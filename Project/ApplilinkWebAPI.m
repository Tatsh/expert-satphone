#import "ApplilinkWebAPI.h"

#import <UIKit/UIKit.h>

#import "ApplilinkConsts.h"
#import "ApplilinkNetworkError.h"
#import "ApplilinkUtilities.h"

// HTTP method that selects the form-encoded POST body path; any other value uses the GET query.
static NSString *const kApplilinkWebAPIPostMethod = @"POST";

// Form-encoding constants for the POST body.
static NSString *const kApplilinkWebAPIContentTypeHeaderField = @"Content-Type";
static NSString *const kApplilinkWebAPIFormURLEncodedContentType =
    @"application/x-www-form-urlencoded";
static NSString *const kApplilinkWebAPIQueryPairFormat = @"%@=%@";
static NSString *const kApplilinkWebAPIQueryArrayPairFormat = @"%@[]=%@";
static NSString *const kApplilinkWebAPIQueryPairSeparator = @"&";

// The parameters every applilink request carries. Both pairs are built inline by the
// dictionaryWithObjectsAndKeys: at 0x2512ac, whose stack holds four objects and an explicit nil.
static NSString *const kApplilinkWebAPICarrierKey = @"cr";
static NSString *const kApplilinkWebAPICarrierValue = @"0";
static NSString *const kApplilinkWebAPIFormatKey = @"format";
static NSString *const kApplilinkWebAPIFormatValue = @"json";

// Endpoint whose presence in a request URL marks it as the session-regeneration request; that
// request is short-circuited rather than blocked on the session gate.
static NSString *const kApplilinkWebAPISessionRegeneratePath = @"/app/auth/sessionRegenerate.php";

// NSUserDefaults key holding the reward contents-server URL, matched to recognise a contents-server
// response.
static NSString *const kApplilinkWebAPIRewardAppliURLKey = @"ApplilinkReward.appliURL";

// NSUserDefaults key under which the asynchronous completion handler persists the null-scrubbed
// response body.
static NSString *const kApplilinkWebAPIResponseNsDataKey = @"ApplilinkNetwork.responseNsData";

// Keys used when building the session-regeneration short-circuit result and the various error
// user-info dictionaries.
static NSString *const kApplilinkWebAPIStatusKey = @"status";
static NSString *const kApplilinkWebAPIErrorCodeKey = @"error_code";
static NSString *const kApplilinkWebAPIResponseKey = @"response";
static NSString *const kApplilinkWebAPIStatusCodeKey = @"statusCode";

// The subobject key the completion handler pulls out of the parsed dictionary before its
// null-scrub pass, and the substring it strips.
static NSString *const kApplilinkWebAPINsSubobjectKey = @"NS";
static NSString *const kApplilinkWebAPINullLiteral = @"null";
static NSString *const kApplilinkWebAPIEmptyString = @"";

// Contents-server first-line status values.
static NSString *const kApplilinkWebAPIContentsStatusOK = @"1";
static NSString *const kApplilinkWebAPIContentsStatusMalformed = @"2";

// Format that renders a numeric HTTP status code into the error user-info string.
static NSString *const kApplilinkWebAPIStatusCodeFormat = @"%ld";

// GCD queue label for the asynchronous request timer.
static const char *const kApplilinkWebAPIQueueLabel = "requestAsynchronousWithURL";

// Applilink network error codes delivered on the various failure paths. These are the raw integers
// the binary passes to +[ApplilinkNetworkError localizedApplilinkErrorWithCode:].
enum {
    kApplilinkNetworkErrorCodeConnectionFailed = 1003,    // 0x3eb
    kApplilinkNetworkErrorCodeMalformedJSON = 1000,       // JSON parsed to nil
    kApplilinkNetworkErrorCodeContentsMalformed = 1006,   // 0x3ee, response not a dictionary
    kApplilinkNetworkErrorCodeContentsUnavailable = 1007, // 0x3ef, JSON unavailable or HTTP failure
    kApplilinkNetworkErrorCodeJSONUnavailable = 1025, // 0x401, NSJSONSerialization missing (sync)
    kApplilinkNetworkErrorCodeTimeout = 1027,         // 0x403, timeout description
};

// Session-regeneration success payload: the reward server that has already granted a session
// receives a synthesised result with this reward point total.
static const NSInteger kApplilinkWebAPISessionRegenerateResult = 100000000;

// Retry policy: the request is attempted at most twice before the counter is forced to the cap.
static const int kApplilinkWebAPIRetryCap = 2;

// HTTP status codes in the 4xx and 5xx server-error ranges are retried.
enum {
    kApplilinkWebAPIServerErrorStatusBase4xx = 400,
    kApplilinkWebAPIServerErrorStatusBase5xx = 500,
    kApplilinkWebAPIServerErrorStatusSpan = 100,
};

// Synchronous request timeout, in seconds.
static const float kApplilinkWebAPISynchronousTimeout = 10.0f;

// The synchronous retry loop only retries a connection error whose code equals this sentinel. It is
// neither NSURLErrorTimedOut (-1001) nor any documented NSURLError value; the binary compares
// against exactly -71495, so a genuine timeout on the synchronous path is reported rather than
// retried. The asynchronous path (unlike this one) does test NSURLErrorTimedOut.
static const NSInteger kApplilinkWebAPISynchronousRetryErrorCode = -71495;

// Interval, in seconds, that an asynchronous request sleeps while polling the session gate.
static const NSTimeInterval kApplilinkWebAPISessionWaitPollInterval = 0.1;

// Extra seconds added to the retry timer beyond the request's own timeout.
static const double kApplilinkWebAPIRetryTimerSlack = 2.0;

// Minimum operating-system version that supports the network-retry policy.
static const float kApplilinkWebAPIRetryMinimumOSVersion = 6.0f;

// Delay, in seconds, before the armed session gate auto-clears.
static const NSTimeInterval kApplilinkWebAPISessionConnectionWaitTimeout = 10.0;

// Session state shared by every ApplilinkWebAPI request.
//
// @ghidraAddress 0x354328 -init sets this, +retryCancel clears it.
static BOOL g_fApplilinkNetworkRetryEnabled;
// @ghidraAddress 0x354329 +setSessionConnectionWait: sets it, +calcelSessionConnection clears it.
static BOOL g_bApplilinkWebAPISessionConnectionWait;
// @ghidraAddress 0x35432a +setSessionStatus: sets it; gates the session-regeneration short circuit.
static BOOL g_bApplilinkWebAPISessionStatus;

@implementation ApplilinkWebAPI {
    // The binary keeps this as a plain, non-property @c int ivar without an underscore.
    int retryCount;
}

#pragma mark Lifecycle

- (instancetype)init {
    self = [super init];
    if (self) {
        retryCount = 0;
        g_fApplilinkNetworkRetryEnabled = YES;
    }
    return self;
}

- (void)dealloc {
    // The binary defines -dealloc as a bare super chain; under ARC the runtime inserts that chain,
    // so the body is empty.
}

#pragma mark Request building

- (NSDictionary *)commonParameters {
    return @{
        kApplilinkWebAPICarrierKey : kApplilinkWebAPICarrierValue,
        kApplilinkWebAPIFormatKey : kApplilinkWebAPIFormatValue,
    };
}

- (NSMutableURLRequest *)requestWithURL:(NSString *)URL
                                 method:(NSString *)method
                             parameters:(NSDictionary *)parameters
                                timeout:(float)timeout
                            cachePolicy:(NSNumber *)cachePolicy {
    NSDictionary *merged = [ApplilinkUtilities joinDictionary:parameters
                                               withDictionary:[self commonParameters]];
    NSMutableURLRequest *request;
    if ([kApplilinkWebAPIPostMethod isEqualToString:method]) {
        request = [self requestForPostWithURL:URL parameters:merged];
    } else {
        request = [self requestForGetWithURL:URL parameters:merged];
    }
    [request setHTTPMethod:method];
    [request setTimeoutInterval:timeout];
    NSURLRequestCachePolicy policy = NSURLRequestReloadIgnoringLocalCacheData;
    if (cachePolicy) {
        policy = (NSURLRequestCachePolicy)cachePolicy.intValue;
    }
    [request setCachePolicy:policy];
    return request;
}

- (NSMutableURLRequest *)requestForGetWithURL:(NSString *)URL
                                   parameters:(NSDictionary *)parameters {
    NSString *urlString = [ApplilinkUtilities appendParametersToURL:URL parameters:parameters];
    return [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
}

- (NSMutableURLRequest *)requestForPostWithURL:(NSString *)URL
                                    parameters:(NSDictionary *)parameters {
    NSMutableArray<NSString *> *pairs = [NSMutableArray array];
    for (id key in [parameters allKeys]) {
        id value = parameters[key];
        if ([value isKindOfClass:[NSArray class]]) {
            for (NSUInteger index = 0; index < [value count]; ++index) {
                [pairs addObject:[NSString stringWithFormat:kApplilinkWebAPIQueryArrayPairFormat,
                                                            key,
                                                            value[index]]];
            }
        } else {
            [pairs addObject:[NSString stringWithFormat:kApplilinkWebAPIQueryPairFormat,
                                                        key,
                                                        parameters[key]]];
        }
    }
    NSString *body = [pairs componentsJoinedByString:kApplilinkWebAPIQueryPairSeparator];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:URL]];
    [request addValue:kApplilinkWebAPIFormURLEncodedContentType
        forHTTPHeaderField:kApplilinkWebAPIContentTypeHeaderField];
    [request setHTTPBody:[body dataUsingEncoding:NSUTF8StringEncoding]];
    [request setCachePolicy:NSURLRequestReloadIgnoringLocalCacheData];
    return request;
}

#pragma mark Asynchronous transport

- (void)requestAsynchronousWithURL:(NSString *)URL
                            method:(NSString *)method
                        parameters:(NSDictionary *)parameters
                          userInfo:(id)userInfo
                               tag:(NSInteger)tag
                       cachePolicy:(NSNumber *)cachePolicy
                           timeout:(float)timeout
                             retry:(BOOL)retry
                     finishedBlock:(ApplilinkWebAPIFinishedBlock)finishedBlock
                       failedBlock:(ApplilinkWebAPIFailedBlock)failedBlock {
    NSMutableURLRequest *request = [self requestWithURL:URL
                                                 method:method
                                             parameters:parameters
                                                timeout:timeout
                                            cachePolicy:cachePolicy];
    if (!retry) {
        retryCount = kApplilinkWebAPIRetryCap;
    }
    while (g_bApplilinkWebAPISessionConnectionWait) {
        [NSThread sleepForTimeInterval:kApplilinkWebAPISessionWaitPollInterval];
    }
    NSString *sessionRegenerateURL = [[ApplilinkConsts baseUrlSsl]
        stringByAppendingString:kApplilinkWebAPISessionRegeneratePath];
    if ([URL rangeOfString:sessionRegenerateURL].location != NSNotFound) {
        if (g_bApplilinkWebAPISessionStatus) {
            NSDictionary *result = @{
                kApplilinkWebAPIStatusKey : @YES,
                kApplilinkWebAPIErrorCodeKey : @(kApplilinkWebAPISessionRegenerateResult),
            };
            if (finishedBlock) {
                finishedBlock(request, result);
            }
            return;
        }
        [ApplilinkWebAPI setSessionConnectionWait:YES];
    }

    __block dispatch_source_t timerSource = nil;
    __block BOOL finished = NO;
    if (![self canUseNetworkRetry] || retry) {
        dispatch_queue_t timerQueue =
            dispatch_queue_create(kApplilinkWebAPIQueueLabel, DISPATCH_QUEUE_SERIAL);
        timerSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, timerQueue);
        dispatch_source_set_timer(
            timerSource,
            dispatch_time(DISPATCH_TIME_NOW,
                          (int64_t)(timeout * NSEC_PER_SEC + kApplilinkWebAPIRetryTimerSlack)),
            DISPATCH_TIME_FOREVER,
            NSEC_PER_SEC);
        dispatch_source_set_event_handler(timerSource, ^{
          /** @ghidraAddress 0x2520c8 */
          if (![self canUseNetworkRetry] || !g_fApplilinkNetworkRetryEnabled) {
              retryCount = kApplilinkWebAPIRetryCap;
          }
          if (timerSource) {
              dispatch_source_cancel(timerSource);
          }
          if (finished) {
              return;
          }
          if (retryCount > 1) {
              ++retryCount;
              NSError *timeoutError = [NSError
                  errorWithDomain:NSURLErrorDomain
                             code:NSURLErrorTimedOut
                         userInfo:@{
                             NSLocalizedDescriptionKey : [ApplilinkNetworkError
                                 localizedApplilinkErrorWithCode:kApplilinkNetworkErrorCodeTimeout]
                                 .localizedDescription
                         }];
              if (failedBlock) {
                  failedBlock(request, timeoutError);
              }
              return;
          }
          [self requestAsynchronousWithURL:URL
                                    method:method
                                parameters:parameters
                                  userInfo:userInfo
                                       tag:tag
                               cachePolicy:cachePolicy
                                   timeout:timeout
                                     retry:retry
                             finishedBlock:finishedBlock
                               failedBlock:failedBlock];
          ++retryCount;
        });
        dispatch_source_set_cancel_handler(timerSource, ^{
          /** @ghidraAddress 0x2523b0 */
          if (timerSource) {
              timerSource = nil;
          }
        });
        dispatch_resume(timerSource);
    }

    [NSURLConnection
        sendAsynchronousRequest:request
                          queue:[NSOperationQueue mainQueue]
              completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
                /** @ghidraAddress 0x252478 */
                if (retryCount > kApplilinkWebAPIRetryCap &&
                    [UIDevice currentDevice].systemVersion.floatValue <
                        kApplilinkWebAPIRetryMinimumOSVersion) {
                    return;
                }
                NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
                NSInteger status = httpResponse.statusCode;
                // The binary tests the 4xx/5xx ranges with an unsigned subtraction, so a status
                // below the range wraps large and is correctly excluded.
                BOOL isServerError =
                    ((NSUInteger)(status - kApplilinkWebAPIServerErrorStatusBase4xx) <
                     kApplilinkWebAPIServerErrorStatusSpan) ||
                    ((NSUInteger)(status - kApplilinkWebAPIServerErrorStatusBase5xx) <
                     kApplilinkWebAPIServerErrorStatusSpan);
                if (!error && !isServerError) {
                    finished = YES;
                    // The contents-server parser returns the body it wishes to hand on: the
                    // accumulated line data for a reward contents URL, otherwise the raw data.
                    id body = [self responseFromContentsServer:URL
                                                       request:request
                                                          data:data
                                                 finishedBlock:finishedBlock
                                                   failedBlock:failedBlock];
                    Class serialization = NSClassFromString(@"NSJSONSerialization");
                    if (!serialization) {
                        if (failedBlock) {
                            failedBlock(request,
                                        [ApplilinkNetworkError
                                            localizedApplilinkErrorWithCode:
                                                kApplilinkNetworkErrorCodeContentsUnavailable]);
                        }
                        return;
                    }
                    NSError *parseError = nil;
                    id parsed = [serialization JSONObjectWithData:body
                                                          options:NSJSONReadingAllowFragments
                                                            error:&parseError];
                    if (parseError) {
                        if (failedBlock) {
                            failedBlock(request, parseError);
                        }
                        return;
                    }
                    if (![parsed isKindOfClass:[NSDictionary class]]) {
                        if (failedBlock) {
                            failedBlock(request,
                                        [ApplilinkNetworkError
                                            localizedApplilinkErrorWithCode:
                                                kApplilinkNetworkErrorCodeContentsMalformed]);
                        }
                        return;
                    }
                    // Null-scrub pass: the "NS" subobject is re-serialised, textually stripped of
                    // the substring "null", re-parsed, and persisted. This corrupts any string
                    // whose content contains "null"; the callback still carries the original parse.
                    NSData *scrubSource = [NSJSONSerialization
                        dataWithJSONObject:[parsed[kApplilinkWebAPINsSubobjectKey] mutableCopy]
                                   options:0
                                     error:nil];
                    NSString *scrubText = [[NSString alloc] initWithData:scrubSource
                                                                encoding:NSUTF8StringEncoding];
                    scrubText = [scrubText
                        stringByReplacingOccurrencesOfString:kApplilinkWebAPINullLiteral
                                                  withString:kApplilinkWebAPIEmptyString];
                    id scrubbed = [NSJSONSerialization
                        JSONObjectWithData:[scrubText dataUsingEncoding:NSUTF8StringEncoding]
                                   options:NSJSONReadingMutableContainers
                                     error:nil];
                    if (scrubbed) {
                        [[NSUserDefaults standardUserDefaults]
                            setObject:scrubbed
                               forKey:kApplilinkWebAPIResponseNsDataKey];
                    }
                    [[NSUserDefaults standardUserDefaults] synchronize];
                    if (finishedBlock) {
                        finishedBlock(request, parsed);
                    }
                    return;
                }
                if (error.code == NSURLErrorTimedOut) {
                    if ([UIDevice currentDevice].systemVersion.floatValue >=
                            kApplilinkWebAPIRetryMinimumOSVersion &&
                        !retry) {
                        NSError *timeoutError =
                            [NSError errorWithDomain:NSURLErrorDomain
                                                code:NSURLErrorTimedOut
                                            userInfo:@{
                                                NSLocalizedDescriptionKey : [ApplilinkNetworkError
                                                    localizedApplilinkErrorWithCode:
                                                        kApplilinkNetworkErrorCodeTimeout]
                                                    .localizedDescription
                                            }];
                        if (failedBlock) {
                            failedBlock(request, timeoutError);
                        }
                    }
                    return;
                }
                finished = YES;
                NSError *reportedError = error;
                if (!reportedError) {
                    reportedError = [ApplilinkNetworkError
                        localizedApplilinkErrorWithCode:
                            kApplilinkNetworkErrorCodeContentsUnavailable
                                               userInfo:@{
                                                   kApplilinkWebAPIStatusCodeKey : [NSString
                                                       stringWithFormat:
                                                           kApplilinkWebAPIStatusCodeFormat,
                                                           (long)status]
                                               }];
                }
                if (failedBlock) {
                    failedBlock(request, reportedError);
                }
              }];
}

#pragma mark Contents-server transport

- (id)responseFromContentsServer:(NSString *)response
                         request:(id)request
                            data:(NSData *)data
                   finishedBlock:(ApplilinkWebAPIFinishedBlock)finishedBlock
                     failedBlock:(ApplilinkWebAPIFailedBlock)failedBlock {
    NSString *appliURL =
        [[NSUserDefaults standardUserDefaults] objectForKey:kApplilinkWebAPIRewardAppliURLKey];
    if (![response isEqualToString:appliURL]) {
        return data;
    }
    if (data.length == 0) {
        NSError *connectionError = [ApplilinkNetworkError
            localizedApplilinkErrorWithCode:kApplilinkNetworkErrorCodeConnectionFailed];
        if (failedBlock) {
            failedBlock(request, connectionError);
        }
        return data;
    }

    // The body is line-delimited: line 0 carries the status field and is captured into
    // @c firstLine, and every later line is appended into the accumulator string.
    __block int lineIndex = 0;
    __block NSString *firstLine = nil;
    NSMutableString *accumulator = [[NSMutableString alloc] init];
    NSString *text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    [text enumerateLinesUsingBlock:^(NSString *line, BOOL *__attribute__((unused)) stop) {
      /** @ghidraAddress 0x253104 */
      if (lineIndex != 0) {
          [accumulator appendString:line];
      } else {
          firstLine = [[NSString alloc] initWithString:line];
      }
      ++lineIndex;
    }];

    if ([firstLine isEqualToString:kApplilinkWebAPIContentsStatusOK]) {
        // The success path returns the accumulated body as data without invoking the finished
        // block; the asynchronous caller JSON-parses this return value itself.
        return [accumulator dataUsingEncoding:NSUTF8StringEncoding];
    }
    NSDictionary *userInfo = @{kApplilinkWebAPIResponseKey : firstLine};
    NSInteger code = [firstLine isEqualToString:kApplilinkWebAPIContentsStatusMalformed] ?
                         kApplilinkNetworkErrorCodeContentsMalformed :
                         kApplilinkNetworkErrorCodeContentsUnavailable;
    NSError *bodyError = [ApplilinkNetworkError localizedApplilinkErrorWithCode:code
                                                                       userInfo:userInfo];
    if (failedBlock) {
        failedBlock(request, bodyError);
    }
    return data;
}

#pragma mark Synchronous transport

- (id)requestSynchronousWithURL:(NSString *)URL
                         method:(NSString *)method
                     parameters:(NSDictionary *)parameters
                    cachePolicy:(NSNumber *)cachePolicy
                          error:(NSError **)error {
    NSMutableURLRequest *request = [self requestWithURL:URL
                                                 method:method
                                             parameters:parameters
                                                timeout:kApplilinkWebAPISynchronousTimeout
                                            cachePolicy:cachePolicy];
    retryCount = 0;
    NSData *data = nil;
    for (;;) {
        NSHTTPURLResponse *response = nil;
        NSError *connectionError = nil;
        data = [NSURLConnection sendSynchronousRequest:request
                                     returningResponse:&response
                                                 error:&connectionError];
        NSInteger status = response.statusCode;
        // The binary tests the 4xx/5xx ranges with an unsigned subtraction, so a status below the
        // range wraps large and is correctly excluded.
        BOOL isServerError = ((NSUInteger)(status - kApplilinkWebAPIServerErrorStatusBase4xx) <
                              kApplilinkWebAPIServerErrorStatusSpan) ||
                             ((NSUInteger)(status - kApplilinkWebAPIServerErrorStatusBase5xx) <
                              kApplilinkWebAPIServerErrorStatusSpan);
        if (!connectionError && !isServerError) {
            if (!data) {
                if (!error) {
                    return nil;
                }
                *error = [ApplilinkNetworkError
                    localizedApplilinkErrorWithCode:kApplilinkNetworkErrorCodeConnectionFailed];
                return nil;
            }
            break;
        }
        // Only a connection error carrying this exact sentinel code is retried; every other
        // failure is reported. (The value is not NSURLErrorTimedOut; see the constant's comment.)
        if (retryCount > 1 || connectionError.code != kApplilinkWebAPISynchronousRetryErrorCode) {
            if (!error) {
                return nil;
            }
            *error = connectionError;
            return nil;
        }
        [NSThread sleepForTimeInterval:(NSTimeInterval)(retryCount * 2 + 2)];
        int attempted = retryCount;
        retryCount = attempted + 1;
        if (attempted >= kApplilinkWebAPIRetryCap) {
            break;
        }
    }

    Class serialization = NSClassFromString(@"NSJSONSerialization");
    if (!serialization) {
        if (error) {
            *error = [ApplilinkNetworkError
                localizedApplilinkErrorWithCode:kApplilinkNetworkErrorCodeJSONUnavailable];
        }
        return nil;
    }
    NSError *parseError = nil;
    id parsed = [serialization JSONObjectWithData:data
                                          options:NSJSONReadingAllowFragments
                                            error:&parseError];
    if (!parseError) {
        if (parsed) {
            return parsed;
        }
        if (error) {
            *error = [ApplilinkNetworkError
                localizedApplilinkErrorWithCode:kApplilinkNetworkErrorCodeMalformedJSON];
        }
    } else if (error) {
        *error = parseError;
    }
    return nil;
}

#pragma mark Capability

- (BOOL)canUseNetworkRetry {
    return
        [UIDevice currentDevice].systemVersion.floatValue >= kApplilinkWebAPIRetryMinimumOSVersion;
}

#pragma mark Class factories

+ (void)requestAsynchronousWithURL:(NSString *)URL
                            method:(NSString *)method
                        parameters:(NSDictionary *)parameters
                          userInfo:(id)userInfo
                               tag:(NSInteger)tag
                       cachePolicy:(NSNumber *)cachePolicy
                           timeout:(float)timeout
                             retry:(BOOL)retry
                     finishedBlock:(ApplilinkWebAPIFinishedBlock)finishedBlock
                       failedBlock:(ApplilinkWebAPIFailedBlock)failedBlock {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
      /** @ghidraAddress 0x2537fc */
      // A fresh instance per call keeps the per-request retryCount ivar from being shared.
      [[[ApplilinkWebAPI alloc] init] requestAsynchronousWithURL:URL
                                                          method:method
                                                      parameters:parameters
                                                        userInfo:userInfo
                                                             tag:tag
                                                     cachePolicy:cachePolicy
                                                         timeout:timeout
                                                           retry:retry
                                                   finishedBlock:finishedBlock
                                                     failedBlock:failedBlock];
    });
}

+ (id)requestSynchronousWithURL:(NSString *)URL
                         method:(NSString *)method
                     parameters:(NSDictionary *)parameters
                    cachePolicy:(NSNumber *)cachePolicy
                          error:(NSError **)error {
    return [[[ApplilinkWebAPI alloc] init] requestSynchronousWithURL:URL
                                                              method:method
                                                          parameters:parameters
                                                         cachePolicy:cachePolicy
                                                               error:error];
}

+ (id)responseFromContentsServer:(NSString *)response
                         request:(id)request
                            data:(NSData *)data
                   finishedBlock:(ApplilinkWebAPIFinishedBlock)finishedBlock
                     failedBlock:(ApplilinkWebAPIFailedBlock)failedBlock {
    return [[[ApplilinkWebAPI alloc] init] responseFromContentsServer:response
                                                              request:request
                                                                 data:data
                                                        finishedBlock:finishedBlock
                                                          failedBlock:failedBlock];
}

#pragma mark Session and retry control

+ (void)retryCancel {
    g_fApplilinkNetworkRetryEnabled = NO;
}

+ (void)setSessionConnectionWait:(BOOL)sessionConnectionWait {
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    g_bApplilinkWebAPISessionConnectionWait = sessionConnectionWait;
    if (sessionConnectionWait) {
        [self performSelector:@selector(calcelSessionConnection)
                   withObject:nil
                   afterDelay:kApplilinkWebAPISessionConnectionWaitTimeout];
    }
}

+ (void)calcelSessionConnection {
    g_bApplilinkWebAPISessionConnectionWait = NO;
}

+ (void)setSessionStatus:(BOOL)sessionStatus {
    g_bApplilinkWebAPISessionStatus = sessionStatus;
}

@end

#import "ApplilinkURLConnection.h"

@implementation ApplilinkURLConnection {
    __weak id<ApplilinkURLConnectionDelegate> _connectionDelegate; // +0x8
    NSMutableData *_receivedData;                                  // +0x10
    NSURLResponse *_responseData;                                  // +0x18
}

@synthesize connectionDelegate = _connectionDelegate;
@synthesize receivedData = _receivedData;
@synthesize responseData = _responseData;

#pragma mark - Construction

/** @ghidraAddress 0x230c04 */
- (instancetype)init {
    return [super init];
}

/** @ghidraAddress 0x230c40 */
- (void)loadRequestWithRequest:(NSURLRequest *)request delegate:(id)delegate {
    _connectionDelegate = delegate;
    NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
    if (connection) {
        _receivedData = [NSMutableData data];
    }
}

#pragma mark - NSURLConnectionDataDelegate

/** @ghidraAddress 0x230d04 */
- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    _responseData = response;
    _receivedData.length = 0;
}

/** @ghidraAddress 0x230d5c */
- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    [_receivedData appendData:data];
}

/** @ghidraAddress 0x230d7c */
- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    _receivedData = nil;
    if (_connectionDelegate &&
        [_connectionDelegate respondsToSelector:@selector(failLoadWithError:)]) {
        [_connectionDelegate failLoadWithError:error];
    }
}

/** @ghidraAddress 0x230e48 */
- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    NSString *response = [[NSString alloc] initWithData:_receivedData
                                               encoding:NSUTF8StringEncoding];
    _receivedData = nil;
    _responseData = nil;
    if (_connectionDelegate &&
        [_connectionDelegate respondsToSelector:@selector(finishLoadWithResponse:)]) {
        [_connectionDelegate finishLoadWithResponse:response];
    }
}

/** @ghidraAddress 0x230f50 */
- (NSURLRequest *)connection:(NSURLConnection *)connection
             willSendRequest:(NSURLRequest *)request
            redirectResponse:(NSURLResponse *)redirectResponse {
    // A redirect the delegate claims (via -redirectStartLoad:) is cancelled here: the delegate is
    // told the load finished with no body and the request is dropped.
    if (_connectionDelegate &&
        [_connectionDelegate respondsToSelector:@selector(redirectStartLoad:)] &&
        [_connectionDelegate redirectStartLoad:request]) {
        if ([_connectionDelegate respondsToSelector:@selector(finishLoadWithResponse:)]) {
            [_connectionDelegate finishLoadWithResponse:nil];
        }
        return nil;
    }
    return request;
}

@end

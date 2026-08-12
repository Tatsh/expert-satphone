#import "SharePlayManager.h"

#import <UIKit/UIKit.h>

#import "HostClass.h"
#import "SessionClass.h"

// The MultipeerConnectivity service type this game advertises and browses for.
static NSString *const kSharePlayServiceType = @"jubeatplus1";

// The name of the one-shot output stream used to transfer the music-data file.
static NSString *const kSharePlayMusicStreamName = @"musicData";

// Keys inside a serialised SharePlay message dictionary.
static NSString *const kSharePlayKeyDataType = @"dataType";
static NSString *const kSharePlayKeySendData = @"sendData";

// The key under which the host adds the file size to the music-info dictionary.
static NSString *const kSharePlayKeyFileSize = @"fileSize";

// Keys inside a final-result payload.
static NSString *const kSharePlayKeyFinalDataScore = @"FinalDataScore";
static NSString *const kSharePlayKeyFinalDataBonus = @"FinalDataBonus";
static NSString *const kSharePlayKeyFinalDataFullcombo = @"FinalDataFullcombo";

// The fixed start-of-play delay, in seconds, from -startPlaySync.
static const float kSharePlayStartDelaySeconds = 5.0f;

// Clock synchronisation stops once the measured round-trip delay drops to this threshold, in
// seconds, and gives up after kSharePlayMaxPingTryCount attempts.
static const float kSharePlaySyncDelayThreshold = 0.08f;
static const float kSharePlayMaxPingTryCount = 10.0f;

// The music-stream read is done into a fixed 1 KiB buffer.
static const NSUInteger kSharePlayStreamReadBufferSize = 1024;

// The message-type tag carried under kSharePlayKeyDataType.
typedef enum {
    SharePlayMessageTypeCheckExistMusic = 1,
    SharePlayMessageTypeMusicSendComplete = 2,
    SharePlayMessageTypeSelectStart = 3,
    SharePlayMessageTypeStartMusicTime = 4,
    SharePlayMessageTypeSendMusicInfo = 6,
    SharePlayMessageTypeSendMusicData = 7,
    SharePlayMessageTypeClientReady = 8,
    SharePlayMessageTypeClientLoaded = 9,
    SharePlayMessageTypeScore = 10,
    SharePlayMessageTypeFinalData = 11,
    SharePlayMessageTypeHostClock = 12,
    SharePlayMessageTypeClientClock = 13,
} SharePlayMessageType;

@interface SharePlayManager () {
    MCPeerID *myPeerID;
    BOOL bIsHost;
    MCNearbyServiceBrowser *nearbyBrowser;
    MCNearbyServiceAdvertiser *nearbyAdv;
    NSString *partnerName;
    SessionClass *clientInfo;
    NSData *musicData;
    BOOL bAccept;
    HostClass *hostInfo;
    NSDate *hostDate;
    NSDate *clientDate;
    NSMutableData *receiveMusicData;
    int fileSize;
    NSInputStream *musicStream;
    __weak NSOutputStream *weakSendStream;
    NSDictionary *musicInfo;
    NSString *musicFilePath;
    BOOL bConnected;
}
@end

@implementation SharePlayManager

#pragma mark - Initialisation

- (BOOL)isHost {
    return bIsHost;
}

- (instancetype)initWithScreenName:(NSString *)screenName {
    self = [super init];
    if (self) {
        if (screenName == nil) {
            _displayName = UIDevice.currentDevice.name;
        } else {
            _displayName = screenName;
        }
        myPeerID = [[MCPeerID alloc] initWithDisplayName:_displayName];
        nearbyBrowser = nil;
        nearbyAdv = nil;
        receiveMusicData = nil;
    }
    return self;
}

#pragma mark - Session setup

- (void)sessionCreate {
    MCSession *newSession = [[MCSession alloc] initWithPeer:myPeerID];
    newSession.delegate = self;
    bConnected = NO;
    self.session = newSession;
    weakSendStream = nil;
}

- (void)startClient {
    [self sessionCreate];
    nearbyBrowser = [[MCNearbyServiceBrowser alloc] initWithPeer:myPeerID
                                                     serviceType:kSharePlayServiceType];
    nearbyBrowser.delegate = self;
    [nearbyBrowser startBrowsingForPeers];
    bIsHost = NO;
    bAccept = YES;
    hostInfo = [[HostClass alloc] init];
}

- (void)startHostModeWithMusicInfo:(NSDictionary *)musicInfoIn filePath:(NSString *)filePath {
    musicFilePath = filePath;
    NSDictionary *attributes = [NSFileManager.defaultManager attributesOfItemAtPath:musicFilePath
                                                                              error:nil];
    id size = attributes[NSFileSize];
    NSMutableDictionary *mutableInfo = [musicInfoIn mutableCopy];
    mutableInfo[kSharePlayKeyFileSize] = size;
    musicInfo = [mutableInfo copy];
    [self sessionCreate];
    nearbyAdv = [[MCNearbyServiceAdvertiser alloc] initWithPeer:myPeerID
                                                  discoveryInfo:nil
                                                    serviceType:kSharePlayServiceType];
    nearbyAdv.delegate = self;
    [nearbyAdv startAdvertisingPeer];
    bIsHost = YES;
    bAccept = YES;
    clientInfo = [[SessionClass alloc] init];
    hostInfo = [[HostClass alloc] init];
}

#pragma mark - Teardown

- (void)connectCancel {
    if (nearbyAdv != nil) {
        [nearbyAdv stopAdvertisingPeer];
        nearbyAdv.delegate = nil;
        nearbyAdv = nil;
    }
    if (nearbyBrowser != nil) {
        [nearbyBrowser stopBrowsingForPeers];
        nearbyBrowser.delegate = nil;
        nearbyBrowser = nil;
    }
    if (self.session != nil) {
        if (musicStream != nil) {
            musicStream.delegate = nil;
            musicStream = nil;
        }
        [self.session disconnect];
        self.session.delegate = nil;
        self.session = nil;
        if (weakSendStream != nil) {
            // The binary sleeps a second to let the in-flight output stream drain before the
            // manager is torn down.
            sleep(1);
        }
    }
}

- (void)disconnect {
    [self connectCancel];
}

#pragma mark - Outgoing control messages

- (void)sendSelectStart {
    MCPeerID *peer = self.session.connectedPeers[0];
    [self sendTypeData:SharePlayMessageTypeSelectStart toPeer:peer];
    musicData = nil;
}

- (void)startPlaySync {
    if ([self.delegate respondsToSelector:@selector(sharePlayManager:startMusicTime:)]) {
        [self.delegate sharePlayManager:self startMusicTime:kSharePlayStartDelaySeconds];
    }
    NSDate *startDate =
        [NSDate dateWithTimeIntervalSinceNow:kSharePlayStartDelaySeconds - clientInfo.delayTime];
    NSDictionary *message = @{
        kSharePlayKeyDataType : @(SharePlayMessageTypeStartMusicTime),
        kSharePlayKeySendData : startDate
    };
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:message];
    [self sendData:data toPeer:self.session.connectedPeers[0]];
}

- (void)sendClientReady {
    MCPeerID *peer = self.session.connectedPeers[0];
    [self sendTypeData:SharePlayMessageTypeClientReady toPeer:peer];
}

#pragma mark - MCNearbyServiceBrowserDelegate

- (void)browser:(MCNearbyServiceBrowser *)browser
            foundPeer:(MCPeerID *)peerID
    withDiscoveryInfo:(NSDictionary<NSString *, NSString *> *)info {
    if (!bConnected) {
        if ([self.delegate respondsToSelector:@selector(sharePlayManager:findHostID:)]) {
            [self.delegate sharePlayManager:self findHostID:peerID];
        }
    }
}

- (void)browser:(MCNearbyServiceBrowser *)browser lostPeer:(MCPeerID *)peerID {
    if (!bConnected) {
        if ([self.delegate respondsToSelector:@selector(sharePlayManager:lostHostID:)]) {
            [self.delegate sharePlayManager:self lostHostID:peerID];
        }
    }
}

- (void)browser:(MCNearbyServiceBrowser *)browser didNotStartBrowsingForPeers:(NSError *)error {
}

#pragma mark - MCNearbyServiceAdvertiserDelegate

- (void)advertiser:(MCNearbyServiceAdvertiser *)advertiser
    didNotStartAdvertisingPeer:(NSError *)error {
}

- (void)advertiser:(MCNearbyServiceAdvertiser *)advertiser
    didReceiveInvitationFromPeer:(MCPeerID *)peerID
                     withContext:(NSData *)context
               invitationHandler:(void (^)(BOOL accept, MCSession *session))handler {
    if (bAccept) {
        handler(YES, self.session);
        partnerName = peerID.displayName;
        bAccept = NO;
    } else {
        handler(NO, self.session);
    }
}

#pragma mark - Connection state machine

- (void)changeState:(MCPeerID *)peer state:(MCSessionState)state {
    if (state == MCSessionStateNotConnected) {
        [self connectCancel];
        dispatch_async(dispatch_get_main_queue(), ^{
          /** @ghidraAddress 0xc6128 */
          if (!self->bIsHost) {
              self->bAccept = YES;
              if ([self.delegate respondsToSelector:@selector(sharePlayManagerDisconnect:)]) {
                  [self.delegate sharePlayManagerDisconnect:self];
              }
          } else {
              if ([self.delegate
                      respondsToSelector:@selector(sharePlayManager:disconnectClient:)]) {
                  [self.delegate sharePlayManager:self disconnectClient:peer];
              }
          }
        });
    } else if (state == MCSessionStateConnected) {
        bConnected = YES;
        if (!bIsHost) {
            [nearbyBrowser stopBrowsingForPeers];
            nearbyBrowser.delegate = nil;
            nearbyBrowser = nil;
            dispatch_async(dispatch_get_main_queue(), ^{
              /** @ghidraAddress 0xc6068 */
              if ([self.delegate respondsToSelector:@selector(sharePlayManagerConnectHost:)]) {
                  [self.delegate sharePlayManagerConnectHost:self];
              }
            });
        } else {
            clientInfo.pingTryCnt = 0;
            [self sendHostClock:peer];
            [nearbyAdv stopAdvertisingPeer];
            nearbyAdv.delegate = nil;
            nearbyAdv = nil;
        }
    }
}

#pragma mark - MCSessionDelegate

- (void)session:(MCSession *)session peer:(MCPeerID *)peerID didChangeState:(MCSessionState)state {
    [self changeState:peerID state:state];
}

- (void)session:(MCSession *)session didReceiveData:(NSData *)data fromPeer:(MCPeerID *)peerID {
    dispatch_async(dispatch_get_main_queue(), ^{
      /** @ghidraAddress 0xc71e8 */
      [self receiveData:session data:data fromPeer:peerID];
    });
}

- (void)receiveData:(MCSession *)session data:(NSData *)data fromPeer:(MCPeerID *)peer {
    NSDictionary *message = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    int type = [message[kSharePlayKeyDataType] intValue];
    switch (type) {
    case SharePlayMessageTypeCheckExistMusic: {
        BOOL exist = [message[kSharePlayKeySendData] boolValue];
        if (!exist) {
            if ([self.delegate
                    respondsToSelector:@selector(sharePlayManager:receiveExistMusicData:)]) {
                [self.delegate sharePlayManager:self receiveExistMusicData:NO];
            }
            if (musicData == nil) {
                musicData = [NSData dataWithContentsOfFile:musicFilePath];
            }
            [self sendDataStream:musicData toPeer:peer dataName:kSharePlayMusicStreamName];
        } else {
            clientInfo.dataReceived = YES;
            if ([self.delegate
                    respondsToSelector:@selector(sharePlayManagerSuccessSendMusicData:)]) {
                [self.delegate sharePlayManagerSuccessSendMusicData:self];
            }
        }
        break;
    }
    case SharePlayMessageTypeMusicSendComplete: {
        if (weakSendStream != nil) {
            weakSendStream = nil;
        }
        if ([self.delegate respondsToSelector:@selector(sharePlayManagerSuccessSendMusicData:)]) {
            [self.delegate sharePlayManagerSuccessSendMusicData:self];
        }
        break;
    }
    case SharePlayMessageTypeSelectStart: {
        [self.delegate sharePlayManagerHostSelectStart:self];
        break;
    }
    case SharePlayMessageTypeStartMusicTime: {
        if ([self.delegate respondsToSelector:@selector(sharePlayManager:startMusicTime:)]) {
            NSDate *hostStartDate = message[kSharePlayKeySendData];
            NSDate *now = [NSDate date];
            NSTimeInterval hostToLocal = [hostStartDate timeIntervalSinceDate:hostDate];
            NSDate *localStartDate = [NSDate dateWithTimeInterval:hostToLocal sinceDate:clientDate];
            NSTimeInterval remaining = [localStartDate timeIntervalSinceDate:now];
            [self.delegate sharePlayManager:self startMusicTime:(float)remaining];
        }
        break;
    }
    case SharePlayMessageTypeSendMusicInfo: {
        NSDictionary *info = message[kSharePlayKeySendData];
        musicInfo = [info copy];
        if ([self.delegate respondsToSelector:@selector(sharePlayManager:receiveMusicInfo:)]) {
            BOOL alreadyHave = [self.delegate sharePlayManager:self receiveMusicInfo:info];
            NSDictionary *reply = @{
                kSharePlayKeyDataType : @(SharePlayMessageTypeCheckExistMusic),
                kSharePlayKeySendData : @(alreadyHave)
            };
            NSData *replyData = [NSKeyedArchiver archivedDataWithRootObject:reply];
            [self sendData:replyData toPeer:peer];
            fileSize = [info[kSharePlayKeyFileSize] intValue];
            (void)[NSDate date]; // Yes, the binary creates and discards this date.
        }
        break;
    }
    case SharePlayMessageTypeSendMusicData: {
        (void)[NSDate date]; // Yes, the binary creates and discards this date.
        BOOL loaded = YES;
        clientInfo.dataReceived = YES;
        musicData = message[kSharePlayKeySendData];
        if ([self.delegate respondsToSelector:@selector(sharePlayManager:musicDataReceived:)]) {
            loaded = [self.delegate sharePlayManager:self
                                   musicDataReceived:message[kSharePlayKeySendData]];
        }
        NSDictionary *ack = @{
            kSharePlayKeyDataType : @(SharePlayMessageTypeMusicSendComplete),
            kSharePlayKeySendData : @(loaded)
        };
        NSData *ackData = [NSKeyedArchiver archivedDataWithRootObject:ack];
        [self sendData:ackData toPeer:self.session.connectedPeers[0]];
        break;
    }
    case SharePlayMessageTypeClientReady: {
        if (!bIsHost) {
            return;
        }
        clientInfo.readyToLoad = YES;
        if ([self.delegate respondsToSelector:@selector(sharePlayManagerAllClientReady:)]) {
            [self.delegate sharePlayManagerAllClientReady:self];
        }
        break;
    }
    case SharePlayMessageTypeClientLoaded: {
        clientInfo.dataLoaded = YES;
        [self checkMusicDataLoadingStatus];
        break;
    }
    case SharePlayMessageTypeScore: {
        [self receiveScore:message[kSharePlayKeySendData]];
        break;
    }
    case SharePlayMessageTypeFinalData: {
        [self receiveFinalData:message[kSharePlayKeySendData]];
        break;
    }
    case SharePlayMessageTypeHostClock: {
        hostDate = [message[kSharePlayKeySendData] copy];
        clientDate = [NSDate date];
        NSDictionary *reply = @{
            kSharePlayKeyDataType : @(SharePlayMessageTypeClientClock),
            kSharePlayKeySendData : clientDate
        };
        NSData *replyData = [NSKeyedArchiver archivedDataWithRootObject:reply];
        [self sendData:replyData toPeer:peer];
        break;
    }
    case SharePlayMessageTypeClientClock: {
        NSDate *clientEcho = message[kSharePlayKeySendData];
        NSDate *now = [NSDate date];
        clientInfo.delayTime = (float)[now timeIntervalSinceDate:clientEcho];
        if (clientInfo.delayTime <= kSharePlaySyncDelayThreshold) {
            // Halve the measured round trip to estimate the one-way delay.
            clientInfo.delayTime = clientInfo.delayTime * 0.5f;
            if ([self.delegate respondsToSelector:@selector(sharePlayManagerConnectClient:)]) {
                [self.delegate sharePlayManagerConnectClient:self];
            }
            NSDictionary *info = @{
                kSharePlayKeyDataType : @(SharePlayMessageTypeSendMusicInfo),
                kSharePlayKeySendData : musicInfo
            };
            NSData *infoData = [NSKeyedArchiver archivedDataWithRootObject:info];
            [self sendData:infoData toPeer:peer];
        } else if (clientInfo.pingTryCnt < kSharePlayMaxPingTryCount) {
            [self sendHostClock:peer];
        } else {
            [self connectCancel];
            if ([self.delegate respondsToSelector:@selector(sharePlayManager:disconnectClient:)]) {
                [self.delegate sharePlayManager:self disconnectClient:peer];
            }
        }
        break;
    }
    default:
        break;
    }
}

- (void)session:(MCSession *)session
    didReceiveStream:(NSInputStream *)stream
            withName:(NSString *)streamName
            fromPeer:(MCPeerID *)peerID {
    musicStream = stream;
    stream.delegate = self;
    [stream scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
    [stream open];
}

- (void)session:(MCSession *)session
    didStartReceivingResourceWithName:(NSString *)resourceName
                             fromPeer:(MCPeerID *)peerID
                         withProgress:(NSProgress *)progress {
}

- (void)session:(MCSession *)session
    didFinishReceivingResourceWithName:(NSString *)resourceName
                              fromPeer:(MCPeerID *)peerID
                                 atURL:(NSURL *)localURL
                             withError:(NSError *)error {
}

#pragma mark - Connection request and clock

- (void)sendConnectRequest:(MCPeerID *)peer {
    [nearbyBrowser invitePeer:peer toSession:self.session withContext:nil timeout:0];
    partnerName = peer.displayName;
}

- (void)sendHostClock:(MCPeerID *)peer {
    NSDate *now = [NSDate date];
    NSDictionary *message =
        @{kSharePlayKeyDataType : @(SharePlayMessageTypeHostClock), kSharePlayKeySendData : now};
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:message];
    [self sendData:data toPeer:peer];
    clientInfo.pingTryCnt = clientInfo.pingTryCnt + 1.0f;
}

#pragma mark - Result exchange

- (void)checkFinishStatus {
    if (clientInfo.finished && hostInfo.finished) {
        NSDictionary *finalData = @{
            kSharePlayKeyFinalDataScore : @(hostInfo.score),
            kSharePlayKeyFinalDataBonus : @(hostInfo.finalBonus),
            kSharePlayKeyFinalDataFullcombo : @(hostInfo.fullcombo)
        };
        NSDictionary *message = @{
            kSharePlayKeyDataType : @(SharePlayMessageTypeFinalData),
            kSharePlayKeySendData : finalData
        };
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:message];
        [self sendData:data toPeer:self.session.connectedPeers[0]];
        if ([self.delegate
                respondsToSelector:@selector(
                                       sharePlayManager:receiveFinalScore:bonus:fullCombo:)]) {
            [self.delegate sharePlayManager:self
                          receiveFinalScore:clientInfo.score
                                      bonus:clientInfo.finalBonus
                                  fullCombo:clientInfo.fullcombo];
        }
    }
}

- (void)receiveScore:(NSNumber *)score {
    int value = [score intValue];
    if (bIsHost) {
        clientInfo.score = value;
    } else {
        hostInfo.score = value;
    }
    if ([self.delegate respondsToSelector:@selector(sharePlayManager:receiveScore:)]) {
        [self.delegate sharePlayManager:self receiveScore:value];
    }
}

- (void)receiveFinalData:(NSDictionary *)finalData {
    if (bIsHost) {
        clientInfo.score = [finalData[kSharePlayKeyFinalDataScore] intValue];
        clientInfo.finalBonus = [finalData[kSharePlayKeyFinalDataBonus] intValue];
        clientInfo.fullcombo = [finalData[kSharePlayKeyFinalDataFullcombo] boolValue];
        clientInfo.finished = YES;
        [self checkFinishStatus];
    } else {
        hostInfo.score = [finalData[kSharePlayKeyFinalDataScore] intValue];
        hostInfo.finalBonus = [finalData[kSharePlayKeyFinalDataBonus] intValue];
        hostInfo.fullcombo = [finalData[kSharePlayKeyFinalDataFullcombo] boolValue];
        if ([self.delegate
                respondsToSelector:@selector(
                                       sharePlayManager:receiveFinalScore:bonus:fullCombo:)]) {
            [self.delegate sharePlayManager:self
                          receiveFinalScore:hostInfo.score
                                      bonus:hostInfo.finalBonus
                                  fullCombo:hostInfo.fullcombo];
        }
    }
}

#pragma mark - Chart loading

- (void)checkMusicDataLoadingStatus {
    if (hostInfo.dataLoaded && clientInfo.dataLoaded) {
        if ([self.delegate respondsToSelector:@selector(sharePlayManagerAllClientLoaded:)]) {
            [self.delegate sharePlayManagerAllClientLoaded:self];
        }
    }
}

- (void)completeLoadingMusicData {
    if (bIsHost) {
        hostInfo.dataLoaded = YES;
        [self checkMusicDataLoadingStatus];
    } else {
        [self sendTypeData:SharePlayMessageTypeClientLoaded toPeer:self.session.connectedPeers[0]];
    }
}

#pragma mark - Score sending

- (void)sendScore:(int)score {
    NSDictionary *message =
        @{kSharePlayKeyDataType : @(SharePlayMessageTypeScore), kSharePlayKeySendData : @(score)};
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:message];
    [self sendData:data toPeer:self.session.connectedPeers[0]];
}

- (void)sendFinalScore:(int)score bonus:(int)bonus fullCombo:(BOOL)fullCombo {
    if (!bIsHost) {
        NSDictionary *finalData = @{
            kSharePlayKeyFinalDataScore : @(score),
            kSharePlayKeyFinalDataBonus : @(bonus),
            kSharePlayKeyFinalDataFullcombo : @(fullCombo)
        };
        NSDictionary *message = @{
            kSharePlayKeyDataType : @(SharePlayMessageTypeFinalData),
            kSharePlayKeySendData : finalData
        };
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:message];
        [self sendData:data toPeer:self.session.connectedPeers[0]];
    } else {
        hostInfo.score = score;
        hostInfo.finalBonus = bonus;
        hostInfo.fullcombo = fullCombo;
        hostInfo.finished = YES;
        [self checkFinishStatus];
    }
}

#pragma mark - Low-level send

- (void)sendTypeData:(int)type toPeer:(MCPeerID *)peer {
    NSDictionary *message = @{kSharePlayKeyDataType : @(type)};
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:message];
    [self sendData:data toPeer:peer];
}

- (void)sendData:(NSData *)data toPeer:(MCPeerID *)peer {
    NSArray *peers = @[ peer ];
    [self.session sendData:data toPeers:peers withMode:MCSessionSendDataReliable error:nil];
}

- (void)sendDataStream:(NSData *)data toPeer:(MCPeerID *)peer dataName:(NSString *)dataName {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
      /** @ghidraAddress 0xc8690 */
      NSOutputStream *stream = [self.session startStreamWithName:dataName toPeer:peer error:nil];
      self->weakSendStream = stream;
      stream.delegate = self;
      [stream scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
      [stream open];
      [stream write:data.bytes maxLength:data.length];
      [stream close];
    });
}

#pragma mark - NSStreamDelegate

- (void)stream:(NSStream *)stream handleEvent:(NSStreamEvent)eventCode {
    if (eventCode == NSStreamEventEndEncountered) {
        if (musicStream == (NSInputStream *)stream) {
            [stream close];
            [stream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
            musicStream = nil;
            clientInfo.dataReceived = YES;
            musicData = [receiveMusicData copy];
            receiveMusicData = nil;
            BOOL loaded = YES;
            if ([self.delegate respondsToSelector:@selector(sharePlayManager:musicDataReceived:)]) {
                loaded = [self.delegate sharePlayManager:self musicDataReceived:musicData];
            }
            NSDictionary *ack = @{
                kSharePlayKeyDataType : @(SharePlayMessageTypeMusicSendComplete),
                kSharePlayKeySendData : @(loaded)
            };
            NSData *ackData = [NSKeyedArchiver archivedDataWithRootObject:ack];
            [self sendData:ackData toPeer:self.session.connectedPeers[0]];
        }
    } else if (eventCode == NSStreamEventErrorOccurred) {
        if (musicStream == (NSInputStream *)stream) {
            [stream close];
            [stream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
            musicStream = nil;
            receiveMusicData = nil;
        }
    } else if (eventCode == NSStreamEventHasBytesAvailable &&
               musicStream == (NSInputStream *)stream) {
        if (receiveMusicData == nil) {
            receiveMusicData = [[NSMutableData alloc] init];
        }
        uint8_t buffer[kSharePlayStreamReadBufferSize];
        NSInteger read = [musicStream read:buffer maxLength:kSharePlayStreamReadBufferSize];
        if (read != 0) {
            [receiveMusicData appendBytes:buffer length:read];
        }
        if ([self.delegate respondsToSelector:@selector(sharePlayManager:receiveProgress:)]) {
            dispatch_async(dispatch_get_main_queue(), ^{
              /** @ghidraAddress 0xc8d1c */
              float received = (float)receiveMusicData.length;
              float progress = received / (float)self->fileSize;
              if (progress > 1.0f) {
                  progress = 1.0f;
              }
              [self.delegate sharePlayManager:self receiveProgress:progress];
            });
        }
    }
}

#pragma mark - Accessors

- (NSString *)partnerScreenName {
    return partnerName;
}

@end

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :

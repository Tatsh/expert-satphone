/** @file
 * The local multiplayer ("share play" / versus) session manager.
 *
 * Reconstructed from Ghidra program Jubeat (class SharePlayManager, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * SharePlayManager wraps Apple's MultipeerConnectivity. In host mode it advertises the
 * @c jubeatplus1 service and, once a client connects, runs a small clock-synchronisation
 * handshake, streams the chart's music data over an NSOutputStream, and exchanges score and
 * end-of-play result data. In client mode it browses for a host, requests connection, receives
 * the music data, and reports its own results back. Every message is an
 * NSKeyedArchiver-serialised NSDictionary keyed by @c dataType (a message-type tag) and
 * @c sendData (the payload).
 */

#import <Foundation/Foundation.h>
#import <MultipeerConnectivity/MultipeerConnectivity.h>

@class SharePlayManager;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Delegate through which a SharePlayManager reports discovery, connection, data-transfer,
 * and gameplay-result events.
 */
@protocol SharePlayManagerDelegate <NSObject>

@optional
/**
 * @brief Reports the progress of the incoming music-data stream as a fraction in @c 0..1.
 * @param manager The reporting manager.
 * @param progress The received fraction, clamped to @c 1.0.
 */
- (void)sharePlayManager:(SharePlayManager *)manager receiveProgress:(float)progress;
/**
 * @brief A candidate host was discovered while browsing.
 * @param manager The reporting manager.
 * @param hostID The discovered host's peer identifier.
 */
- (void)sharePlayManager:(SharePlayManager *)manager findHostID:(MCPeerID *)hostID;
/**
 * @brief A previously discovered host is no longer reachable.
 * @param manager The reporting manager.
 * @param hostID The lost host's peer identifier.
 */
- (void)sharePlayManager:(SharePlayManager *)manager lostHostID:(MCPeerID *)hostID;
/**
 * @brief The client established a connection to the host.
 * @param manager The reporting manager.
 */
- (void)sharePlayManagerConnectHost:(SharePlayManager *)manager;
/**
 * @brief The client accepted a role change back to the ready-to-invite state after a drop.
 * @param manager The reporting manager.
 */
- (void)sharePlayManagerDisconnect:(SharePlayManager *)manager;
/**
 * @brief The host lost its client, or gave up clock synchronisation.
 * @param manager The reporting manager.
 * @param peer The peer that dropped.
 */
- (void)sharePlayManager:(SharePlayManager *)manager disconnectClient:(MCPeerID *)peer;
/**
 * @brief The host learned whether the client already has the music data.
 * @param manager The reporting manager.
 * @param exist Whether the client reported it already has the data.
 */
- (void)sharePlayManager:(SharePlayManager *)manager receiveExistMusicData:(BOOL)exist;
/**
 * @brief The music data was delivered to the client successfully.
 * @param manager The reporting manager.
 */
- (void)sharePlayManagerSuccessSendMusicData:(SharePlayManager *)manager;
/**
 * @brief The host chose the song and requested the shared play to begin.
 * @param manager The reporting manager.
 */
- (void)sharePlayManagerHostSelectStart:(SharePlayManager *)manager;
/**
 * @brief Requests that play begin after the given number of seconds, clock-corrected per side.
 * @param manager The reporting manager.
 * @param time Seconds from now until play should start.
 */
- (void)sharePlayManager:(SharePlayManager *)manager startMusicTime:(float)time;
/**
 * @brief The client received the song's metadata and is asked whether it accepts it.
 * @param manager The reporting manager.
 * @param musicInfo The song's metadata dictionary.
 * @return Whether the client already possesses the music data.
 */
- (BOOL)sharePlayManager:(SharePlayManager *)manager receiveMusicInfo:(NSDictionary *)musicInfo;
/**
 * @brief The client received the music data payload.
 * @param manager The reporting manager.
 * @param musicData The received music data.
 * @return Whether loading of the received data succeeded.
 */
- (BOOL)sharePlayManager:(SharePlayManager *)manager musicDataReceived:(NSData *)musicData;
/**
 * @brief Both sides signalled they are ready to load the chart.
 * @param manager The reporting manager.
 */
- (void)sharePlayManagerAllClientReady:(SharePlayManager *)manager;
/**
 * @brief Both sides finished loading the chart.
 * @param manager The reporting manager.
 */
- (void)sharePlayManagerAllClientLoaded:(SharePlayManager *)manager;
/**
 * @brief The clock handshake settled and the client connection is confirmed on the host.
 * @param manager The reporting manager.
 */
- (void)sharePlayManagerConnectClient:(SharePlayManager *)manager;
/**
 * @brief A mid-play score update arrived from the peer.
 * @param manager The reporting manager.
 * @param score The peer's score.
 */
- (void)sharePlayManager:(SharePlayManager *)manager receiveScore:(int)score;
/**
 * @brief The peer's end-of-play result arrived.
 * @param manager The reporting manager.
 * @param score The peer's final score.
 * @param bonus The peer's end-of-play bonus.
 * @param fullCombo Whether the peer achieved a full combo.
 */
- (void)sharePlayManager:(SharePlayManager *)manager
       receiveFinalScore:(int)score
                   bonus:(int)bonus
               fullCombo:(BOOL)fullCombo;

@end

/**
 * @brief Manages a two-peer MultipeerConnectivity session for shared ("versus") play.
 */
@interface SharePlayManager : NSObject <MCNearbyServiceBrowserDelegate,
                                        MCNearbyServiceAdvertiserDelegate,
                                        MCSessionDelegate,
                                        NSStreamDelegate>

/** @brief Whether this device is the host of the session. @ghidraAddress 0xc51d4 */
@property(nonatomic, readonly) BOOL isHost;
/** @brief The connected partner's display name, or nil before one connects. */
@property(nonatomic, readonly, nullable) NSString *partnerScreenName;
/** @brief The underlying multipeer session. */
@property(nonatomic, strong, nullable) MCSession *session;
/** @brief The event delegate. */
@property(nonatomic, weak, nullable) id<SharePlayManagerDelegate> delegate;
/** @brief The display name advertised for this device's peer. */
@property(nonatomic, assign, nullable) NSString *displayName;

/**
 * @brief Designated initialiser.
 * @param screenName The name to advertise, or nil to use the device name.
 * @return The initialised manager.
 * @ghidraAddress 0xc51e4
 */
- (instancetype)initWithScreenName:(nullable NSString *)screenName;

/** @brief Creates the MCSession bound to this device's peer. @ghidraAddress 0xc5324 */
- (void)sessionCreate;
/** @brief Starts browsing for a host as a client. @ghidraAddress 0xc53b8 */
- (void)startClient;
/**
 * @brief Starts advertising as a host with the chosen song.
 * @param musicInfo The song's metadata; the file size is added under @c fileSize.
 * @param filePath The path to the music data file.
 * @ghidraAddress 0xc54a8
 */
- (void)startHostModeWithMusicInfo:(NSDictionary *)musicInfo filePath:(NSString *)filePath;

/** @brief Tears down advertising, browsing, streams, and the session. @ghidraAddress 0xc5708 */
- (void)connectCancel;
/** @brief Disconnects from the session. @ghidraAddress 0xc5898 */
- (void)disconnect;

/** @brief Host: tells the client the song was chosen and play should begin. @ghidraAddress 0xc58a4
 */
- (void)sendSelectStart;
/** @brief Host: begins the clock-corrected start-of-play countdown. @ghidraAddress 0xc5954 */
- (void)startPlaySync;
/** @brief Client: tells the host it is ready to load the chart. @ghidraAddress 0xc5b6c */
- (void)sendClientReady;

/**
 * @brief A candidate host was found while browsing.
 * @ghidraAddress 0xc5c08
 */
- (void)browser:(MCNearbyServiceBrowser *)browser
            foundPeer:(MCPeerID *)peerID
    withDiscoveryInfo:(nullable NSDictionary<NSString *, NSString *> *)info;
/**
 * @brief A previously found host was lost.
 * @ghidraAddress 0xc5ccc
 */
- (void)browser:(MCNearbyServiceBrowser *)browser lostPeer:(MCPeerID *)peerID;
/**
 * @brief Browsing failed to start.
 * @ghidraAddress 0xc5d90
 */
- (void)browser:(MCNearbyServiceBrowser *)browser didNotStartBrowsingForPeers:(NSError *)error;

/**
 * @brief Advertising failed to start.
 * @ghidraAddress 0xc5d94
 */
- (void)advertiser:(MCNearbyServiceAdvertiser *)advertiser
    didNotStartAdvertisingPeer:(NSError *)error;
/**
 * @brief An invitation arrived while advertising; accepted only while @c bAccept is set.
 * @ghidraAddress 0xc5d98
 */
- (void)advertiser:(MCNearbyServiceAdvertiser *)advertiser
    didReceiveInvitationFromPeer:(MCPeerID *)peerID
                     withContext:(nullable NSData *)context
               invitationHandler:(void (^)(BOOL accept, MCSession *_Nullable session))handler;

/**
 * @brief Drives the connection state machine for a peer.
 * @param peer The peer whose state changed.
 * @param state The new session state.
 * @ghidraAddress 0xc5e98
 */
- (void)changeState:(MCPeerID *)peer state:(MCSessionState)state;

/**
 * @brief Session-state change callback; forwards to -changeState:state:.
 * @ghidraAddress 0xc62b8
 */
- (void)session:(MCSession *)session peer:(MCPeerID *)peerID didChangeState:(MCSessionState)state;
/**
 * @brief Decodes and dispatches a received message by its @c dataType tag.
 * @param session The session the data arrived on.
 * @param data The archived message payload.
 * @param peer The originating peer.
 * @ghidraAddress 0xc62cc
 */
- (void)receiveData:(MCSession *)session data:(NSData *)data fromPeer:(MCPeerID *)peer;
/**
 * @brief Data-received callback; defers handling to -receiveData:data:fromPeer: on the main queue.
 * @ghidraAddress 0xc70e4
 */
- (void)session:(MCSession *)session didReceiveData:(NSData *)data fromPeer:(MCPeerID *)peerID;
/**
 * @brief Stream-received callback; schedules the input stream and opens it.
 * @ghidraAddress 0xc7270
 */
- (void)session:(MCSession *)session
    didReceiveStream:(NSInputStream *)stream
            withName:(NSString *)streamName
            fromPeer:(MCPeerID *)peerID;
/**
 * @brief Resource-transfer start callback (unused).
 * @ghidraAddress 0xc731c
 */
- (void)session:(MCSession *)session
    didStartReceivingResourceWithName:(NSString *)resourceName
                             fromPeer:(MCPeerID *)peerID
                         withProgress:(NSProgress *)progress;
/**
 * @brief Resource-transfer finish callback (unused).
 * @ghidraAddress 0xc7320
 */
- (void)session:(MCSession *)session
    didFinishReceivingResourceWithName:(NSString *)resourceName
                              fromPeer:(MCPeerID *)peerID
                                 atURL:(nullable NSURL *)localURL
                             withError:(nullable NSError *)error;

/**
 * @brief Client: invites the given host peer to this device's session.
 * @param peer The host peer to invite.
 * @ghidraAddress 0xc7324
 */
- (void)sendConnectRequest:(MCPeerID *)peer;
/**
 * @brief Host: sends its current clock and counts a ping attempt.
 * @param peer The client peer.
 * @ghidraAddress 0xc73ec
 */
- (void)sendHostClock:(MCPeerID *)peer;

/** @brief Host: if both sides finished, exchanges and reports the final result. @ghidraAddress
 * 0xc7548 */
- (void)checkFinishStatus;
/**
 * @brief Records a mid-play score for the peer and notifies the delegate.
 * @param score The peer's score, boxed.
 * @ghidraAddress 0xc78fc
 */
- (void)receiveScore:(NSNumber *)score;
/**
 * @brief Records the peer's end-of-play result and reports or reconciles it.
 * @param finalData The peer's final-result dictionary.
 * @ghidraAddress 0xc79fc
 */
- (void)receiveFinalData:(NSDictionary *)finalData;

/** @brief Notifies the delegate once both sides have loaded the chart. @ghidraAddress 0xc7d64 */
- (void)checkMusicDataLoadingStatus;
/** @brief Marks this side's chart as loaded and reconciles or reports it. @ghidraAddress 0xc7e4c */
- (void)completeLoadingMusicData;

/**
 * @brief Sends a mid-play score to the peer.
 * @param score The score to send.
 * @ghidraAddress 0xc7f34
 */
- (void)sendScore:(int)score;
/**
 * @brief Sends the end-of-play result, or records it on the host.
 * @param score The final score.
 * @param bonus The end-of-play bonus.
 * @param fullCombo Whether a full combo was achieved.
 * @ghidraAddress 0xc80b8
 */
- (void)sendFinalScore:(int)score bonus:(int)bonus fullCombo:(BOOL)fullCombo;

/**
 * @brief Archives a bare message-type tag and sends it to the peer.
 * @param type The message-type tag.
 * @param peer The destination peer.
 * @ghidraAddress 0xc83b8
 */
- (void)sendTypeData:(int)type toPeer:(MCPeerID *)peer;
/**
 * @brief Sends an archived payload to a single peer reliably.
 * @param data The archived payload.
 * @param peer The destination peer.
 * @ghidraAddress 0xc84b0
 */
- (void)sendData:(NSData *)data toPeer:(MCPeerID *)peer;
/**
 * @brief Streams a payload to a peer over a one-shot NSOutputStream on a background queue.
 * @param data The payload to stream.
 * @param peer The destination peer.
 * @param dataName The stream name.
 * @ghidraAddress 0xc8568
 */
- (void)sendDataStream:(NSData *)data toPeer:(MCPeerID *)peer dataName:(NSString *)dataName;

/**
 * @brief Input-stream event handler; accumulates the incoming music data and acks completion.
 * @ghidraAddress 0xc8840
 */
- (void)stream:(NSStream *)stream handleEvent:(NSStreamEvent)eventCode;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :

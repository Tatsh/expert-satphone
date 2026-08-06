/** @file
 * One peer's state in a multipeer play session.
 *
 * Reconstructed from Ghidra program Jubeat (class SessionClass, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * RECONSTRUCTION STATE: complete. The runtime metadata declares one method beyond the property
 * accessors and it is implemented.
 *
 * The superclass was read from the class object's superclass slot at 0x34df80, which binds to
 * @c _OBJC_CLASS_$_NSObject at load time rather than being stored in the file.
 *
 * Every property below is transcribed from the class's property metadata, so the types and
 * attributes are the runtime's own rather than inferred from accessor code. The three timing
 * fields encode as @c f — single-precision @c float, not @c double or @c NSTimeInterval — and
 * @c pingTryCnt encodes as @c f as well despite counting attempts, which the initialiser
 * corroborates by zeroing it through a vector register.
 */

#import <Foundation/Foundation.h>
#import <MultipeerConnectivity/MultipeerConnectivity.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The per-peer record a multipeer session keeps.
 */
@interface SessionClass : NSObject

/** @brief The peer this record describes. */
@property(nonatomic, strong, nullable) MCPeerID *peerID;
/** @brief Measured round-trip delay to the peer, in seconds. */
@property(nonatomic) float delayTime;
/** @brief How many pings have been attempted. A float, per the metadata. */
@property(nonatomic) float pingTryCnt;
/** @brief When the current receive began. */
@property(nonatomic, strong, nullable) NSDate *receiveStartTime;
/** @brief How long the last receive took, in seconds. */
@property(nonatomic) float receiveTime;
/** @brief The peer's score, or -1 before one has been reported. */
@property(nonatomic) int score;
/** @brief The peer's end-of-play bonus. */
@property(nonatomic) int finalBonus;
/** @brief Whether the peer has finished playing. */
@property(nonatomic) BOOL finished;
/** @brief Whether the peer achieved a full combo. */
@property(nonatomic) BOOL fullcombo;
/** @brief Whether the peer has finished loading its chart. */
@property(nonatomic) BOOL dataLoaded;
/** @brief Whether the peer's data has arrived. */
@property(nonatomic) BOOL dataReceived;
/** @brief Whether the peer is ready to begin loading. */
@property(nonatomic) BOOL readyToLoad;
/** @brief Whether clock synchronisation with the peer has settled. */
@property(nonatomic) BOOL settledSync;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :

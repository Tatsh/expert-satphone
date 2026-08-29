/**
 * @file
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
 * The per-peer record a multipeer session keeps.
 */
@interface SessionClass : NSObject

/** The peer this record describes. */
@property(nonatomic, strong, nullable) MCPeerID *peerID;
/** Measured round-trip delay to the peer, in seconds. */
@property(nonatomic) float delayTime;
/** How many pings have been attempted. A float, per the metadata. */
@property(nonatomic) float pingTryCnt;
/** When the current receive began. */
@property(nonatomic, strong, nullable) NSDate *receiveStartTime;
/** How long the last receive took, in seconds. */
@property(nonatomic) float receiveTime;
/** The peer's score, or -1 before one has been reported. */
@property(nonatomic) int score;
/** The peer's end-of-play bonus. */
@property(nonatomic) int finalBonus;
/** Whether the peer has finished playing. */
@property(nonatomic) BOOL finished;
/** Whether the peer achieved a full combo. */
@property(nonatomic) BOOL fullcombo;
/** Whether the peer has finished loading its chart. */
@property(nonatomic) BOOL dataLoaded;
/** Whether the peer's data has arrived. */
@property(nonatomic) BOOL dataReceived;
/** Whether the peer is ready to begin loading. */
@property(nonatomic) BOOL readyToLoad;
/** Whether clock synchronisation with the peer has settled. */
@property(nonatomic) BOOL settledSync;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :

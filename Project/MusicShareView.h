/** @file
 * A modal "share music" panel over a dimmed, rounded gradient board: it lists the nearby peer
 * hosts a client can join, carries a status message and a spinning activity indicator, and offers
 * a single Cancel button.
 *
 * Reconstructed from Ghidra program Jubeat (class MusicShareView, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * The class overrides @c +layerClass to back itself with a @c CAGradientLayer , and it acts as its
 * own host table's data source and delegate. The host list is driven by the multipeer session:
 * peers are added and removed as they appear and vanish, and choosing a row tells the weak
 * @c MusicSelectViewController to connect to that host.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class MCPeerID;
@class MusicSelectViewController;

/**
 * @brief A modal peer-host picker for sharing music, laid over a dimmed gradient board.
 */
@interface MusicShareView : UIView <UITableViewDataSource, UITableViewDelegate>

/**
 * @brief The owning controller, told which host to connect to and when the panel is cancelled.
 *
 * Held weakly (the controller owns the view).
 */
@property(nonatomic, weak, nullable) MusicSelectViewController *controller;

/**
 * @brief Backs the view with a @c CAGradientLayer .
 * @return The @c CAGradientLayer class.
 * @ghidraAddress 0x1832d8
 */
+ (Class)layerClass;

/**
 * @brief Builds the whole modal: the gradient board, its host icon and join-background images, the
 * status message label, the (initially detached) host table with its inner shadow, the Cancel
 * button, and the activity indicator.
 *
 * The board takes the frame it is given; there is no per-idiom or per-theme sizing here.
 *
 * @param frame The board's frame, sized by the caller.
 * @return The initialised panel.
 * @ghidraAddress 0x1832ec
 */
- (instancetype)initWithFrame:(CGRect)frame;

/**
 * @brief Cancel button action: tells the controller to cancel the share.
 * @param sender The Cancel button. Unused.
 * @ghidraAddress 0x183d6c
 */
- (void)pushCancel:(nullable id)sender;

/**
 * @brief Enters the searching state: shows "Searching hosts", makes the host table selectable, and
 * adds the table and its inner-shadow overlay to the board.
 * @ghidraAddress 0x183db0
 */
- (void)changeClientModeSearch;

/**
 * @brief Enters the connecting state: locks the host table against selection and shows
 * "Connecting".
 * @ghidraAddress 0x183ec0
 */
- (void)changeClientModeConnecting;

/**
 * @brief Enters the connected state: detaches the host table as data source and delegate, fades it
 * and its shadow out and removes them, and starts the activity indicator spinning.
 * @ghidraAddress 0x183f78
 */
- (void)changeClientModeConnected;

/**
 * @brief Adds a discovered host, taking its display name from the peer itself, and reloads the
 * table with an inserted row.
 * @param host The peer that was found.
 * @ghidraAddress 0x1842c4
 */
- (void)addHost:(nonnull MCPeerID *)host;

/**
 * @brief Removes a host row, resetting the message to "Searching hosts" once the list empties.
 *
 * Byte-for-byte identical to @c -removeHost: in the binary.
 *
 * @param host The peer to remove.
 * @ghidraAddress 0x1844f4
 */
- (void)removeHostTmp:(nonnull MCPeerID *)host;

/**
 * @brief Adds a discovered host under an explicit display name and reloads the table with an
 * inserted row.
 * @param host The peer that was found.
 * @param name The display name to show for that peer.
 * @ghidraAddress 0x184704
 */
- (void)addHost:(nonnull MCPeerID *)host name:(nonnull NSString *)name;

/**
 * @brief Removes a host row, resetting the message to "Searching hosts" once the list empties.
 *
 * Byte-for-byte identical to @c -removeHostTmp: in the binary.
 *
 * @param host The peer to remove.
 * @ghidraAddress 0x18492c
 */
- (void)removeHost:(nonnull MCPeerID *)host;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :

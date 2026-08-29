/**
 * @file
 * @brief The bottom bar of the music-select screen: an all-songs / playlists button on the left,
 * a jubeat Lab. button on the right, and a scrolling "new store info" ticker between them.
 *
 * Reconstructed from Ghidra program Jubeat (class MusicSelectBottomView, image base 0x100000000).
 * All @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c UIView, taken from the dyld bind at the class object's superclass slot.
 */

#import <UIKit/UIKit.h>

@class MusicPlaylistManager;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief What a @c MusicSelectBottomView tells its owner (the music-select controller).
 *
 * The delegate is weak and untyped in the metadata; it is messaged directly after a
 * @c -respondsToSelector: guard rather than through a declared conformance, so every selector is
 * effectively optional. Each method forwards the matching bar event.
 */
@protocol MusicSelectBottomViewDelegate <NSObject>
@optional
/**
 * @brief The playlists button was tapped.
 * @param sender The tapped button.
 */
- (void)tapPlaylists:(nullable id)sender;
/**
 * @brief The jubeat Lab. button was tapped.
 * @param sender The tapped button.
 */
- (void)tapJubeatLab:(nullable id)sender;
/**
 * @brief The store-info ticker was tapped.
 * @param info A dictionary describing the tapped link (a @c "pack", @c "genre", or @c "challenge"
 * target), or @c nil when the URL opened externally or carried no in-app target.
 */
- (void)tapStoreInfo:(nullable NSDictionary *)info;
/**
 * @brief A bar control went down (touch-began): the delegate can show a pressed state.
 * @param sender The pressed control.
 */
- (void)btnTouchesBegan:(nullable id)sender;
/**
 * @brief A bar control's touch was cancelled: the delegate can clear a pressed state.
 * @param sender The released control.
 */
- (void)btnTouchesCancel:(nullable id)sender;
@end

/**
 * @brief The music-select screen's bottom bar.
 *
 * Lays out three controls sized to the bar's own height (30 points): a left playlists button, a
 * right jubeat Lab. button, and a centred store-info ticker built from a background image view, a
 * scroll view, and an @c InfoLabel. The ticker cycles messages drawn from @c arrayStoreInfo with a
 * fade-in, a marquee scroll, and a fade-out driven by a repeating @c NSTimer.
 */
@interface MusicSelectBottomView : UIView

/**
 * @brief The object told about bar-button and ticker taps. Held weakly.
 * @ghidraAddress 0x1d7cbc (getter), 0x1d7cdc (setter)
 */
@property(nonatomic, weak, nullable) id<MusicSelectBottomViewDelegate> aDelegate;

/**
 * @brief The playlist model consulted to name a custom playlist. Held weakly.
 * @ghidraAddress 0x1d7cf0 (getter), 0x1d7d10 (setter)
 */
@property(nonatomic, weak, nullable) MusicPlaylistManager *playlistManager;

/**
 * @brief Builds the bar: the playlists button, the jubeat Lab. button, and the store-info ticker
 * (background image view, scroll view, and @c InfoLabel), all sized to the bar height.
 * @param frame The bar's frame.
 * @return The initialised view.
 * @ghidraAddress 0x1d5824
 */
- (instancetype)initWithFrame:(CGRect)frame;

/**
 * @brief The playlists button's action: forwards to the delegate.
 * @param sender The tapped button.
 * @ghidraAddress 0x1d672c
 */
- (void)tapPlaylists:(nullable id)sender;

/**
 * @brief A control's touch-down action: forwards to the delegate so it can show a pressed state.
 * @param sender The pressed control.
 * @ghidraAddress 0x1d67dc
 */
- (void)btnTouchesBegan:(nullable id)sender;

/**
 * @brief A control's touch-cancel action: forwards to the delegate so it can clear a pressed state.
 * @param sender The released control.
 * @ghidraAddress 0x1d688c
 */
- (void)btnTouchesCancel:(nullable id)sender;

/**
 * @brief The playlists button's frame in the bar's own coordinate space.
 * @return The playlists button's frame.
 * @ghidraAddress 0x1d693c
 */
- (CGRect)getPlayListBtnRect;

/**
 * @brief Retitles or re-icons the playlists button for the selected playlist.
 *
 * On the phone the button carries a title string; on the pad it carries an artwork icon. The
 * argument is a sentinel index: -12/-11/-2 are the "all songs" variants, -10 the level playlist,
 * -1 the not-yet-played playlist, a negative default clears the button, and any non-negative index
 * names the custom playlist through @c playlistManager (phone) or shows the custom icon (pad).
 *
 * @param index The selected playlist's sentinel or custom index.
 * @ghidraAddress 0x1d69ac
 */
- (void)playlistButtonChanged:(NSInteger)index;

/**
 * @brief The store-info ticker's action: resolves the current message's link and forwards it to
 * the delegate.
 *
 * A @c jbtstore:// URL with a @c pack or @c genre path becomes a one-entry dictionary; a
 * @c jbtchallenge:// URL becomes a @c challenge dictionary; any other scheme is opened externally
 * and reported as @c nil.
 *
 * @param sender The tapped ticker button.
 * @ghidraAddress 0x1d6dec
 */
- (void)tapStoreInfo:(nullable id)sender;

/**
 * @brief Installs the ticker's message list and starts the cycle.
 *
 * Copies the messages, picks a random starting index, shows the ticker button, schedules the
 * repeating hide timer, and shows the first message.
 *
 * @param table The array of message dictionaries (each carrying @c "Message" and @c "Link" keys).
 * @ghidraAddress 0x1d7278
 */
- (void)setCommentTable:(nullable NSArray *)table;

/**
 * @brief Shows the next ticker message: sets the label text, resets the scroll, fades the label in,
 * then scrolls it to its end (the marquee).
 * @ghidraAddress 0x1d7410
 */
- (void)showNextStoreText;

/**
 * @brief Hides the current ticker message: disables the button, advances the index, and fades the
 * label out, then shows the next message.
 * @ghidraAddress 0x1d79d8
 */
- (void)hideStoreText;

/**
 * @brief Stops the ticker button's title animation by removing all layer animations.
 * @ghidraAddress 0x1d7ba0
 */
- (void)animStop;

/**
 * @brief The jubeat Lab. button's action: forwards to the delegate.
 * @param sender The tapped button.
 * @ghidraAddress 0x1d7c0c
 */
- (void)tapJubeatLab:(nullable id)sender;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :

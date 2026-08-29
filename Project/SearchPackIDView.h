/**
 * @file
 * @brief The modal board that looks up which purchasable pack contains a given tune.
 *
 * Reconstructed from Ghidra program Jubeat (class SearchPackIDView, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c UIView: @c -initWithTuneID:type:delegate: calls @c -[super initWithFrame:]
 * with the board's own size (0x114778). The view is itself the gradient-backed board —
 * @c +layerClass returns @c CAGradientLayer — shown over a dimmed parent. It owns a @c Downloader
 * whose JSON POST resolves the comprised-pack id for a music id, and it is that downloader's
 * delegate: @c -downloaderFinished: parses the pack id and message out of the response, then
 * reports the outcome to its own delegate, which reads the result back with @c -getPackID and
 * @c -getRecommendString .
 */

#import <UIKit/UIKit.h>

#import "Downloader.h"

NS_ASSUME_NONNULL_BEGIN

@class SearchPackIDView;
@class TuneInfo;

/**
 * @brief What a @c SearchPackIDView tells its owner once the pack lookup settles.
 *
 * All three messages are dispatched with @c -performSelector: after a @c -respondsToSelector:
 * guard, so all are optional, and each carries the view itself so the owner can read the result
 * back with @c -getPackID and @c -getRecommendString .
 */
@protocol SearchPackIDViewDelegate <NSObject>
@optional
/**
 * @brief Sent when the lookup resolved a pack (or a social recommend string).
 * @param view The modal.
 */
- (void)packIDSearchEnd:(nullable SearchPackIDView *)view;
/**
 * @brief Sent when the lookup completed but no pack contains the tune.
 * @param view The modal.
 */
- (void)packIDSearchFailed:(nullable SearchPackIDView *)view;
/**
 * @brief Sent from the Cancel/Close button, whether the lookup is still running or has settled.
 * @param view The modal.
 */
- (void)packIDSearchCancel:(nullable SearchPackIDView *)view;
@end

/**
 * @brief A gradient-backed board that resolves the pack owning a tune and reports the outcome.
 */
@interface SearchPackIDView : UIView <DownloaderDelegate>

/**
 * @brief The layer class backing the board: a @c CAGradientLayer .
 * @return The @c CAGradientLayer class.
 * @ghidraAddress 0x114274
 */
+ (Class)layerClass;

/**
 * @brief A @c StoreButton factory helper.
 *
 * Builds a blue-green rounded @c StoreButton , but neither stores nor adds it: the binary discards
 * the result, and the sender argument is ignored.
 * @param sender Ignored.
 * @ghidraAddress 0x114288
 */
- (void)createStoreBtn:(nullable id)sender;

/**
 * @brief Whether a music id is a built-in bundle tune.
 *
 * True only when the app bundle carries a @c Music resource and the id appears in
 * @c -[StoreMusicListManager builtinMusic] .
 * @param musicID The music id to test.
 * @return @c YES if the tune ships with the app.
 * @ghidraAddress 0x1143c0
 */
- (BOOL)isBundleMusic:(int)musicID;

/**
 * @brief Builds the modal for the tune carried by a music object and starts the pack lookup.
 *
 * Forwards to @c -initWithTuneID:type:delegate: after reading the tune's @c -tuneID .
 * @param music The tune whose @c -tuneID identifies it.
 * @param type The social service type, or @c nil for a plain pack lookup.
 * @param delegate The object told the outcome; held weakly.
 * @return The initialised view.
 * @ghidraAddress 0x1145d4
 */
- (instancetype)initWithID:(nullable TuneInfo *)music
                      type:(nullable NSString *)type
                  delegate:(nullable id<SearchPackIDViewDelegate>)delegate;

/**
 * @brief Builds the board, its label, the three buttons, and the spinner, then posts the lookup.
 *
 * The board is @c 320 wide and @c 360 tall on a pad, and @c 300 square otherwise. The move-to-store
 * (@c btnOK ) and end (@c btnEnd ) buttons start fully transparent, flanking the centre; the
 * centred @c btnCancel is the visible one. The owned @c Downloader is built with a JSON POST to the
 * recommend or pack-search endpoint but is not started here — @c -startDownload begins it.
 * @param tuneID The tune id to search packs for.
 * @param type The social service type, or @c nil for a plain pack lookup.
 * @param delegate The object told the outcome; held weakly.
 * @return The initialised view.
 * @ghidraAddress 0x114684
 */
- (instancetype)initWithTuneID:(unsigned int)tuneID
                          type:(nullable NSString *)type
                      delegate:(nullable id<SearchPackIDViewDelegate>)delegate;

/**
 * @brief Cancel/Close button action: cancels the lookup and tells the delegate
 * @c -packIDSearchCancel: .
 * @param sender The button.
 * @ghidraAddress 0x115830
 */
- (void)pushCancel:(nullable id)sender;

/**
 * @brief Overlays the full-board progress label and starts the pack-lookup download.
 * @ghidraAddress 0x1158f0
 */
- (void)startDownload;

/**
 * @brief @c DownloaderDelegate : the lookup failed; shows the failure message.
 * @param downloader The failed downloader.
 * @ghidraAddress 0x115aa0
 */
- (void)downloaderError:(nullable Downloader *)downloader;

/**
 * @brief @c DownloaderDelegate : the lookup completed; parses the pack id and message, then reports
 * end, not-found, or failure.
 * @param downloader The finished downloader.
 * @ghidraAddress 0x115ad8
 */
- (void)downloaderFinished:(nullable Downloader *)downloader;

/**
 * @brief Shows the download-failed message and retitles the button Close.
 * @ghidraAddress 0x115cd4
 */
- (void)searchPackFailed;

/**
 * @brief Shows the no-pack message, retitles the button Close, and tells the delegate
 * @c -packIDSearchFailed: .
 * @ghidraAddress 0x115e14
 */
- (void)notFindPackID;

/**
 * @brief The pack id resolved by the lookup.
 * @return The comprised-pack id, or @c nil when none was found.
 * @ghidraAddress 0x115fd4
 */
- (nullable NSNumber *)getPackID;

/**
 * @brief The recommend/message string the lookup returned.
 * @return The @c "Message" text from the response, or @c nil.
 * @ghidraAddress 0x115fe4
 */
- (nullable NSString *)getRecommendString;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :

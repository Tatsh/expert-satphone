/** @file
 * A tappable genre banner button in the store's pack list.
 *
 * Reconstructed from Ghidra program Jubeat (class StoreGenreBannerView, image base 0x100000000).
 * All @ghidraAddress values are offsets relative to that image base. The class object is at
 * 0x351628.
 */

#import <UIKit/UIKit.h>

#import "Downloader.h"
#import "StorePackListGenre.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief What a @c StoreGenreBannerView tells its owner.
 */
@protocol StoreGenreBannerViewDelegate <NSObject>
@optional
/**
 * @brief Sent when the banner is tapped.
 * @param bannerView The banner that was tapped.
 */
- (void)tapGenreBtn:(nonnull id)bannerView;
@end

/**
 * @brief A rounded genre banner showing a title over an optional downloaded artwork.
 */
@interface StoreGenreBannerView : UIButton <DownloaderDelegate>

/**
 * @brief The object told when the banner is tapped.
 *
 * Weak and untyped in the metadata, so the dispatch goes through @c -respondsToSelector: rather
 * than a declared conformance.
 */
@property(nonatomic, weak, nullable) id delegate;

/**
 * @brief Builds the banner's shadow layer, artwork button, and title label.
 * @param frame The banner's frame.
 * @return The initialised banner.
 * @ghidraAddress 0x1fd02c
 */
- (instancetype)initWithFrame:(CGRect)frame;

/**
 * @brief Fills the banner from a genre record and, when it has an artwork URL, starts a fetch.
 * @param info The genre record.
 * @ghidraAddress 0x1fd62c
 */
- (void)setGenreInfo:(nullable StorePackListGenre *)info;

/**
 * @brief The tap handler: tells the delegate the banner was tapped.
 * @param sender The banner button.
 * @ghidraAddress 0x1fd88c
 */
- (void)tapGenreBanner:(nonnull id)sender;

/**
 * @brief Applies the selected or unselected appearance to the banner's border, background, and
 * shadow.
 * @param selected Whether the banner is selected.
 * @ghidraAddress 0x1fd940
 */
- (void)setSelectColor:(BOOL)selected;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :

/** @file
 * The heading above a store genre's pack list.
 *
 * Reconstructed from Ghidra program Jubeat (class StoreGenreTitleView, image base 0x100000000).
 * All @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c UIView, from the dyld bind at the class object's superclass slot
 * (0x350410).
 *
 * The pad and the phone get different views, not just different metrics: the pad has a background
 * image and a separate title label, and the phone has neither — its comment label carries
 * everything, over a plain translucent background.
 *
 * RECONSTRUCTION STATE: three of four members written. @c -setGenreTitleInfo: is declared but not
 * reconstructed; see RECONSTRUCTION_STATUS.md.
 */

#import <UIKit/UIKit.h>

#import "Downloader.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief What a @c StoreGenreTitleView tells its owner.
 *
 * The protocol's name is the binary's own, from the delegate ivar's encoding
 * @c \@"<StoreGenreTitleViewDelegate>" .
 */
@protocol StoreGenreTitleViewDelegate <NSObject>
@end

/**
 * @brief A genre heading with a title, a description, and an optional downloaded banner.
 */
@interface StoreGenreTitleView : UIView <DownloaderDelegate>

/**
 * @brief The object told about the heading's events.
 */
@property(nonatomic, weak, nullable) id<StoreGenreTitleViewDelegate> delegate;

/**
 * @brief Builds the heading, differently per idiom.
 *
 * @param frame The heading's frame.
 * @return The initialised heading.
 * @ghidraAddress 0x1b37b8
 */
- (instancetype)initWithFrame:(CGRect)frame;

/**
 * @brief Fills the heading in from a genre record.
 *
 * DECLARED ONLY — the body has not been reconstructed yet.
 *
 * @param info The genre record.
 * @return An integer whose meaning is not yet established.
 * @ghidraAddress 0x1b3b3c
 */
- (int)setGenreTitleInfo:(nullable id)info;

/**
 * @brief Puts a banner up and fades it in.
 *
 * The fade is driven from zero every time, so re-setting the image replays the animation.
 *
 * @param image The banner.
 * @ghidraAddress 0x1b3ff0
 */
- (void)setBannerImage:(nullable UIImage *)image;

/**
 * @brief Takes the fetched banner, and caches it under its address.
 *
 * Ignores any downloader that is not the one this view started.
 *
 * @param downloader The finished fetch.
 * @ghidraAddress 0x1b4178
 */
- (void)downloaderFinished:(id)downloader;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :

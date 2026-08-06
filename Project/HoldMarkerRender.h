/** @file
 * Draws the hold markers and their tails over the sixteen-panel grid.
 *
 * Reconstructed from Ghidra program Jubeat (class HoldMarkerRender, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c NSObject, from the dyld bind at the class object's superclass slot
 * (0x34e8e0).
 *
 * RECONSTRUCTION STATE: three of four members written. @c -renderHoldMarker:end: is declared but
 * not reconstructed; see RECONSTRUCTION_STATUS.md.
 */

#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>

#import "Texture2D.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief One panel's hold-marker state.
 *
 * The metadata types it @c {?=iIII} — anonymous, sixteen bytes, one signed and three unsigned
 * 32-bit fields. The field names are inferred from use, not recovered; the struct carries no
 * name of its own in the binary.
 */
typedef struct {
    int direction;      /*!< Which way the tail runs. Indexes the four arms of the line renderer. */
    unsigned int start; /*!< The frame the hold began on. */
    unsigned int end;   /*!< The frame the hold ends on. */
    unsigned int state; /*!< The marker's animation state. */
} HoldMarkerInfo;

/**
 * @brief Draws hold markers from a sixteen-entry panel array.
 */
@interface HoldMarkerRender : NSObject

/**
 * @brief Builds a renderer bound to a texture.
 *
 * @param tex The sprite sheet to draw from. Held **weakly** — the store is @c objc_storeWeak , not
 * @c objc_storeStrong , which the ivar's own encoding does not record.
 * @param isPad Whether to use the pad's metrics.
 * @param gameAreaDelay The play area's frame delay.
 * @return The initialised renderer.
 * @ghidraAddress 0xe7e18
 */
- (instancetype)init:(nullable Texture2D *)tex isPad:(BOOL)isPad gameAreaDelay:(int)gameAreaDelay;

/**
 * @brief Draws one hold tail between two panels.
 *
 * The tail runs either vertically or horizontally depending on @c vector , and the rectangle is
 * built differently in each of the four arms. **An out-of-range @c vector draws with uninitialised
 * geometry** rather than drawing nothing; see TYPES_PENDING.md.
 *
 * @param endPoint The far end of the tail.
 * @param startPoint The near end.
 * @param vector Which of the four directions the tail runs in. Only 0 to 3 are handled.
 * @param trans The texture transform.
 * @param alpha The opacity.
 * @param frame Which sprite of the tail animation to draw.
 * @param addLength How far past the panel the tail extends.
 * @ghidraAddress 0xe7eb8
 */
- (void)renderHoldLine:(CGPoint)endPoint
                 start:(CGPoint)startPoint
                vector:(int)vector
                 trans:(char)trans
                 alpha:(float)alpha
                 frame:(int)frame
             addLength:(int)addLength;

/**
 * @brief Draws every panel's hold marker.
 *
 * @param markers A sixteen-entry array, one per panel of the grid.
 * @ghidraAddress 0xe8674
 */
- (void)renderHoldMarker:(nullable HoldMarkerInfo *)markers;

/**
 * @brief Draws one panel's hold marker.
 *
 * DECLARED ONLY — the body has not been reconstructed yet.
 *
 * @param marker The panel's state, passed by value.
 * @param end The panel's index, 0 to 15.
 * @ghidraAddress 0xe80a4
 */
- (void)renderHoldMarker:(HoldMarkerInfo)marker end:(int)end;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :

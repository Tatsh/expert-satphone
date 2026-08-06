/** @file
 * The marker asset manager.
 *
 * Reconstructed from Ghidra program Jubeat (class MarkerManager, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * RECONSTRUCTION STATE: a stub grown outwards from its callers. Only the two class methods
 * @c -[JubeatAppDelegate application:didFinishLaunchingWithOptions:] sends are declared. The class
 * object is at 0x3480d0.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Owns the marker assets and their on-disk layout.
 *
 * Both members below are sent to the class, not to an instance, and neither takes an argument or
 * has its result read.
 */
@interface MarkerManager : NSObject

/**
 * @brief Migrates marker data into the Documents directory.
 *
 * Sent at 0x9a90, first of the pair and unconditional. DECLARED ONLY.
 */
+ (void)moveMarkerDataInDoc;
/**
 * @brief Validates the built-in marker data.
 *
 * Sent at 0x9aa0 immediately after the migration, with no test between them. DECLARED ONLY.
 */
+ (void)checkRegularMarkerData;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :

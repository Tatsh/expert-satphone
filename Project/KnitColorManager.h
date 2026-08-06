/** @file
 * The knit-colour palette manager.
 *
 * Reconstructed from Ghidra program Jubeat (class KnitColorManager, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * RECONSTRUCTION STATE: a stub grown outwards from its caller. The class object at 0x3480a0 has
 * seven cross-references; only the member reached so far is declared.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Holds the knit colour palette.
 */
@interface KnitColorManager : NSObject

/**
 * @brief The shared instance.
 */
@property(class, nonatomic, readonly) KnitColorManager *sharedManager;

/**
 * @brief Replaces the palette from an array of colour components.
 *
 * Called from @c -[JubeatAppDelegate setKnitColor:] at 0x8f88, which is its only call site. The
 * element type is not established: the delegate passes its argument straight through without
 * touching it.
 */
- (void)setColorWithArray:(NSArray *)colors;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :

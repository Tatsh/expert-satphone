/**
 * @file SettingsMapItem.h
 * @brief A map annotation for a shop location in the settings map view.
 *
 * Reconstructed from Ghidra program Jubeat (image base 0x100000000). All @ghidraAddress values are
 * offsets relative to that image base.
 *
 * The @c MKAnnotation the @c SettingsMapViewController drops for each shop: its coordinate, the
 * title and subtitle shown in the callout, and the device model tag. It declares no initialiser of
 * its own, so it is a direct @c NSObject subclass built with @c +alloc / @c -init.
 */

#import <Foundation/Foundation.h>
#import <MapKit/MapKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief One pin on the settings map, carrying its coordinate and callout text.
 */
@interface SettingsMapItem : NSObject <MKAnnotation>

/** @brief The annotation's map coordinate. */
@property(nonatomic, assign) CLLocationCoordinate2D coordinate;

/** @brief The callout title. */
@property(nonatomic, copy, nullable) NSString *title;

/** @brief The callout subtitle. */
@property(nonatomic, copy, nullable) NSString *subtitle;

/** @brief The device model tag. Encodes as @c Q . */
@property(nonatomic, assign) NSUInteger model;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :

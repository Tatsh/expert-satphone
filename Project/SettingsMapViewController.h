/**
 * @file
 * The settings-screen map view controller.
 *
 * Reconstructed from Ghidra program Jubeat (class SettingsMapViewController, image base
 * 0x100000000). All @ghidraAddress values are offsets relative to that image base. It presents an
 * @c MKMapView of collaboration and event "spots", requesting Core Location authorisation through a
 * @c CLLocationManager, KVO-observing the map's user location to recentre once on first fix,
 * downloading the spot list through a @c Downloader, dropping @c SettingsMapItem pin annotations
 * for every spot inside the visible map rectangle, and recentring on either the current location or
 * a "Corabo" collaboration position from the navigation-bar buttons.
 */

#import <CoreLocation/CoreLocation.h>
#import <MapKit/MapKit.h>
#import <UIKit/UIKit.h>

#import "AlertViewManager.h"
#import "Downloader.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * A view controller presenting collaboration and event spots on a map.
 */
@interface SettingsMapViewController : UIViewController <CLLocationManagerDelegate,
                                                         MKMapViewDelegate,
                                                         AlertViewManagerDelegate,
                                                         DownloaderDelegate>

/**
 * The map presenting the spot annotations.
 * @ghidraAddress 0x119240
 */
@property(strong, nonatomic, nullable) MKMapView *mapView;

/**
 * The loading indicator shown while the spot list downloads.
 * @ghidraAddress 0x119264
 */
@property(strong, nonatomic, nullable) UIActivityIndicatorView *indicator;

/**
 * The label prompting the user to zoom in when the region is too wide.
 * @ghidraAddress 0x119288
 */
@property(strong, nonatomic, nullable) UILabel *messageLabel;

/**
 * The location manager used to request and track authorisation.
 * @ghidraAddress 0x1192ac
 */
@property(strong, nonatomic, nullable) CLLocationManager *locationManager;

/**
 * The downloader fetching the spot list.
 * @ghidraAddress 0x1192d0
 */
@property(strong, nonatomic, nullable) Downloader *listDownloader;

/**
 * The spots keyed by identifier, so each is dropped only once.
 * @ghidraAddress 0x1192f4
 */
@property(strong, nonatomic, nullable) NSMutableDictionary *dictSpot;

/**
 * The Google Maps URL opened from a spot's callout accessory.
 * @ghidraAddress 0x119318
 */
@property(strong, nonatomic, nullable) NSString *mapURL;

/**
 * Initialises the controller, its navigation-bar buttons, location manager, and spot store.
 * @return The initialised controller.
 * @ghidraAddress 0x11610c
 */
- (instancetype)init;

/**
 * Builds the map, loading indicator, and prompt label, sizing them to the device idiom.
 * @ghidraAddress 0x11659c
 */
- (void)loadView;

/**
 * Whether Core Location is enabled and authorised for use while in front.
 * @return @c YES when location services are on and authorisation is granted.
 * @ghidraAddress 0x116dc0
 */
- (BOOL)currentLocationEnabled;

/**
 * Requests the spot list for a region, cancelling any request already in flight.
 * @param region The map region to request spots for; retained as the last requested region.
 * @ghidraAddress 0x116e2c
 */
- (void)requestList:(MKCoordinateRegion)region;

/**
 * Recentres the map on the current location, if enabled.
 * @param sender The button that triggered the action.
 * @ghidraAddress 0x117034
 */
- (void)pushCurrent:(nullable id)sender;

/**
 * Recentres the map on the "Corabo" collaboration position.
 * @param sender The button that triggered the action.
 * @ghidraAddress 0x11711c
 */
- (void)pushCorabo:(nullable id)sender;

/**
 * Starts observing the user location once authorisation is granted.
 * @param manager The location manager reporting the change.
 * @param status The new authorisation status.
 * @ghidraAddress 0x117174
 */
- (void)locationManager:(CLLocationManager *)manager
    didChangeAuthorizationStatus:(CLAuthorizationStatus)status;

/**
 * Recentres on the first user-location fix, then stops observing.
 * @param keyPath The observed key path.
 * @param object The observed object.
 * @param change The change dictionary.
 * @param context The observer context.
 * @ghidraAddress 0x117248
 */
- (void)observeValueForKeyPath:(nullable NSString *)keyPath
                      ofObject:(nullable id)object
                        change:(nullable NSDictionary *)change
                       context:(nullable void *)context;

/**
 * Refreshes the visible annotations when the region changes, refetching if the map has moved
 *        far enough.
 * @param mapView The map whose region changed.
 * @param animated Whether the change was animated.
 * @ghidraAddress 0x117394
 */
- (void)mapView:(MKMapView *)mapView regionDidChangeAnimated:(BOOL)animated;

/**
 * Builds the pin view for a spot annotation.
 * @param mapView The map requesting the view.
 * @param annotation The annotation to build a view for.
 * @return The annotation view, or @c nil for the user-location annotation.
 * @ghidraAddress 0x1179f4
 */
- (nullable MKAnnotationView *)mapView:(MKMapView *)mapView
                     viewForAnnotation:(id<MKAnnotation>)annotation;

/**
 * Opens the tapped spot in Google Maps after confirming with an alert.
 * @param mapView The map whose callout accessory was tapped.
 * @param view The annotation view whose accessory was tapped.
 * @param control The tapped accessory control.
 * @ghidraAddress 0x117cb8
 */
- (void)mapView:(MKMapView *)mapView
                   annotationView:(MKAnnotationView *)view
    calloutAccessoryControlTapped:(UIControl *)control;

/**
 * Opens the pending map URL when the confirmation alert's second button is chosen.
 * @param info The alert result, whose @c btnMessage carries the chosen button index.
 * @ghidraAddress 0x11802c
 */
- (void)alertSelect:(NSDictionary *)info;

/**
 * Parses the finished download into spot annotations, or the Corabo position.
 * @param downloader The downloader that finished.
 * @ghidraAddress 0x118158
 */
- (void)downloaderFinished:(id)downloader;

/**
 * Stops the indicator when the spot-list download fails.
 * @param downloader The downloader that errored.
 * @ghidraAddress 0x118bf4
 */
- (void)downloaderError:(id)downloader;

/**
 * Centres the map on the initial region and requests its spot list.
 * @ghidraAddress 0x118cac
 */
- (void)viewDidLoad;

/**
 * Stops observing the user location and releases the map, indicator, and label.
 * @ghidraAddress 0x118d90
 */
- (void)viewDidUnload;

/**
 * Forwards to the superclass.
 * @param animated Whether the appearance is animated.
 * @ghidraAddress 0x118e88
 */
- (void)viewWillAppear:(BOOL)animated;

/**
 * Starts observing the user location if needed and briefly ignores interaction events.
 * @param animated Whether the appearance is animated.
 * @ghidraAddress 0x118ec0
 */
- (void)viewDidAppear:(BOOL)animated;

/**
 * Stops observing the user location and drops the map delegate.
 * @param animated Whether the disappearance is animated.
 * @ghidraAddress 0x118ff0
 */
- (void)viewWillDisappear:(BOOL)animated;

/**
 * Forwards to the superclass.
 * @param animated Whether the disappearance is animated.
 * @ghidraAddress 0x1190bc
 */
- (void)viewDidDisappear:(BOOL)animated;

/**
 * Whether to rotate to a given interface orientation; portrait orientations only.
 * @param interfaceOrientation The orientation to test.
 * @ghidraAddress 0x1190f4
 */
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation;

/**
 * The supported interface orientations: portrait and portrait-upside-down.
 * @return Both portrait orientations.
 * @ghidraAddress 0x119104
 */
- (UIInterfaceOrientationMask)supportedInterfaceOrientations;

/**
 * Whether the controller supports autorotation; always @c YES.
 * @return Always YES.
 * @ghidraAddress 0x11910c
 */
- (BOOL)shouldAutorotate;

/**
 * Stops observing, drops the map delegate, and cancels the spot-list download.
 * @ghidraAddress 0x119114
 */
- (void)dealloc;

/**
 * Closes the map; a no-op in the shipped binary.
 * @ghidraAddress 0x11923c
 */
- (void)mapClose;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :

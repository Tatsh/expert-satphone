#import "SettingsMapViewController.h"

#import "ImageCache.h"
#import "ImageLoading.h"
#import "JubeatAppDelegate.h"
#import "ScratchUtil.h"
#import "SettingsMapItem.h"
#import "StringUtilities.h"

// The typed-accessor category the spot dictionaries are read through; a category on NSDictionary
// not reconstructed as its own file yet. See TYPES_PENDING.md.
@interface NSDictionary (TypedAccessors)
- (nullable NSNumber *)numberForKey:(nonnull id)key;
- (nullable NSString *)stringForKey:(nonnull id)key;
- (nullable NSArray *)arrayForKey:(nonnull id)key;
@end

@interface SettingsMapViewController () {
    MKCoordinateRegion _lastRegion;  // The last region requested from the spot list.
    BOOL _isObservingLocation;       // Whether the user-location KVO observer is registered.
    BOOL _firstLocationObserved;     // Whether the initial location fix has recentred the map.
    Downloader *_optDownloader;      // The Corabo (Ochazuke) campaign-position downloader.
    CLLocationCoordinate2D _carPos;  // The Corabo collaboration position.
    SettingsMapItem *_optAnnotation; // The Corabo collaboration annotation.
    UIBarButtonItem *_optPosBtn;     // The navigation-bar button recentring on the Corabo spot.
    UIColor *_btnColor;              // The saved tint restored on the Corabo button when enabled.
}
@end

// The pin-model tag the Corabo collaboration spot carries; distinct from the cop and sau spot
// models so the annotation view loads the correct texture.
static const int kSettingsMapItemModelCorabo = 9999;

// The spot models the downloaded list encodes as its Model string.
typedef NS_ENUM(int, SettingsMapSpotModel) {
    SettingsMapSpotModelDefault = 0, /*!< An ordinary jubeat store spot. */
    SettingsMapSpotModelCop = 1,     /*!< A "cop" collaboration spot. */
    SettingsMapSpotModelSau = 2,     /*!< A "sau" collaboration spot. */
};

// The spot-list request format and endpoint.
static NSString *const kSpotListRequestFormat = @"lat=%.6f&long=%.6f&range=%.6f";
static NSString *const kSpotListURL = @"https://agx.s.konaminet.jp/agx/main/cgi/gamecenterlist/";
static NSString *const kGoogleMapsURLFormat = @"https://map.google.com/maps?q=%0.6f,%0.6f+(%@)";

// The spot-list response keys.
static NSString *const kSpotListKeyGameCenterList = @"GameCenterList";
static NSString *const kSpotKeyID = @"ID";
static NSString *const kSpotKeyLat = @"Lat";
static NSString *const kSpotKeyLong = @"Long";
static NSString *const kSpotKeyName = @"Name";
static NSString *const kSpotKeyOpen = @"Open";
static NSString *const kSpotKeyModel = @"Model";
static NSString *const kSpotModelCop = @"cop";
static NSString *const kSpotModelSau = @"sau";
static NSString *const kSpotSubtitleFormat = @"営業時間: %@";

// The Corabo (Ochazuke) campaign-position response keys.
static NSString *const kCampKeyStatus = @"status";
static NSString *const kCampKeyMapList = @"camp_map_list";
static NSString *const kCampKeyPosX = @"pos_x";
static NSString *const kCampKeyPosY = @"pos_y";
static NSString *const kCampKeyName = @"name";
static NSString *const kCampKeyDescription = @"description";

// The KVO key path observed on the map's user location.
static NSString *const kUserLocationKeyPath = @"location";

// The reuse identifier for the spot pin annotation views.
static NSString *const kPinReuseIdentifier = @"PinIdentifier";

// The pin textures loaded for each spot model.
static NSString *const kSpotTextureNameSau = @"ac_map_pin";
static NSString *const kSpotTextureNameCorabo = @"map_pin_naga";
static NSString *const kSpotTextureNameDefault = @"ac_map_pin_cop";

// The alertSelect: result key carrying the chosen button index.
static NSString *const kAlertResultButtonKey = @"btnMessage";

// The tag stamped on the "open in Maps?" confirmation alert.
static const int kMapConfirmAlertTag = 1;

@implementation SettingsMapViewController

#pragma mark - Lifecycle

/** @ghidraAddress 0x11610c */
- (instancetype)init {
    self = [super init];
    if (self) {
        self.navigationItem.title = @"SEARCH";
        UIBarButtonItem *currentButton = [[UIBarButtonItem alloc]
            initWithTitle:[NSBundle.mainBundle localizedStringForKey:@"Current Location"
                                                               value:@""
                                                               table:nil]
                    style:UIBarButtonItemStyleDone
                   target:self
                   action:@selector(pushCurrent:)];
        // The Corabo button title reads "永谷園" (Nagatanien), the campaign partner.
        UIBarButtonItem *coraboButton = [[UIBarButtonItem alloc]
            initWithTitle:[NSBundle.mainBundle localizedStringForKey:@"永谷園" value:@"" table:nil]
                    style:UIBarButtonItemStyleDone
                   target:self
                   action:@selector(pushCorabo:)];
        _optPosBtn = coraboButton;
        _btnColor = _optPosBtn.tintColor;
        [_optPosBtn setEnabled:NO];
        // colorWithWhite:0 alpha:0 in the binary.
        _optPosBtn.tintColor = [UIColor colorWithWhite:0 alpha:0];
        self.navigationItem.rightBarButtonItems = @[ currentButton, _optPosBtn ];
        if ([self respondsToSelector:@selector(setExtendedLayoutIncludesOpaqueBars:)]) {
            [self performSelector:@selector(setExtendedLayoutIncludesOpaqueBars:) withObject:nil];
        }
        self.locationManager = [[CLLocationManager alloc] init];
        if ([self.locationManager respondsToSelector:@selector(requestWhenInUseAuthorization)]) {
            [self.locationManager requestWhenInUseAuthorization];
        }
        self.locationManager.delegate = self;
        self.dictSpot = [NSMutableDictionary dictionaryWithCapacity:64];
        _isObservingLocation = NO;
        _firstLocationObserved = NO;
    }
    return self;
}

/** @ghidraAddress 0x11659c */
- (void)loadView {
    [super loadView];
    // The pad uses a fixed 540x620 canvas (pool constants at 0x28f900 and 0x291c78); the phone
    // uses its screen bounds. The map frame origin is CGRectZero's (0, 0) either way.
    CGFloat width;
    CGFloat height;
    if ([JubeatAppDelegate.appDelegate isPad]) {
        width = 540.0;
        height = 620.0;
    } else {
        CGRect bounds = UIScreen.mainScreen.bounds;
        width = bounds.size.width;
        height = bounds.size.height;
    }
    CGFloat navBarHeight = self.navigationController.navigationBar.frame.size.height;
    self.mapView = [[MKMapView alloc] initWithFrame:CGRectMake(0, 0, width, height - navBarHeight)];
    self.mapView.showsUserLocation = YES;
    self.mapView.delegate = self;
    [self.view addSubview:self.mapView];

    self.indicator = [[UIActivityIndicatorView alloc]
        initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    // Anchored to the right edge, 36 points in from the width, at a 32x32 size.
    self.indicator.frame = CGRectMake(width + -36.0, 4.0, 32.0, 32.0);
    self.indicator.hidesWhenStopped = YES;
    self.indicator.backgroundColor = [UIColor colorWithWhite:0 alpha:0.5];
    self.indicator.layer.cornerRadius = 4.0;
    [self.mapView addSubview:self.indicator];

    UILabel *label =
        [[UILabel alloc] initWithFrame:CGRectMake((width + -280.0) * 0.5, 40.0, 280.0, 60.0)];
    self.messageLabel = label;
    self.messageLabel.opaque = NO;
    // colorWithWhite:0 alpha:0.6 in the binary.
    self.messageLabel.backgroundColor = [UIColor colorWithWhite:0 alpha:0.6000000238418579];
    self.messageLabel.font = [UIFont boldSystemFontOfSize:18.0];
    self.messageLabel.numberOfLines = 2;
    self.messageLabel.text = @"店舗を表示するには\n地図を拡大して下さい";
    self.messageLabel.textColor = UIColor.whiteColor;
    self.messageLabel.textAlignment = NSTextAlignmentCenter;
    self.messageLabel.layer.cornerRadius = 8.0;
    self.messageLabel.alpha = 0;
    [self.mapView addSubview:self.messageLabel];

    if ([JubeatAppDelegate.appDelegate isNagaCoraMode]) {
        NSURL *ochazukeURL = [ScratchUtil getOchazukeURL];
        _optDownloader = [[Downloader alloc] initWithURL:ochazukeURL delegate:self];
        [_optDownloader startDownloading];
    }
}

/** @ghidraAddress 0x118cac */
- (void)viewDidLoad {
    [super viewDidLoad];
    // The initial region centres on Japan (35.681382, 139.766084) with a small span.
    MKCoordinateRegion region;
    region.center = CLLocationCoordinate2DMake(35.681382, 139.766084);
    region.span = MKCoordinateSpanMake(0.01004, 0.01159);
    [self.mapView setRegion:region animated:NO];
    [self requestList:region];
}

/** @ghidraAddress 0x118d90 */
- (void)viewDidUnload {
    [super viewDidUnload];
    if (_isObservingLocation) {
        [self.mapView.userLocation removeObserver:self forKeyPath:kUserLocationKeyPath];
        _isObservingLocation = NO;
    }
    self.mapView = nil;
    self.indicator = nil;
    self.messageLabel = nil;
}

/** @ghidraAddress 0x118e88 */
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}

/** @ghidraAddress 0x118ec0 */
- (void)viewDidAppear:(BOOL)animated {
    if ([self currentLocationEnabled] && !_firstLocationObserved && !_isObservingLocation) {
        [self.mapView.userLocation addObserver:self
                                    forKeyPath:kUserLocationKeyPath
                                       options:0
                                       context:nil];
        _isObservingLocation = YES;
    }
    [UIApplication.sharedApplication beginIgnoringInteractionEvents];
    [UIApplication.sharedApplication performSelector:@selector(endIgnoringInteractionEvents)
                                          withObject:nil
                                          afterDelay:0.5];
}

/** @ghidraAddress 0x118ff0 */
- (void)viewWillDisappear:(BOOL)animated {
    if (_isObservingLocation) {
        [self.mapView.userLocation removeObserver:self forKeyPath:kUserLocationKeyPath];
        _isObservingLocation = NO;
    }
    self.mapView.delegate = nil;
}

/** @ghidraAddress 0x1190bc */
- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
}

/** @ghidraAddress 0x119114 */
- (void)dealloc {
    if (_isObservingLocation) {
        [self.mapView.userLocation removeObserver:self forKeyPath:kUserLocationKeyPath];
        _isObservingLocation = NO;
    }
    self.mapView.delegate = nil;
    [self.listDownloader cancel];
}

#pragma mark - Rotation

/** @ghidraAddress 0x1190f4 */
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return interfaceOrientation - 1 < 2;
}

/** @ghidraAddress 0x119104 */
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskPortraitUpsideDown;
}

/** @ghidraAddress 0x11910c */
- (BOOL)shouldAutorotate {
    return YES;
}

#pragma mark - Location authorisation

/** @ghidraAddress 0x116dc0 */
- (BOOL)currentLocationEnabled {
    if (![CLLocationManager locationServicesEnabled]) {
        return NO;
    }
    if (![CLLocationManager respondsToSelector:@selector(authorizationStatus)]) {
        return YES;
    }
    return [CLLocationManager authorizationStatus] == kCLAuthorizationStatusAuthorizedWhenInUse;
}

/** @ghidraAddress 0x117174 */
- (void)locationManager:(CLLocationManager *)manager
    didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
    if (status == kCLAuthorizationStatusAuthorizedWhenInUse && !_firstLocationObserved &&
        !_isObservingLocation) {
        [self.mapView.userLocation addObserver:self
                                    forKeyPath:kUserLocationKeyPath
                                       options:0
                                       context:nil];
        _isObservingLocation = YES;
    }
}

/** @ghidraAddress 0x117248 */
- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
    [self.mapView setCenterCoordinate:self.mapView.userLocation.location.coordinate animated:YES];
    [self.mapView.userLocation removeObserver:self forKeyPath:kUserLocationKeyPath];
    _isObservingLocation = NO;
    _firstLocationObserved = YES;
}

#pragma mark - Recentring

/** @ghidraAddress 0x117034 */
- (void)pushCurrent:(id)sender {
    if ([self currentLocationEnabled]) {
        [self.mapView setCenterCoordinate:self.mapView.userLocation.location.coordinate
                                 animated:YES];
    }
}

/** @ghidraAddress 0x11711c */
- (void)pushCorabo:(id)sender {
    [self.mapView setCenterCoordinate:_carPos animated:YES];
}

#pragma mark - Spot list

/** @ghidraAddress 0x116e2c */
- (void)requestList:(MKCoordinateRegion)region {
    NSString *body = [NSString stringWithFormat:kSpotListRequestFormat,
                                                region.center.latitude,
                                                region.center.longitude,
                                                0.27];
    if (self.listDownloader) {
        [self.listDownloader cancel];
    }
    self.listDownloader =
        [[Downloader alloc] initWithURL:[NSURL URLWithString:kSpotListURL]
                               postData:[body dataUsingEncoding:NSUTF8StringEncoding]
                               delegate:self];
    _lastRegion = region;
    [self.listDownloader startDownloading];
    [self.indicator startAnimating];
}

/** @ghidraAddress 0x118158 */
- (void)downloaderFinished:(id)downloader {
    if (self.listDownloader == downloader) {
        NSDictionary *json = [self.listDownloader getDataInJSON];
        NSArray *list = json ? [json arrayForKey:kSpotListKeyGameCenterList] : nil;
        if (json && list) {
            MKCoordinateRegion region = self.mapView.region;
            MKMapPoint topLeft = MKMapPointForCoordinate(CLLocationCoordinate2DMake(
                region.center.latitude + region.span.latitudeDelta * 0.5,
                region.center.longitude - region.span.longitudeDelta * 0.5));
            MKMapPoint bottomRight = MKMapPointForCoordinate(CLLocationCoordinate2DMake(
                region.center.latitude - region.span.latitudeDelta * 0.5,
                region.center.longitude + region.span.longitudeDelta * 0.5));
            MKMapRect visibleRect = MKMapRectMake(topLeft.x,
                                                  topLeft.y,
                                                  ABS(bottomRight.x - topLeft.x),
                                                  ABS(bottomRight.y - topLeft.y));
            for (id entry in list) {
                if (![entry isKindOfClass:[NSDictionary class]]) {
                    continue;
                }
                NSDictionary *spot = entry;
                NSNumber *spotID = [spot numberForKey:kSpotKeyID];
                NSNumber *lat = [spot numberForKey:kSpotKeyLat];
                NSNumber *lng = [spot numberForKey:kSpotKeyLong];
                NSString *name = [spot stringForKey:kSpotKeyName];
                NSString *open = [spot stringForKey:kSpotKeyOpen];
                if (spotID && lat && lng && name && open) {
                    NSString *model = [spot stringForKey:kSpotKeyModel];
                    if ([self.dictSpot objectForKey:spotID] == nil) {
                        CLLocationCoordinate2D coordinate =
                            CLLocationCoordinate2DMake(lat.doubleValue, lng.doubleValue);
                        SettingsMapItem *item = [[SettingsMapItem alloc] init];
                        item.title = name;
                        item.subtitle = [NSString stringWithFormat:kSpotSubtitleFormat, open];
                        if ([model isEqualToString:kSpotModelCop]) {
                            item.model = SettingsMapSpotModelCop;
                        }
                        // The binary sets the cop model above, then immediately overwrites it here
                        // with 2 (sau) or 0, so a "cop" spot ends up with model 0. Kept as shipped.
                        item.model = [model isEqualToString:kSpotModelSau] ?
                                         SettingsMapSpotModelSau :
                                         SettingsMapSpotModelDefault;
                        item.coordinate = coordinate;
                        self.dictSpot[spotID] = item;
                        if (MKMapRectContainsPoint(visibleRect,
                                                   MKMapPointForCoordinate(coordinate))) {
                            [self.mapView addAnnotation:item];
                        }
                    }
                }
            }
        }
        self.listDownloader = nil;
        [self.indicator stopAnimating];
    } else if (_optDownloader == downloader) {
        NSDictionary *json = [downloader getDataInJSON];
        if ([[json objectForKey:kCampKeyStatus] intValue] == 0) {
            NSArray *campList = [json objectForKey:kCampKeyMapList];
            if (campList.count) {
                NSNumber *posX = [campList[0] objectForKey:kCampKeyPosX];
                NSNumber *posY = [campList[0] objectForKey:kCampKeyPosY];
                _carPos = CLLocationCoordinate2DMake(posX.doubleValue, posY.doubleValue);
                MKCoordinateRegion region = self.mapView.region;
                MKMapPoint topLeft = MKMapPointForCoordinate(CLLocationCoordinate2DMake(
                    region.center.latitude + region.span.latitudeDelta * 0.5,
                    region.center.longitude - region.span.longitudeDelta * 0.5));
                MKMapPoint bottomRight = MKMapPointForCoordinate(CLLocationCoordinate2DMake(
                    region.center.latitude - region.span.latitudeDelta * 0.5,
                    region.center.longitude + region.span.longitudeDelta * 0.5));
                MKMapRect visibleRect = MKMapRectMake(topLeft.x,
                                                      topLeft.y,
                                                      ABS(bottomRight.x - topLeft.x),
                                                      ABS(bottomRight.y - topLeft.y));
                _optAnnotation = [[SettingsMapItem alloc] init];
                _optAnnotation.title = [campList[0] objectForKey:kCampKeyName];
                _optAnnotation.subtitle = [campList[0] objectForKey:kCampKeyDescription];
                _optAnnotation.model = kSettingsMapItemModelCorabo;
                _optAnnotation.coordinate = _carPos;
                [_optPosBtn setEnabled:YES];
                _optPosBtn.tintColor = _btnColor;
                if (MKMapRectContainsPoint(visibleRect, MKMapPointForCoordinate(_carPos))) {
                    [self.mapView addAnnotation:_optAnnotation];
                }
            }
        }
    }
}

/** @ghidraAddress 0x118bf4 */
- (void)downloaderError:(id)downloader {
    if (self.listDownloader != downloader) {
        return;
    }
    self.listDownloader = nil;
    [self.indicator stopAnimating];
}

#pragma mark - MKMapViewDelegate

/** @ghidraAddress 0x117394 */
- (void)mapView:(MKMapView *)mapView regionDidChangeAnimated:(BOOL)animated {
    MKCoordinateRegion region = self.mapView.region;
    MKMapPoint topLeft = MKMapPointForCoordinate(
        CLLocationCoordinate2DMake(region.center.latitude + region.span.latitudeDelta * 0.5,
                                   region.center.longitude - region.span.longitudeDelta * 0.5));
    MKMapPoint bottomRight = MKMapPointForCoordinate(
        CLLocationCoordinate2DMake(region.center.latitude - region.span.latitudeDelta * 0.5,
                                   region.center.longitude + region.span.longitudeDelta * 0.5));
    // When the longitude span exceeds 0.26 the map is too wide: drop every pin and prompt to zoom.
    if (region.span.longitudeDelta > 0.26) {
        [self.mapView removeAnnotations:self.mapView.annotations];
        self.messageLabel.alpha = 1.0;
        return;
    }
    MKMapRect visibleRect = MKMapRectMake(
        topLeft.x, topLeft.y, ABS(bottomRight.x - topLeft.x), ABS(bottomRight.y - topLeft.y));
    self.messageLabel.alpha = 0;
    for (id<MKAnnotation> annotation in self.mapView.annotations) {
        if (!MKMapRectContainsPoint(visibleRect, MKMapPointForCoordinate(annotation.coordinate))) {
            [self.mapView removeAnnotation:annotation];
        }
    }
    for (id spotID in self.dictSpot) {
        SettingsMapItem *item = [self.dictSpot objectForKey:spotID];
        if (MKMapRectContainsPoint(visibleRect, MKMapPointForCoordinate(item.coordinate))) {
            [self.mapView addAnnotation:item];
        }
    }
    if (MKMapRectContainsPoint(visibleRect, MKMapPointForCoordinate(_carPos))) {
        [self.mapView addAnnotation:_optAnnotation];
    }
    // Refetch only when centred inside Japan's bounding box (latitude 24.45..154, longitude
    // 20.5..45.6) and the map has moved more than 15% of the last request's range.
    if (region.center.longitude < 154.0 && region.center.longitude > 24.45 &&
        region.center.latitude > 20.5 && region.center.latitude < 45.6) {
        CLLocation *last = [[CLLocation alloc] initWithLatitude:_lastRegion.center.latitude
                                                      longitude:_lastRegion.center.longitude];
        CLLocation *now = [[CLLocation alloc] initWithLatitude:region.center.latitude
                                                     longitude:region.center.longitude];
        if ([last distanceFromLocation:now] / 111133.3 > 0.15000000000000002) {
            [self requestList:region];
        }
    }
}

/** @ghidraAddress 0x1179f4 */
- (nullable MKAnnotationView *)mapView:(MKMapView *)mapView
                     viewForAnnotation:(id<MKAnnotation>)annotation {
    if (self.mapView.userLocation == annotation) {
        return nil;
    }
    MKAnnotationView *view =
        [mapView dequeueReusableAnnotationViewWithIdentifier:kPinReuseIdentifier];
    if (view == nil) {
        view = [[MKAnnotationView alloc] initWithAnnotation:annotation
                                            reuseIdentifier:kPinReuseIdentifier];
        view.centerOffset = CGPointMake(5.0, -18.0);
        view.canShowCallout = YES;
        UIButton *accessory = [UIButton buttonWithType:UIButtonTypeDetailDisclosure];
        view.rightCalloutAccessoryView = accessory;
    }
    if (![annotation isKindOfClass:[SettingsMapItem class]]) {
        view.annotation = annotation;
    } else {
        SettingsMapItem *item = (SettingsMapItem *)annotation;
        UIImage *image;
        if (item.model == SettingsMapSpotModelSau) {
            image = [[ImageCache sharedCache] getResPNG:kSpotTextureNameSau];
        } else if (item.model == kSettingsMapItemModelCorabo) {
            view.image = LoadScaledEncryptedTexImage(kSpotTextureNameCorabo);
            return view;
        } else {
            image = [[ImageCache sharedCache] getResPNG:kSpotTextureNameDefault];
        }
        view.image = image;
    }
    return view;
}

/** @ghidraAddress 0x117cb8 */
- (void)mapView:(MKMapView *)mapView
                   annotationView:(MKAnnotationView *)view
    calloutAccessoryControlTapped:(UIControl *)control {
    if (self.mapURL) {
        self.mapURL = nil;
    }
    self.mapURL = [[NSString alloc] initWithFormat:kGoogleMapsURLFormat,
                                                   view.annotation.coordinate.latitude,
                                                   view.annotation.coordinate.longitude,
                                                   CreateUrlEncodedString(view.annotation.title)];
    [[AlertViewManager sharedManager]
             makeAlert:0
              delegate:self
                   tag:kMapConfirmAlertTag
                 title:view.annotation.title
                   msg:@"この場所を\n『マップ』で開きますか?"
                cancel:[NSBundle.mainBundle localizedStringForKey:@"Cancel" value:@"" table:nil]
               btnText:@[ [NSBundle.mainBundle localizedStringForKey:@"OK" value:@"" table:nil] ]
                  show:YES
        viewController:self];
}

#pragma mark - AlertViewManagerDelegate

/** @ghidraAddress 0x11802c */
- (void)alertSelect:(NSDictionary *)info {
    if ([[info objectForKey:kAlertResultButtonKey] intValue] == 1) {
        if (self.mapURL) {
            [UIApplication.sharedApplication openURL:[NSURL URLWithString:self.mapURL]];
        }
    }
}

#pragma mark - Actions

/** @ghidraAddress 0x11923c */
- (void)mapClose {
}

@end

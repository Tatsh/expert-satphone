#import "SettingsMapItem.h"

@implementation SettingsMapItem {
    CLLocationCoordinate2D _coordinate;
}

- (CLLocationCoordinate2D)coordinate {
    return _coordinate;
}

- (void)setCoordinate:(CLLocationCoordinate2D)coordinate {
    _coordinate = coordinate;
}

@end

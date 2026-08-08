#import "collectionCell.h"

#import "JubeatAppDelegate.h"

// MusicView is not reconstructed as its own file yet, so it is reached through a forward
// declaration here. Its selectors are noted in TYPES_PENDING.md.
@interface MusicView : UIView
- (instancetype)initWithFrame:(CGRect)frame
                  artworkSize:(double)artworkSize
                      colType:(int)colType
                    labelDisp:(BOOL)labelDisp;
- (void)setInfo:(nullable id)info bArtistNameDisp:(BOOL)artistNameDisp;
- (void)setDelegate:(nullable id)delegate;
- (nullable UIImageView *)imgView;
- (void)clearInfo;
- (nullable id)tuneInfo;
@end

@interface MusicTuneInfoStub : NSObject
- (int)tuneID;
@end

// The hosted music view's frame and artwork size by idiom. On the phone the height depends on the
// device type (a 106-point band on type 2, 101 otherwise).
static const CGFloat kCellWidthPad = 220.0;         // @ghidraAddress 0x28f430
static const CGFloat kCellWidthPhone = 100.0;       // @ghidraAddress 0x28f3f0
static const CGFloat kCellArtworkPad = 160.0;       // @ghidraAddress 0x28f438
static const CGFloat kCellArtworkPhone = 80.0;      // @ghidraAddress 0x28f3f8
static const CGFloat kCellHeightPad = 210.0;        // @ghidraAddress 0x28f200
static const CGFloat kCellHeightPhoneType2 = 106.0; // @ghidraAddress 0x28f320
static const CGFloat kCellHeightPhoneOther = 101.0; // @ghidraAddress 0x28f328

// The device type whose phone layout uses the taller cell.
static const NSInteger kCellDeviceTypeTall = 2;

@implementation collectionCell {
    MusicView *view;  // ivar-offset global 0x349aa4
    id aDelegate;     // the artwork-loading delegate
    BOOL bDispArtist; // whether the music view shows the artist name (isPad)
}

/** @ghidraAddress 0x3ac18 */
- (void)initCell:(id)info
    parentDelegate:(id)parentDelegate
          viewType:(int)viewType
         labelDisp:(BOOL)labelDisp {
    aDelegate = parentDelegate;
    BOOL isPad = JubeatAppDelegate.appDelegate.isPad;
    NSInteger deviceType = JubeatAppDelegate.appDelegate.deviceType;
    self.autoresizesSubviews = YES;
    self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    bDispArtist = isPad;

    // A fresh cell replaces any previously hosted music view.
    if (view) {
        [view removeFromSuperview];
        view = nil;
    }
    if (!view) {
        CGFloat width = isPad ? kCellWidthPad : kCellWidthPhone;
        CGFloat artworkSize = isPad ? kCellArtworkPad : kCellArtworkPhone;
        CGFloat height = isPad ? kCellHeightPad :
                                 (deviceType == kCellDeviceTypeTall ? kCellHeightPhoneType2 :
                                                                      kCellHeightPhoneOther);
        view = [[MusicView alloc] initWithFrame:CGRectMake(0, 0, width, height)
                                    artworkSize:artworkSize
                                        colType:viewType
                                      labelDisp:labelDisp];
        [view setDelegate:parentDelegate];
        [self addSubview:view];
    }
    // Reset the hosted view for reuse.
    view.imgView.image = nil;
    [view clearInfo];
    view.hidden = NO;
}

/** @ghidraAddress 0x3ae74 */
- (void)refleshText:(BOOL)animated {
    // The device idiom is queried but the result is discarded; the method is otherwise inert.
    (void)JubeatAppDelegate.appDelegate.isPad;
}

/** @ghidraAddress 0x3aebc */
- (void)setInfo:(id)info index:(int)index {
    view.tag = index;
    [view setInfo:info bArtistNameDisp:bDispArtist];
    if ([aDelegate respondsToSelector:@selector(loadArtworkForInfo:)]) {
        [aDelegate performSelector:@selector(loadArtworkForInfo:) withObject:view];
    }
}

/** @ghidraAddress 0x3afbc */
- (void)setInfo:(id)info {
    [view setInfo:info bArtistNameDisp:bDispArtist];
    if ([aDelegate respondsToSelector:@selector(loadArtworkForInfo:)]) {
        [aDelegate performSelector:@selector(loadArtworkForInfo:) withObject:view];
    }
}

/** @ghidraAddress 0x3b084 */
- (MusicView *)getMusicView {
    return view;
}

/** @ghidraAddress 0x3b094 */
- (int)getTuneID {
    return [(MusicTuneInfoStub *)[view tuneInfo] tuneID];
}

/** @ghidraAddress 0x3b0ec */
- (BOOL)existMusicView {
    return view != nil;
}

@end

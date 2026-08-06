#import "StoreDialogView.h"

// The panel itself: a rounded, grey-bordered, semi-transparent black slab with a soft shadow.
static const CGFloat kPanelCornerRadius = 8.0;
static const CGFloat kPanelBorderWidth = 2.0;
static const CGFloat kPanelShadowRadius = 8.0;
static const float kPanelShadowOpacity = 0.5f;
static const CGFloat kPanelBackgroundAlpha = 0.7f; // @ghidraAddress 0x291c98

// The spinner: a fixed square, centred horizontally and set a fifth of the way down.
static const CGFloat kIndicatorSize = 40.0;         // @ghidraAddress 0x28f1f8
static const CGFloat kIndicatorCentreRatioY = 0.2f; // @ghidraAddress 0x28f240

// The message: full width less a margin either side, and eighteen point.
static const CGFloat kMessageWidthInset = -30.0;
static const CGFloat kMessageHeight = 24.0;
static const CGFloat kMessageFontSize = 18.0;

// How far -layout: moves the message off the panel's centre in each of its two modes.
static const CGFloat kMessageOffsetProgressHidden = 10.0;
static const CGFloat kMessageOffsetProgressShown = -10.0;

// The progress bar: inset thirty points either side, just below the panel's middle.
static const CGFloat kProgressX = 30.0;
static const CGFloat kProgressWidthInset = -60.0; // @ghidraAddress 0x291bc8
static const CGFloat kProgressHeight = 11.0;
static const CGFloat kProgressOffsetY = 10.0;
static const float kProgressInitialValue = 0.3f; // @ghidraAddress 0x28e0b0

// The abort button: a fixed size, centred horizontally, low on the panel. Orange when live and a
// darker orange when not.
static const CGFloat kAbortWidth = 140.0;         // @ghidraAddress 0x28f6a8
static const CGFloat kAbortHeight = 36.0;         // @ghidraAddress 0x28f530
static const CGFloat kAbortRed = 0.756f;          // @ghidraAddress 0x291d98
static const CGFloat kAbortGreen = 0.212f;        // @ghidraAddress 0x291da0
static const CGFloat kAbortBlue = 0.042f;         // @ghidraAddress 0x291da8
static const CGFloat kAbortDisabledRed = 0.45f;   // @ghidraAddress 0x291d20
static const CGFloat kAbortDisabledGreen = 0.15f; // @ghidraAddress 0x291db0
static const CGFloat kAbortCornerRadius = 5.0;
static const CGFloat kAbortFontSize = 20.0;
static const CGFloat kAbortCentreRatioY = 0.83f; // @ghidraAddress 0x291db8

// Half, used to centre against the panel's own size.
static const CGFloat kHalf = 0.5;

@implementation StoreDialogView

/** @ghidraAddress 0xd6c20 */
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.contentScaleFactor = UIScreen.mainScreen.scale;
        self.opaque = NO;
        self.layer.cornerRadius = kPanelCornerRadius;
        self.layer.borderColor = UIColor.grayColor.CGColor;
        self.layer.borderWidth = kPanelBorderWidth;
        self.layer.shadowRadius = kPanelShadowRadius;
        self.layer.shadowOffset = CGSizeZero;
        self.layer.shadowOpacity = kPanelShadowOpacity;
        self.layer.shouldRasterize = YES;
        self.backgroundColor = [UIColor colorWithWhite:0 alpha:kPanelBackgroundAlpha];

        self.indicatorView = [[UIActivityIndicatorView alloc]
            initWithFrame:CGRectMake(0, 0, kIndicatorSize, kIndicatorSize)];
        self.indicatorView.activityIndicatorViewStyle = UIActivityIndicatorViewStyleWhiteLarge;
        // The vertical centres here and on the button are truncated to whole points before being
        // used, so the subviews land on pixel boundaries whatever the panel's height.
        self.indicatorView.center = CGPointMake(frame.size.width * kHalf,
                                                (int)(frame.size.height * kIndicatorCentreRatioY));
        [self addSubview:self.indicatorView];

        self.labelMessage = [[UILabel alloc]
            initWithFrame:CGRectMake(0, 0, frame.size.width + kMessageWidthInset, kMessageHeight)];
        self.labelMessage.backgroundColor = UIColor.clearColor;
        self.labelMessage.textColor = UIColor.whiteColor;
        self.labelMessage.textAlignment = NSTextAlignmentCenter;
        self.labelMessage.numberOfLines = 1;
        self.labelMessage.font = [UIFont systemFontOfSize:kMessageFontSize];
        [self addSubview:self.labelMessage];

        self.progressView =
            [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleBar];
        self.progressView.frame = CGRectMake(kProgressX,
                                             (int)(frame.size.height * kHalf) + kProgressOffsetY,
                                             frame.size.width + kProgressWidthInset,
                                             kProgressHeight);
        // A non-zero starting value, so the bar is visible before the first real update.
        self.progressView.progress = kProgressInitialValue;
        [self addSubview:self.progressView];

        self.buttonAbort =
            [[StoreButton alloc] initWithFrame:CGRectMake(0, 0, kAbortWidth, kAbortHeight)];
        self.buttonAbort.buttonColor = [UIColor colorWithRed:kAbortRed
                                                       green:kAbortGreen
                                                        blue:kAbortBlue
                                                       alpha:1.0];
        self.buttonAbort.disabledColor = [UIColor colorWithRed:kAbortDisabledRed
                                                         green:kAbortDisabledGreen
                                                          blue:0
                                                         alpha:1.0];
        self.buttonAbort.cornerRadius = kAbortCornerRadius;
        self.buttonAbort.exclusiveTouch = YES;
        self.buttonAbort.titleLabel.font = [UIFont boldSystemFontOfSize:kAbortFontSize];
        [self.buttonAbort setTitle:NSLocalizedString(@"Abort", nil) forState:UIControlStateNormal];
        [self.buttonAbort addTarget:self
                             action:@selector(btnAbort:)
                   forControlEvents:UIControlEventTouchUpInside];
        self.buttonAbort.center =
            CGPointMake(frame.size.width * kHalf, (int)(frame.size.height * kAbortCentreRatioY));
        [self addSubview:self.buttonAbort];
    }
    return self;
}

/** @ghidraAddress 0xd765c */
- (void)layout:(BOOL)hidden {
    CGSize size = self.frame.size;
    // The two arms are spelled out rather than folded: both pass a literal to -setHidden: rather
    // than the parameter, so the branch is in the source and not something the compiler made.
    if (hidden) {
        // With the bar and the button gone the message drops below the panel's centre to take
        // their place.
        self.progressView.hidden = YES;
        self.buttonAbort.hidden = YES;
        self.labelMessage.center =
            CGPointMake(size.width * kHalf, size.height * kHalf + kMessageOffsetProgressHidden);
    } else {
        self.progressView.hidden = NO;
        self.buttonAbort.hidden = NO;
        self.labelMessage.center =
            CGPointMake(size.width * kHalf, size.height * kHalf + kMessageOffsetProgressShown);
    }
}

/** @ghidraAddress 0xd77cc */
- (void)btnAbort:(id)sender {
    // Yes, sender is unused: the delegate is handed the panel rather than the button. The delegate
    // is loaded from the weak slot twice, once to test and once to send to.
    if ([self.delegate respondsToSelector:@selector(storeDialogCancel:)]) {
        [self.delegate performSelector:@selector(storeDialogCancel:) withObject:self];
    }
}

@end

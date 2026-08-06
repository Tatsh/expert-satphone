#import "StoreLoadingView.h"

// The spinner and both labels are the same height, and both labels the same size of type.
static const CGFloat kSubviewHeight = 24.0;
static const CGFloat kLabelFontSize = 18.0;

// The caption's grey serves twice: as the text's level, and as the alpha of the white shadow under
// it. The two arguments are swapped between the calls.
static const CGFloat kCaptionWhite = 0.2f; // @ghidraAddress 0x28f240
static const CGFloat kCaptionShadowOffsetY = 1.0;

// The error label is the overlay's height less this much.
static const CGFloat kErrorHeightInset = -20.0;

// Each subview sits a whole number of points off the overlay's vertical centre.
enum {
    kIndicatorOffsetY = -10,
    kCaptionOffsetY = 20,
    kErrorOffsetY = -20,
};

static const CGFloat kHalf = 0.5;

@implementation StoreLoadingView {
    UIActivityIndicatorView *accessingIndicator;
    UILabel *accessingLabel;
    UILabel *errorLabel;
}

/** @ghidraAddress 0x1b98d0 */
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.opaque = NO;
        self.backgroundColor = UIColor.clearColor;

        // The vertical centre is truncated to a whole point once and then each subview is offset
        // from it by a whole number, so none of the three lands on a half pixel.
        int centreY = (int)(frame.size.height * kHalf);
        CGFloat centreX = frame.size.width * kHalf;

        accessingIndicator = [[UIActivityIndicatorView alloc]
            initWithFrame:CGRectMake(0, 0, kSubviewHeight, kSubviewHeight)];
        accessingIndicator.activityIndicatorViewStyle = UIActivityIndicatorViewStyleGray;
        accessingIndicator.center = CGPointMake(centreX, centreY + kIndicatorOffsetY);

        accessingLabel =
            [[UILabel alloc] initWithFrame:CGRectMake(0, 0, frame.size.width, kSubviewHeight)];
        accessingLabel.backgroundColor = UIColor.clearColor;
        accessingLabel.font = [UIFont boldSystemFontOfSize:kLabelFontSize];
        accessingLabel.textColor = [UIColor colorWithWhite:kCaptionWhite alpha:1.0];
        // The same two numbers as the line above, the other way round: a white shadow at the grey's
        // level, under grey text at full opacity.
        accessingLabel.shadowColor = [UIColor colorWithWhite:1.0 alpha:kCaptionWhite];
        accessingLabel.shadowOffset = CGSizeMake(0, kCaptionShadowOffsetY);
        accessingLabel.textAlignment = NSTextAlignmentCenter;
        accessingLabel.center = CGPointMake(centreX, centreY + kCaptionOffsetY);
        accessingLabel.text = NSLocalizedString(@"Loading...", nil);

        errorLabel = [[UILabel alloc]
            initWithFrame:CGRectMake(
                              0, 0, frame.size.width, frame.size.height + kErrorHeightInset)];
        errorLabel.backgroundColor = UIColor.clearColor;
        errorLabel.font = [UIFont boldSystemFontOfSize:kLabelFontSize];
        errorLabel.textColor = UIColor.blackColor;
        errorLabel.textAlignment = NSTextAlignmentCenter;
        errorLabel.numberOfLines = 0;
        errorLabel.center = CGPointMake(centreX, centreY + kErrorOffsetY);

        // None of the three is added here. Membership of the hierarchy is the state the other
        // three methods switch between.
    }
    return self;
}

/** @ghidraAddress 0x1b9dac */
- (void)startLoading {
    self.hidden = NO;
    if (errorLabel.superview) {
        [errorLabel removeFromSuperview];
    }
    if (!accessingIndicator.superview) {
        [self addSubview:accessingIndicator];
        // Only started on the way in. An indicator already in the hierarchy is left as it is.
        [accessingIndicator startAnimating];
    }
    if (!accessingLabel.superview) {
        [self addSubview:accessingLabel];
    }
}

/** @ghidraAddress 0x1b9eb4 */
- (void)stopLoading {
    self.hidden = YES;
    if (accessingIndicator.superview) {
        // Removed, not stopped: -stopAnimating is never sent anywhere in this class.
        [accessingIndicator removeFromSuperview];
    }
    if (accessingLabel.superview) {
        [accessingLabel removeFromSuperview];
    }
}

/** @ghidraAddress 0x1b9f6c */
- (void)showError:(NSString *)error {
    // -stopLoading hides the overlay and the next line shows it again. Both calls are in the
    // binary; the hide never reaches the screen.
    [self stopLoading];
    self.hidden = NO;
    errorLabel.text = error;
    if (!errorLabel.superview) {
        [self addSubview:errorLabel];
    }
}

@end

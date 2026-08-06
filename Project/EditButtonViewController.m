#import "EditButtonViewController.h"

#import "ImageLoading.h"

EditButtonSelectionKey const EditButtonSelectionKeyName = @"name";
EditButtonSelectionKey const EditButtonSelectionKeySelect = @"select";

// The popover's backdrop, from the CFString at 0x2e1fe0.
static NSString *const kBackgroundImageName = @"edit_pop_bg";
// The selected button's artwork is the plain name with this suffix, from the CFString at 0x2e2000.
static NSString *const kSelectedImageNameFormat = @"%@_s";

// Horizontal gap between adjacent buttons.
static const CGFloat kButtonGap = 2.0;
// The popover's height, independent of the artwork.
static const CGFloat kPopoverHeight = 40.0; // @ghidraAddress 0x28f1f8

@implementation EditButtonViewController {
    // Weak: the binary stores it with objc_storeWeak, not objc_storeStrong.
    __weak id<EditButtonViewControllerDelegate> delegate;
    NSString *myName;
}

/** @ghidraAddress 0x207348 */
- (instancetype)initWithButtonArray:(NSArray<NSString *> *)buttonArray
                             selNum:(int)selNum
                           delegate:(id<EditButtonViewControllerDelegate>)aDelegate
                           ctrlName:(NSString *)ctrlName {
    self = [super init];
    if (self) {
        delegate = aDelegate;
        myName = ctrlName;

        UIImage *backgroundImage = LoadScaledPngImage(kBackgroundImageName);
        UIImageView *backgroundView = [[UIImageView alloc] initWithImage:backgroundImage];
        [self.view addSubview:backgroundView];

        // The running left edge, kept as a whole number between buttons.
        CGFloat nextX = 0;
        for (NSUInteger i = 0; i < buttonArray.count; ++i) {
            UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
            button.exclusiveTouch = YES;
            button.tag = i;
            [button addTarget:self
                          action:@selector(pushBtn:)
                forControlEvents:UIControlEventTouchUpInside];
            [self.view addSubview:button];

            NSString *imageName = [buttonArray objectAtIndex:i];
            // The binary widens selNum by zero-extension, not sign-extension, before comparing it
            // against the 64-bit counter, so the cast is spelled out rather than left implicit.
            if ((NSUInteger)(unsigned int)selNum == i) {
                // Yes, the array is indexed a second time rather than reusing imageName.
                imageName = [NSString
                    stringWithFormat:kSelectedImageNameFormat, [buttonArray objectAtIndex:selNum]];
            }
            UIImage *buttonImage = LoadScaledPngImage(imageName);
            [button setBackgroundImage:buttonImage forState:UIControlStateNormal];
            button.frame = CGRectMake(nextX, 0, buttonImage.size.width, buttonImage.size.height);
            // Truncated to a whole number on every step, so the gaps do not accumulate a fraction.
            nextX = (int)(nextX + buttonImage.size.width + kButtonGap);
        }

        // The width is the accumulated run; the height is fixed and ignores the artwork.
        self.preferredContentSize = CGSizeMake(nextX, kPopoverHeight);
    }
    return self;
}

/** @ghidraAddress 0x20773c */
- (void)pushBtn:(UIButton *)sender {
    id values[] = {myName, @(sender.tag)};
    id keys[] = {EditButtonSelectionKeyName, EditButtonSelectionKeySelect};
    NSDictionary *info = [NSDictionary dictionaryWithObjects:values
                                                     forKeys:keys
                                                       count:sizeof(keys) / sizeof(keys[0])];
    // The delegate is loaded from the weak slot twice, once to test and once to send to.
    if ([delegate respondsToSelector:@selector(editBtnSelect:tag:)]) {
        [delegate performSelector:@selector(editBtnSelect:tag:) withObject:self withObject:info];
    }
}

@end

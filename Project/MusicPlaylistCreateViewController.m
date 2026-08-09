#import "MusicPlaylistCreateViewController.h"

// The field is inset by this margin on every side, so its width is the parent's width less twice
// the margin. The inset reaches the code as an fmov immediate at 0x167020; the width reduction as
// an fmov immediate at 0x167008.
static const CGFloat kFieldInset = 10.0;

// The field's fixed height, loaded from the __const pool.
/** @ghidraAddress 0x10028f458 */
static const CGFloat kFieldHeight = 32.0;

// The name is capped so that the text after the edit stays under this many characters. The bound
// reaches the code as the cmp #0x80 immediate at 0x166f5c.
static const NSUInteger kMaxPlaylistNameLength = 128;

@implementation MusicPlaylistCreateViewController {
    UITextField *fieldName;
    UIBarButtonItem *btnDone;
}

#pragma mark - Lifecycle

/** @ghidraAddress 0x1667c8 */
- (instancetype)init {
    self = [super init];
    if (self) {
        self.navigationItem.title = [NSBundle.mainBundle localizedStringForKey:@"New Playlist"
                                                                         value:@""
                                                                         table:nil];
        btnDone = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                target:self
                                                                action:@selector(tapDone:)];
        btnDone.enabled = NO;
        self.navigationItem.rightBarButtonItem = btnDone;
        self.navigationItem.backBarButtonItem.title =
            [NSBundle.mainBundle localizedStringForKey:@"Cancel" value:@"" table:nil];
    }
    return self;
}

/** @ghidraAddress 0x166a04 */
- (void)loadView {
    [super loadView];
    self.view.backgroundColor = UIColor.grayColor;
    fieldName = [[UITextField alloc] initWithFrame:CGRectZero];
    fieldName.borderStyle = UITextBorderStyleRoundedRect;
    fieldName.keyboardType = UIKeyboardTypeDefault;
    fieldName.autocapitalizationType = UITextAutocapitalizationTypeNone;
    fieldName.autocorrectionType = UITextAutocorrectionTypeNo;
    fieldName.placeholder = [NSBundle.mainBundle localizedStringForKey:@"Playlist Name"
                                                                 value:@""
                                                                 table:nil];
    fieldName.returnKeyType = UIReturnKeyDone;
    [fieldName addTarget:self
                  action:@selector(fieldChanged:)
        forControlEvents:UIControlEventEditingChanged];
    fieldName.delegate = self;
    [self.view addSubview:fieldName];
}

/** @ghidraAddress 0x166f9c */
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    fieldName.frame = CGRectMake(
        kFieldInset, kFieldInset, self.view.frame.size.width - (kFieldInset * 2), kFieldHeight);
    if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)]) {
        self.edgesForExtendedLayout = UIRectEdgeNone;
    }
}

/** @ghidraAddress 0x16707c */
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [fieldName becomeFirstResponder];
}

/** @ghidraAddress 0x1670d8 */
- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [fieldName resignFirstResponder];
}

/** @ghidraAddress 0x167134 */
- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
}

#pragma mark - Actions

/** @ghidraAddress 0x166c40 */
- (void)fieldChanged:(id)sender {
    btnDone.enabled = fieldName.text.length != 0;
}

/** @ghidraAddress 0x166cb0 */
- (void)tapDone:(id)sender {
    [fieldName resignFirstResponder];
    NSString *name = fieldName.text;
    NSUInteger trimmedLength =
        [name stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet].length;
    if (trimmedLength != 0) {
        if ([self.delegate respondsToSelector:@selector(musicPlaylistCreateWithName:)]) {
            // The raw text is handed over, not the trimmed value that was tested for emptiness.
            [self.delegate performSelector:@selector(musicPlaylistCreateWithName:) withObject:name];
        }
    }
    [self.navigationController popViewControllerAnimated:YES];
}

#pragma mark - UITextFieldDelegate

/** @ghidraAddress 0x166e30 */
- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if (fieldName.text.length != 0) {
        [self tapDone:nil];
    }
    return YES;
}

/** @ghidraAddress 0x166eac */
- (BOOL)textField:(UITextField *)textField
    shouldChangeCharactersInRange:(NSRange)range
                replacementString:(NSString *)string {
    if (fieldName != textField) {
        return NO;
    }
    if ([string compare:@"\n"] == NSOrderedSame) {
        return YES;
    }
    NSUInteger newLength = (textField.text.length - range.length) + string.length;
    return newLength < kMaxPlaylistNameLength;
}

#pragma mark - Rotation

/** @ghidraAddress 0x16716c */
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // The binary tests (unsigned)(orientation - 1) < 2, which is exactly the two portrait cases:
    // UIInterfaceOrientationPortrait (1) and UIInterfaceOrientationPortraitUpsideDown (2).
    return interfaceOrientation == UIInterfaceOrientationPortrait ||
           interfaceOrientation == UIInterfaceOrientationPortraitUpsideDown;
}

/** @ghidraAddress 0x16717c */
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskPortraitUpsideDown;
}

/** @ghidraAddress 0x167184 */
- (BOOL)shouldAutorotate {
    return YES;
}

@end

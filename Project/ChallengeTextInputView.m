#import "ChallengeTextInputView.h"

// The maximum length of the entered name, in characters.
static const NSUInteger kMaxNameLength = 20;

// The whitespace stripped when testing for a blank entry. The full-width space is stripped too, but
// its result is discarded (see -checkBlankString:).
static NSString *const kASCIISpace = @" ";
static NSString *const kFullWidthSpace = @"　";

@implementation ChallengeTextInputView

@synthesize nameBox = _nameBox;
@synthesize changeBtn = _changeBtn;
@synthesize aDelegate = _aDelegate;
@synthesize inputText = _inputText;

#pragma mark - Construction

/** @ghidraAddress 0x93ea0 */
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) {
        return self;
    }
    self.opaque = NO;
    self.layer.doubleSided = NO;

    self.nameBox = [[UITextField alloc] init];
    self.nameBox.backgroundColor = UIColor.clearColor;
    self.nameBox.delegate = self;
    self.nameBox.returnKeyType = UIReturnKeyDone;
    [self addSubview:self.nameBox];

    self.changeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    self.changeBtn.exclusiveTouch = YES;
    [self.changeBtn addTarget:self
                       action:@selector(commitName:)
             forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:self.changeBtn];
    return self;
}

#pragma mark - Text state

/** @ghidraAddress 0x9415c */
- (void)resetView {
    self.nameBox.text = nil;
    _inputText = @"";
    self.changeBtn.imageView.image = nil;
}

/** @ghidraAddress 0x941e4 */
- (void)setDefaultText:(NSString *)text {
    self.nameBox.text = text;
    _inputText = text;
}

// Records the current field text as the backed-up input, clamping both the field and the backup to
// the maximum length.
/** @ghidraAddress 0x9432c */
- (void)backUpFieldText {
    if (!self.nameBox) {
        return;
    }
    if (self.inputText.length > kMaxNameLength) {
        _inputText = [self.inputText substringWithRange:NSMakeRange(0, kMaxNameLength)];
    }
    if (self.nameBox.text.length > kMaxNameLength) {
        self.nameBox.text = [self.nameBox.text substringWithRange:NSMakeRange(0, kMaxNameLength)];
    }
    _inputText = self.nameBox.text;
}

#pragma mark - Committing

// Backs up the field text, dismisses the keyboard, and reports the commit to the delegate.
/** @ghidraAddress 0x94238 */
- (void)commitName:(id)sender {
    [self backUpFieldText];
    [self.nameBox resignFirstResponder];
    if ([self.aDelegate respondsToSelector:@selector(commitText:)]) {
        [self.aDelegate performSelector:@selector(commitText:) withObject:self];
    }
}

#pragma mark - Predicates

/** @ghidraAddress 0x94514 */
- (BOOL)isPictText:(NSString *)text {
    NSData *data = [text dataUsingEncoding:NSShiftJISStringEncoding];
    NSString *roundTrip = [[NSString alloc] initWithData:data encoding:NSShiftJISStringEncoding];
    return [roundTrip isEqualToString:@""];
}

// Whether a string is blank once its spaces are stripped. The full-width-space strip is performed
// but its result is discarded; only the ASCII-space strip is tested. Faithful to the binary.
/** @ghidraAddress 0x946e4 */
- (BOOL)checkBlankString:(NSString *)text {
    NSString *stripped = [text stringByReplacingOccurrencesOfString:kASCIISpace withString:@""];
    (void)[text stringByReplacingOccurrencesOfString:kFullWidthSpace
                                          withString:@""]; // Result discarded, as in the binary.
    return [stripped isEqualToString:@""];
}

#pragma mark - UITextFieldDelegate

/** @ghidraAddress 0x944d4 */
- (BOOL)textViewShouldBeginEditing:(id)textView {
    [self backUpFieldText];
    return YES;
}

/** @ghidraAddress 0x944f4 */
- (BOOL)textViewShouldEndEditing:(id)textView {
    [self backUpFieldText];
    return YES;
}

/** @ghidraAddress 0x945b0 */
- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if ([self checkBlankString:textField.text]) {
        return NO;
    }
    [self backUpFieldText];
    [self.nameBox resignFirstResponder];
    if ([self.aDelegate respondsToSelector:@selector(commitText:)]) {
        [self.aDelegate performSelector:@selector(commitText:) withObject:self];
    }
    return YES;
}

/** @ghidraAddress 0x947ac */
- (BOOL)textField:(UITextField *)textField
    shouldChangeCharactersInRange:(NSRange)range
                replacementString:(NSString *)string {
    NSMutableString *candidate = [textField.text mutableCopy];
    [candidate replaceCharactersInRange:range withString:string];
    return candidate.length < kMaxNameLength + 1;
}

@end

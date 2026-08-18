#import "EditModalTableViewController.h"

#import "EditDataManager.h"

// The reuse identifier shared by every row's cell.
static NSString *const kReuseIdentifier = @"EditModaltableViewCell";

// The persisted-dictionary keys the form reads and writes.
static NSString *const kEditorInfoKeyFumenName = @"fumenName";
static NSString *const kEditorInfoKeyEditorName = @"editorName";
static NSString *const kEditorInfoKeyComment = @"comment";
static NSString *const kEditorInfoKeyLevel = @"level";
static NSString *const kEditorInfoKeyCopyLock = @"copyLock";

// The user-defaults key mirroring the editor name.
static NSString *const kPrefEditorNameKey = @"PrefEditorName";

// The sections, in order. The upload section is only present when uploading is enabled.
typedef enum : NSInteger {
    EditModalSectionFields = 0, // The three editable text fields.
    EditModalSectionLevel = 1,  // The level scale and slider.
    EditModalSectionCopy = 2,   // The copy-permission switch.
    EditModalSectionUpload = 3, // The upload button (only when uploading is enabled).
} EditModalSection;

// The rows in the fields section, in order; each is also the text view's tag.
typedef enum : NSInteger {
    EditModalFieldChartName = 0,  // The chart name.
    EditModalFieldEditorName = 1, // The editor name.
    EditModalFieldComment = 2,    // The comment (allowed to be longer).
} EditModalField;

// The number of editable fields, hence the length of editText and cntLabel.
static const int kFieldCount = 3;
// The number of level ticks drawn above the slider.
static const int kLevelScaleCount = 10;

// The per-field character limits. The comment allows more than the name fields.
static const int kFieldMaxLength = 10;
static const int kCommentMaxLength = 30;

// The text view's height by field. The comment field is taller.
static const CGFloat kFieldHeight = 30.0;
static const CGFloat kCommentFieldHeight = 60.0;

// Row heights, chosen per section and (for the fields section) per row.
static const CGFloat kNameRowHeight = 40.0;
static const CGFloat kCommentRowHeight = 70.0;
static const CGFloat kLevelRowHeight = 70.0;
static const CGFloat kUploadRowHeight = 50.0;

// The cell title and text-view font size, and the count-label height.
static const CGFloat kCellFontSize = 16.0;
static const CGFloat kLabelHeight = 20.0;

// The editable text view's frame within a fields-section cell.
static const CGFloat kFieldTextViewX = 95.0;
static const CGFloat kFieldTextViewWidth = 380.0;

// The character-count label's frame; its y sits 12 points above the text view's bottom.
static const CGFloat kCountLabelX = 420.0;
static const CGFloat kCountLabelWidth = 50.0;
static const CGFloat kCountLabelBottomInset = 12.0;

// The level ticks' x offsets (before the base offset is added), from __const at 0x100293d50.
static const int kLevelScaleOffsets[] = {7, 44, 82, 119, 157, 194, 232, 269, 307, 338};
static const CGFloat kLevelLabelBaseX = 100.0;
static const CGFloat kLevelLabelY = 16.0;
static const CGFloat kLevelLabelWidth = 40.0;

// The level slider's frame and range.
static const CGFloat kLevelSliderX = 100.0;
static const CGFloat kLevelSliderY = 36.0;
static const CGFloat kLevelSliderWidth = 360.0;
static const CGFloat kLevelSliderHeight = 20.0;
static const float kLevelSliderMaxValue = 9.0f;

// The copy-permission switch's frame.
static const CGFloat kCopySwitchX = 380.0;
static const CGFloat kCopySwitchY = 7.0;
static const CGFloat kCopySwitchWidth = 50.0;
static const CGFloat kCopySwitchHeight = 30.0;

// The count label's text colour, a dark teal built from components (0, 0.2, 0.4, 1). The green
// component is the double at 0x10028f240 and the blue is the double at 0x10028f2c0.
static const CGFloat kCountLabelColorGreen = 0.2;
static const CGFloat kCountLabelColorBlue = 0.4;

// The Shift-JIS encoding used to detect pictographic input: text that does not survive a Shift-JIS
// round-trip is treated as pictographic and rejected.
static const NSStringEncoding kPictDetectEncoding = NSShiftJISStringEncoding;

// The field titles shown in each fields-section cell, from the __const table at 0x100353e68.
static NSString *const kFieldTitles[] = {@"譜面名", @"作成者名", @"コメント"};

@interface EditModalTableViewController ()

/**
 * @brief Returns the persisted string for a field index.
 * @param index The field index.
 * @return The stored chart name, editor name, or comment, or @c nil for an unknown index.
 * @ghidraAddress 0x1e2f9c
 */
- (NSString *)getStringPointer:(int)index;

/**
 * @brief Copies the active field's text back into @c editText , clamped to the field limit.
 * @ghidraAddress 0x1e4230
 */
- (void)backUpFieldText;

/**
 * @brief Updates a field's character-count label and colours it red when the count is negative.
 * @param field The field index.
 * @param remaining The remaining character count.
 * @ghidraAddress 0x1e47b0
 */
- (void)labelChange:(int)field num:(int)remaining;

/**
 * @brief Detects pictographic (emoji) input that cannot be represented in Shift-JIS.
 * @param text The candidate text.
 * @return @c YES when the text does not survive a Shift-JIS round-trip.
 * @ghidraAddress 0x1e470c
 */
- (BOOL)isPictText:(NSString *)text;

/**
 * @brief The copy-permission switch's action.
 * @param sender The switch.
 * @ghidraAddress 0x1e4020
 */
- (void)changeSwitch:(UISwitch *)sender;

/**
 * @brief The level slider's action; snaps the value to the nearest integer.
 * @param slider The slider.
 * @ghidraAddress 0x1e4c1c
 */
- (void)levelSliderChange:(UISlider *)slider;

@end

@implementation EditModalTableViewController {
    UILabel *levelCell;
    UITextView *selectField;
    NSString *editText[kFieldCount];
    int difficulty;
    int copyFlg;
    UISwitch *copyFlagSwitch;
    UILabel *cntLabel[kFieldCount];
    UISlider *levelSlider;
    BOOL bUpload;
    // Weak: the binary stores it with objc_storeWeak, not objc_storeStrong.
    __weak id<EditModalTableViewControllerDelegate> _delegate;
}

@synthesize delegate = _delegate;

#pragma mark - Lifecycle

/** @ghidraAddress 0x1e2ec0 */
- (instancetype)initEnableUpload:(BOOL)enableUpload {
    bUpload = enableUpload;
    self = [super initWithStyle:UITableViewStyleGrouped];
    if (self) {
        selectField = nil;
    }
    return self;
}

/** @ghidraAddress 0x1e2f30 */
- (instancetype)initWithStyle:(UITableViewStyle)style {
    bUpload = NO;
    self = [super initWithStyle:style];
    if (self) {
        selectField = nil;
    }
    return self;
}

// The binary's -dealloc (0x1e4cf4) only forwards to [super dealloc]; under ARC that is implicit, so
// it is intentionally omitted.

#pragma mark - Field data

/** @ghidraAddress 0x1e2f9c */
- (NSString *)getStringPointer:(int)index {
    NSMutableDictionary *info = [EditDataManager sharedManager].getEditorInfo;
    if (index == EditModalFieldComment) {
        return info[kEditorInfoKeyComment];
    }
    if (index == EditModalFieldEditorName) {
        return info[kEditorInfoKeyEditorName];
    }
    if (index == EditModalFieldChartName) {
        return info[kEditorInfoKeyFumenName];
    }
    return nil;
}

/** @ghidraAddress 0x1e3d8c */
- (void)setEditorInfo {
    EditDataManager *editData = [EditDataManager sharedManager];
    [self backUpFieldText];
    NSMutableDictionary *info = editData.getEditorInfo;
    info[kEditorInfoKeyFumenName] = editText[EditModalFieldChartName];
    info[kEditorInfoKeyEditorName] = editText[EditModalFieldEditorName];
    [NSUserDefaults.standardUserDefaults setValue:editText[EditModalFieldEditorName]
                                           forKey:kPrefEditorNameKey];
    info[kEditorInfoKeyComment] = editText[EditModalFieldComment];
    info[kEditorInfoKeyLevel] = @(difficulty);
    info[kEditorInfoKeyCopyLock] = @(copyFlg);
}

/** @ghidraAddress 0x1e4230 */
- (void)backUpFieldText {
    if (selectField == nil) {
        return;
    }
    int tag = (int)selectField.tag;
    int limit = (tag == EditModalFieldComment) ? kCommentMaxLength : kFieldMaxLength;
    if (editText[tag].length > (NSUInteger)limit) {
        editText[tag] = [editText[tag] substringWithRange:NSMakeRange(0, limit)];
    }
    if (selectField.text.length > (NSUInteger)limit) {
        selectField.text = [selectField.text substringWithRange:NSMakeRange(0, limit)];
    }
    [self labelChange:tag num:(limit - (int)editText[tag].length)];
    if (tag == EditModalFieldComment) {
        editText[tag] = selectField.text;
        return;
    }
    if (selectField.text.length == 0) {
        // An emptied name field is restored from the backing string rather than saved empty.
        selectField.text = editText[tag];
        return;
    }
    editText[tag] = selectField.text;
}

/** @ghidraAddress 0x1e47b0 */
- (void)labelChange:(int)field num:(int)remaining {
    cntLabel[field].text = [NSString stringWithFormat:@"%d", remaining];
    UIColor *color;
    if (remaining < 0) {
        color = UIColor.redColor;
    } else {
        // The binary builds this with colorWithRed:green:blue:alpha:.
        color = [UIColor colorWithRed:0.0
                                green:kCountLabelColorGreen
                                 blue:kCountLabelColorBlue
                                alpha:1.0];
    }
    cntLabel[field].textColor = color;
}

/** @ghidraAddress 0x1e470c */
- (BOOL)isPictText:(NSString *)text {
    NSData *data = [text dataUsingEncoding:kPictDetectEncoding];
    NSString *roundTrip = [[NSString alloc] initWithData:data encoding:kPictDetectEncoding];
    return [roundTrip isEqualToString:@""];
}

#pragma mark - Actions

/** @ghidraAddress 0x1e4020 */
- (void)changeSwitch:(UISwitch *)sender {
    copyFlg = sender.on;
}

/** @ghidraAddress 0x1e4c1c */
- (void)levelSliderChange:(UISlider *)slider {
    float raw = slider.value;
    int rounded = (int)raw;
    if (raw > (float)rounded + 0.5f) {
        rounded += 1;
    }
    slider.value = (float)rounded;
    difficulty = (int)slider.value;
}

#pragma mark - UITableViewDataSource

/** @ghidraAddress 0x1e3ff0 */
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return bUpload ? 4 : 3;
}

/** @ghidraAddress 0x1e400c */
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return (section == EditModalSectionFields) ? kFieldCount : 1;
}

/** @ghidraAddress 0x1e3f4c */
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == EditModalSectionFields && indexPath.row == EditModalFieldComment) {
        return kCommentRowHeight;
    }
    if (indexPath.section == EditModalSectionLevel) {
        return kLevelRowHeight;
    }
    if (indexPath.section == EditModalSectionUpload) {
        return kUploadRowHeight;
    }
    // The fields section's name rows and the copy section share the same height.
    return kNameRowHeight;
}

/** @ghidraAddress 0x1e3088 */
- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kReuseIdentifier];
    if (cell != nil) {
        return cell;
    }

    if (indexPath.section == EditModalSectionFields) {
        int row = (int)indexPath.row;
        CGFloat fieldHeight = (row == EditModalFieldComment) ? kCommentFieldHeight : kFieldHeight;
        int limit = (row == EditModalFieldComment) ? kCommentMaxLength : kFieldMaxLength;

        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
                                      reuseIdentifier:kReuseIdentifier];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.textLabel.font = [UIFont boldSystemFontOfSize:kCellFontSize];
        cell.textLabel.text = kFieldTitles[row];

        UITextView *textView = [[UITextView alloc]
            initWithFrame:CGRectMake(kFieldTextViewX, 0.0, kFieldTextViewWidth, fieldHeight)];
        textView.font = [UIFont systemFontOfSize:kCellFontSize];
        textView.backgroundColor = UIColor.clearColor;
        textView.scrollEnabled = NO;
        textView.keyboardType = UIKeyboardTypeDefault;
        textView.autocapitalizationType = UITextAutocapitalizationTypeNone;
        textView.autocorrectionType = UITextAutocorrectionTypeNo;
        textView.returnKeyType = UIReturnKeyDone;
        textView.delegate = self;
        textView.tag = row;
        editText[row] = [NSString stringWithString:[self getStringPointer:row]];
        textView.text = editText[row];
        [cell.contentView addSubview:textView];

        UILabel *countLabel =
            [[UILabel alloc] initWithFrame:CGRectMake(kCountLabelX,
                                                      fieldHeight - kCountLabelBottomInset,
                                                      kCountLabelWidth,
                                                      kLabelHeight)];
        cntLabel[row] = countLabel;
        countLabel.alpha = 0.0;
        countLabel.text = [NSString stringWithFormat:@"%d", limit - (int)editText[row].length];
        countLabel.textAlignment = NSTextAlignmentRight;
        countLabel.backgroundColor = UIColor.clearColor;
        countLabel.textColor = [UIColor colorWithRed:0.0
                                               green:kCountLabelColorGreen
                                                blue:kCountLabelColorBlue
                                               alpha:1.0];
        [cell.contentView addSubview:countLabel];
        return cell;
    }

    if (indexPath.section == EditModalSectionLevel) {
        difficulty = [[EditDataManager sharedManager].getEditorInfo[kEditorInfoKeyLevel] intValue];
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
                                      reuseIdentifier:kReuseIdentifier];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.textLabel.font = [UIFont boldSystemFontOfSize:kCellFontSize];
        cell.textLabel.text = @"LEVEL";

        for (int i = 0; i < kLevelScaleCount; ++i) {
            UILabel *tick =
                [[UILabel alloc] initWithFrame:CGRectMake(kLevelScaleOffsets[i] + kLevelLabelBaseX,
                                                          kLevelLabelY,
                                                          kLevelLabelWidth,
                                                          kLabelHeight)];
            tick.text = [NSString stringWithFormat:@"%d", i + 1];
            tick.backgroundColor = UIColor.clearColor;
            [cell.contentView addSubview:tick];
        }

        levelSlider = [[UISlider alloc]
            initWithFrame:CGRectMake(
                              kLevelSliderX, kLevelSliderY, kLevelSliderWidth, kLevelSliderHeight)];
        levelSlider.maximumValue = kLevelSliderMaxValue;
        levelSlider.minimumValue = 0.0f;
        levelSlider.value = (float)difficulty;
        [levelSlider addTarget:self
                        action:@selector(levelSliderChange:)
              forControlEvents:UIControlEventValueChanged];
        [cell.contentView addSubview:levelSlider];
        return cell;
    }

    if (indexPath.section == EditModalSectionCopy) {
        copyFlg = [[EditDataManager sharedManager].getEditorInfo[kEditorInfoKeyCopyLock] intValue];
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
                                      reuseIdentifier:kReuseIdentifier];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.textLabel.text = @"引用の許可";

        copyFlagSwitch = [[UISwitch alloc]
            initWithFrame:CGRectMake(
                              kCopySwitchX, kCopySwitchY, kCopySwitchWidth, kCopySwitchHeight)];
        [copyFlagSwitch addTarget:self
                           action:@selector(changeSwitch:)
                 forControlEvents:UIControlEventValueChanged];
        copyFlagSwitch.on = (copyFlg == 1);
        [cell.contentView addSubview:copyFlagSwitch];
        return cell;
    }

    if (indexPath.section == EditModalSectionUpload) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                      reuseIdentifier:kReuseIdentifier];
        cell.selectionStyle = UITableViewCellSelectionStyleBlue;
        cell.textLabel.text = @"アップロードする";
        cell.textLabel.textColor = UIColor.whiteColor;
        cell.textLabel.textAlignment = NSTextAlignmentCenter;
        cell.textLabel.backgroundColor = UIColor.clearColor;
        return cell;
    }

    return nil;
}

#pragma mark - UITableViewDelegate

/** @ghidraAddress 0x1e4058 */
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == EditModalSectionFields) {
        return;
    }
    if (indexPath.section == EditModalSectionLevel) {
        if (selectField != nil) {
            [self backUpFieldText];
            [selectField resignFirstResponder];
            selectField = nil;
        }
        return;
    }
    if (indexPath.section == EditModalSectionCopy) {
        if (selectField != nil) {
            [self backUpFieldText];
            [selectField resignFirstResponder];
            selectField = nil;
        }
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
        return;
    }
    if (indexPath.section == EditModalSectionUpload) {
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
        if ([self.delegate respondsToSelector:@selector(selectUpdate:)]) {
            [self.delegate performSelector:@selector(selectUpdate:) withObject:self];
        }
    }
}

#pragma mark - UITextViewDelegate

/** @ghidraAddress 0x1e4464 */
- (BOOL)textViewShouldBeginEditing:(UITextView *)textView {
    [self backUpFieldText];
    selectField = textView;
    int tag = (int)selectField.tag;
    int limit = (tag == EditModalFieldComment) ? kCommentMaxLength : kFieldMaxLength;
    int remaining = limit - (int)selectField.text.length;

    // Hide every count label, then reveal and update the one for the field being edited.
    cntLabel[EditModalFieldChartName].alpha = 0.0;
    if (tag == EditModalFieldChartName) {
        cntLabel[EditModalFieldChartName].alpha = 1.0;
        cntLabel[EditModalFieldChartName].text = [NSString stringWithFormat:@"%d", remaining];
    }
    cntLabel[EditModalFieldEditorName].alpha = 0.0;
    if (tag == EditModalFieldEditorName) {
        cntLabel[EditModalFieldEditorName].alpha = 1.0;
        cntLabel[EditModalFieldEditorName].text = [NSString stringWithFormat:@"%d", remaining];
    }
    cntLabel[EditModalFieldComment].alpha = 0.0;
    if (tag == EditModalFieldComment) {
        cntLabel[EditModalFieldComment].alpha = 1.0;
        cntLabel[EditModalFieldComment].text = [NSString stringWithFormat:@"%d", remaining];
    }
    return YES;
}

/** @ghidraAddress 0x1e46ac */
- (BOOL)textViewShouldEndEditing:(UITextView *)textView {
    cntLabel[textView.tag].alpha = 0.0;
    [self backUpFieldText];
    return YES;
}

/** @ghidraAddress 0x1e48a8 */
- (void)textViewDidChange:(UITextView *)textView {
    int limit = (textView.tag == EditModalFieldComment) ? kCommentMaxLength : kFieldMaxLength;
    [self labelChange:(int)textView.tag num:(limit - (int)textView.text.length)];
}

/** @ghidraAddress 0x1e4968 */
- (void)textViewDidChangeSelection:(UITextView *)textView {
}

/** @ghidraAddress 0x1e496c */
- (BOOL)textView:(UITextView *)textView
    shouldChangeTextInRange:(NSRange)range
            replacementText:(NSString *)text {
    int maxLen = (textView.tag == EditModalFieldComment) ? kCommentMaxLength : kFieldMaxLength;
    if ([text isEqualToString:@"\n"]) {
        // The return key commits and dismisses the field; it is never inserted. An empty name
        // field is left untouched here (backUpFieldText restores it).
        if (textView.text.length != 0 || textView.tag == EditModalFieldComment) {
            [self backUpFieldText];
            selectField = nil;
            cntLabel[textView.tag].alpha = 0.0;
            [textView resignFirstResponder];
        }
        return NO;
    }
    if ([text isEqualToString:@""]) {
        // A deletion is always allowed.
        return YES;
    }
    if ([self isPictText:text]) {
        return NO;
    }
    NSUInteger newLength = (textView.text.length - range.length) + text.length;
    // A pure insertion (empty range) is allowed one extra character: the limit is OR-ed with 1, so
    // an even limit such as 10 or 30 permits 11 or 31 on insert, while a replacement uses the plain
    // limit. This oddity is the binary's own.
    NSUInteger limit = (range.length == 0) ? (NSUInteger)(maxLen | 1) : (NSUInteger)maxLen;
    return newLength <= limit;
}

#pragma mark - UITextFieldDelegate

/** @ghidraAddress 0x1e47a8 */
- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    return YES;
}

#pragma mark - UIViewController

/** @ghidraAddress 0x1e4cd4 */
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)orientation {
    // The mask is Portrait | PortraitUpsideDown, tested as the unsigned (orientation - 1) < 2.
    return (NSUInteger)(orientation - 1) < 2;
}

/** @ghidraAddress 0x1e4ce4 */
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskPortraitUpsideDown;
}

/** @ghidraAddress 0x1e4cec */
- (BOOL)shouldAutorotate {
    return YES;
}

@end

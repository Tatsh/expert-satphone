#import "EditSystemMenuview.h"

#import <QuartzCore/QuartzCore.h>

#import "ImageLoading.h"

// The edit save-slot store; not reconstructed in this tree yet, so it is forward-declared. See
// TYPES_PENDING.md.
@interface EditDataManager : NSObject
+ (instancetype)sharedManager;
- (int)getEditSlotLimit;
@end

// The inherited delegate is messaged through these selectors, sent only when it responds.
@protocol EditSystemMenuDelegate <NSObject>
@optional
- (void)selectExit;
- (void)selectLoadSlot:(NSNumber *)slot;
@end

// The two reuse identifiers: the EXIT command cell and the saved-chart load cells.
static NSString *const kExitCellIdentifier = @"EditFileListViewTableCell";
static NSString *const kLoadCellIdentifier = @"EditFileListViewTableLoadCell";

// The saved-chart dictionary keys.
static NSString *const kFumenNameKey = @"fumenName";
static NSString *const kDlFlagKey = @"dlFlag";
static NSString *const kCopyLockKey = @"copyLock";
static NSString *const kNotesNumKey = @"notesNum";

// The header title of the load section, and the EXIT command title and icon.
static NSString *const kLoadSectionTitle = @"LOAD";
static NSString *const kExitTitle = @"EXIT";
static NSString *const kExitIconName = @"edit_icon_exit";

// The two table sections, and the four fixed rows that precede the download-only slots.
static const NSInteger kSectionExit = 0;
static const NSInteger kSectionLoad = 1;
static const NSInteger kSectionCount = 2;
static const int kFixedLoadSlotCount = 4;

// The header heights: zero for the exit section, 20 for the load section, and 4 for any section
// beyond them (unreachable with two sections, but the binary computes it). The load section's
// footer is 1 and every other section's is zero.
static const CGFloat kLoadHeaderHeight = 20.0;
static const CGFloat kOtherHeaderHeight = 4.0;
static const CGFloat kLoadFooterHeight = 1.0;

@implementation EditSystemMenuview

#pragma mark - Layer

/** @ghidraAddress 0x218758 */
+ (Class)layerClass {
    return [CAGradientLayer class];
}

#pragma mark - Construction

/** @ghidraAddress 0x21876c */
- (instancetype)initWithSize:(CGSize)size {
    return [super initWithSize:size];
}

#pragma mark - Table structure

/** @ghidraAddress 0x218ed0 */
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return kSectionCount;
}

/** @ghidraAddress 0x218ed8 */
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == kSectionLoad) {
        return [EditDataManager sharedManager].getEditSlotLimit + kFixedLoadSlotCount;
    }
    return 1;
}

/** @ghidraAddress 0x218e5c */
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return section == kSectionLoad ? kLoadSectionTitle : @"";
}

/** @ghidraAddress 0x218e9c */
- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    if (section == kSectionExit) {
        return 0;
    }
    return section == kSectionLoad ? kLoadHeaderHeight : kOtherHeaderHeight;
}

/** @ghidraAddress 0x218ebc */
- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    return section == kSectionLoad ? kLoadFooterHeight : 0;
}

#pragma mark - Cells

/** @ghidraAddress 0x2187a4 */
- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == kSectionLoad) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kLoadCellIdentifier];
        if (cell == nil) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
                                          reuseIdentifier:kLoadCellIdentifier];
        }
        if (indexPath.row < (NSInteger)self.fileList.count) {
            NSDictionary *file = self.fileList[indexPath.row];
            cell.textLabel.text = file[kFumenNameKey];
            cell.textLabel.textColor = UIColor.blackColor;
            if ([file[kDlFlagKey] intValue] == 0) {
                // A local (non-download) slot past the four fixed rows is shown in blue.
                if (indexPath.row > kFixedLoadSlotCount - 1) {
                    cell.textLabel.textColor = UIColor.blueColor;
                }
            } else if ([file[kCopyLockKey] intValue] == 0) {
                // A download slot that is not copy-locked is greyed and made unselectable.
                cell.textLabel.textColor = UIColor.grayColor;
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
            }
            // The binary always formats the note count, but only reads notesNum when present; when
            // absent it formats a stale register value. Defaulting to zero keeps that safe.
            unsigned int noteCount = 0;
            if (file[kNotesNumKey]) {
                noteCount = [file[kNotesNumKey] unsignedIntValue];
            }
            cell.detailTextLabel.text = [[NSString alloc] initWithFormat:@"%d", noteCount];
            cell.detailTextLabel.textAlignment = NSTextAlignmentRight;
        } else {
            cell.textLabel.text = @"";
            cell.detailTextLabel.text = @"";
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
        }
        cell.imageView.image = nil;
        return cell;
    }
    if (indexPath.section == kSectionExit) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kExitCellIdentifier];
        if (cell == nil) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
                                          reuseIdentifier:kExitCellIdentifier];
        }
        cell.textLabel.text = kExitTitle;
        cell.imageView.image = LoadScaledPngImage(kExitIconName);
        cell.detailTextLabel.text = @"";
        return cell;
    }
    return nil;
}

#pragma mark - Selection

/** @ghidraAddress 0x218f40 */
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    id<EditSystemMenuDelegate> delegate = (id<EditSystemMenuDelegate>)self.delegate;
    if (indexPath.section == kSectionLoad) {
        if (indexPath.row < (NSInteger)self.fileList.count) {
            NSDictionary *file = self.fileList[indexPath.row];
            // A copy-locked download slot is not selectable.
            if ([file[kDlFlagKey] intValue] == 1 && [file[kCopyLockKey] intValue] == 0) {
                return;
            }
            if ([delegate respondsToSelector:@selector(selectLoadSlot:)]) {
                [delegate performSelector:@selector(selectLoadSlot:)
                               withObject:@((int)indexPath.row)];
            }
        }
    } else if (indexPath.section == kSectionExit) {
        if ([delegate respondsToSelector:@selector(selectExit)]) {
            [delegate performSelector:@selector(selectExit)];
        }
    }
}

@end

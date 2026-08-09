#import "EditFileListViewDeleteController.h"

#import "AlertViewManager.h"
#import "EditorInfoCell.h"
#import "ImageLoading.h"
#import "JubeatAppDelegate.h"

// Not yet reconstructed. Vends -initWithMusicID:delegate: and -setBFromNavigate:.
@interface JcfDownloadPageViewController : UIViewController
- (instancetype)initWithMusicID:(int)musicID delegate:(nullable id)delegate;
- (void)setBFromNavigate:(BOOL)bFromNavigate;
@end

// Not yet reconstructed. Vends the shared manager and the editable slot limit.
@interface EditDataManager : NSObject
+ (instancetype)sharedManager;
- (int)getEditSlotLimit;
@end

// The binary's delegate protocol carries three more optional callbacks than the base
// EditFileListViewController reconstruction captured; they are messaged here through
// -respondsToSelector: guards. This local extension names them so the calls stay typed.
@protocol EditFileListViewDeleteDelegate <EditFileListViewDelegate>
@optional
- (void)editFileListViewSelectNewFile;
- (void)editFileListViewSelectDownload;
- (void)editFileListViewDeleteFile:(NSString *)fileName;
@end

// Reuse identifiers.
static NSString *const kMenuCellIdentifier = @"EditFileListViewTableCell";
static NSString *const kInfoCellIdentifier = @"EditorInfoListViewTableCell";

// Keys carried by each fileList element (an NSDictionary).
static NSString *const kFileNameKey = @"fileName";
static NSString *const kFumenNameKey = @"fumenName";
static NSString *const kDlFlagKey = @"dlFlag";
static NSString *const kNotesNumKey = @"notesNum";
static NSString *const kCopyLockKey = @"copyLock";
static NSString *const kUserTagKey = @"userTag";

// The two top-section menu entries, indexed by the menu index (0 and 1).
static NSString *const kMenuText[] = {@"譜面を作る", @"この曲の譜面を探す"};
static NSString *const kMenuIconName[] = {@"edit_icon_new", @"edit_icon_download"};

// The menu index for each menu action.
enum { kMenuIndexNewFile = 0, kMenuIndexDownload = 1 };

// The three table sections.
enum { kSectionMenu = 0, kSectionFiles = 1, kSectionBlank = 2, kSectionCount = 3 };

@implementation EditFileListViewDeleteController {
    NSString *selectName;
    int fileCnt;
    int blankCnt;
    int slotLim;
    BOOL waitEnter;
    UITableViewCell *menuCell[2];
    int menuIndex[2];
    UILabel *sectionLabel[3];
}

#pragma mark - Lifecycle

- (instancetype)initWithSize:(CGSize)size {
    /** @ghidraAddress 0x1f8d10 */
    self = [super initWithSize:size];
    if (self != nil) {
        selectName = nil;
        slotLim = [[EditDataManager sharedManager] getEditSlotLimit];
    }
    return self;
}

#pragma mark - Cell building

- (UITableViewCell *)getNewFileCell:(UITableView *)tableView row:(int)row {
    /** @ghidraAddress 0x1f8db0 */
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kMenuCellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                      reuseIdentifier:kMenuCellIdentifier];
    }
    cell.textLabel.text = kMenuText[row];
    // fmov immediate 0x4032000000000000 (18.0) at 0x1f8e9c.
    cell.textLabel.font = [UIFont boldSystemFontOfSize:18.0];
    cell.imageView.image = LoadScaledPngImage(kMenuIconName[row]);
    return cell;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    /** @ghidraAddress 0x1f8f78 */
    if (indexPath.section == kSectionMenu) {
        UITableViewCell *cell = [self getNewFileCell:tableView row:menuIndex[indexPath.row]];
        menuCell[indexPath.row] = cell;
        if (self.fileList.count < (NSUInteger)slotLim && !self.isShared) {
            cell.textLabel.textColor = UIColor.blackColor;
            cell.selectionStyle = UITableViewCellSelectionStyleBlue;
        } else {
            cell.textLabel.textColor = UIColor.grayColor;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
        }
        return cell;
    }

    EditorInfoCell *cell =
        (EditorInfoCell *)[tableView dequeueReusableCellWithIdentifier:kInfoCellIdentifier];
    if (indexPath.section == kSectionFiles) {
        if (cell == nil) {
            cell = [[EditorInfoCell alloc] init];
        }
        NSDictionary *info = self.fileList[indexPath.row];
        cell.textLabel.text = info[kFumenNameKey];
        if ([info[kDlFlagKey] intValue] == 0) {
            cell.textLabel.textColor = UIColor.blueColor;
        } else {
            cell.textLabel.textColor = UIColor.blackColor;
        }
        cell.lockView.hidden = YES;
        [cell setUserTag:0];
        if ([info[kDlFlagKey] intValue] == 1) {
            if ([info[kCopyLockKey] intValue] == 0) {
                if ([JubeatAppDelegate appDelegate].isPad) {
                    cell.lockView.hidden = NO;
                }
            }
            if ([info[kUserTagKey] intValue] != 0) {
                [cell setUserTag:[info[kUserTagKey] intValue]];
            }
        }
        unsigned int notesNum = info[kNotesNumKey] ? [info[kNotesNumKey] unsignedIntValue] : 0;
        cell.detailTextLabel.text = [[NSString alloc] initWithFormat:@"%d", notesNum];
        cell.detailTextLabel.textAlignment = NSTextAlignmentRight;
        cell.detailTextLabel.backgroundColor = UIColor.clearColor;
    } else {
        if (cell == nil) {
            cell = [[EditorInfoCell alloc] init];
        }
        cell.textLabel.text = @"";
        cell.detailTextLabel.text = @"";
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.lockView.hidden = YES;
        [cell setUserTag:0];
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView
      willDisplayCell:(UITableViewCell *)cell
    forRowAtIndexPath:(NSIndexPath *)indexPath {
    /** @ghidraAddress 0x1f97b0 */
    if (indexPath.section == kSectionMenu) {
        BOOL highlight = (menuIndex[indexPath.row] == kMenuIndexNewFile);
        if (self.fileList.count != 0) {
            NSUInteger i = 0;
            while (selectName != nil) {
                NSString *name = self.fileList[i][kFileNameKey];
                BOOL differs = ![selectName isEqualToString:name];
                highlight = highlight && differs;
                if (!differs) {
                    break;
                }
                ++i;
                if (i >= self.fileList.count) {
                    break;
                }
            }
        }
        if (!highlight || self.isFirst) {
            return;
        }
        // colorWithHue:0.61 saturation:0.09 brightness:0.99 alpha:1.0 from __const 0x1002932d8,
        // 0x1002932e0, and 0x1002932e8.
        cell.backgroundColor = [UIColor colorWithHue:0.61
                                          saturation:0.09
                                          brightness:0.99
                                               alpha:1.0];
        return;
    }

    if (indexPath.section == kSectionFiles) {
        if (self.fileList.count <= (NSUInteger)indexPath.row) {
            return;
        }
        NSString *name = self.fileList[indexPath.row][kFileNameKey];
        if (![selectName isEqualToString:name]) {
            cell.backgroundColor = UIColor.whiteColor;
        } else {
            // Same pink-white highlight as the menu section (__const 0x1002932d8, e0, e8).
            cell.backgroundColor = [UIColor colorWithHue:0.61
                                              saturation:0.09
                                              brightness:0.99
                                                   alpha:1.0];
        }
        return;
    }

    cell.backgroundColor = UIColor.whiteColor;
}

#pragma mark - Table structure

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    /** @ghidraAddress 0x1f9ba8 */
    if (section == kSectionBlank) {
        return blankCnt;
    }
    if (section == kSectionFiles) {
        return fileCnt;
    }
    if (section == kSectionMenu) {
        if (![JubeatAppDelegate appDelegate].isPad) {
            menuIndex[0] = kMenuIndexDownload;
            return 1;
        }
        menuIndex[0] = kMenuIndexNewFile;
        menuIndex[1] = kMenuIndexDownload;
        return 2;
    }
    return 0;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    /** @ghidraAddress 0x1f9c7c */
    return kSectionCount;
}

- (void)tableView:(UITableView *)tableView
    commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
     forRowAtIndexPath:(NSIndexPath *)indexPath {
    /** @ghidraAddress 0x1f9c84 */
    if (editingStyle != UITableViewCellEditingStyleDelete) {
        return;
    }
    NSString *fileName = self.fileList[indexPath.row][kFileNameKey];
    [self.fileList removeObjectAtIndex:indexPath.row];
    --fileCnt;
    [tableView deleteRowsAtIndexPaths:@[ indexPath ] withRowAnimation:UITableViewRowAnimationNone];
    fileCnt = (int)self.fileList.count;
    if (slotLim < fileCnt) {
        fileCnt = slotLim;
    }
    blankCnt = slotLim - fileCnt;

    NSIndexPath *inserted;
    if (fileCnt < slotLim) {
        inserted = [NSIndexPath indexPathForRow:(slotLim - fileCnt - 1) inSection:kSectionBlank];
    } else {
        inserted = [NSIndexPath indexPathForRow:(slotLim - 1) inSection:kSectionFiles];
    }
    [tableView insertRowsAtIndexPaths:@[ inserted ] withRowAnimation:UITableViewRowAnimationFade];

    if ([self.delegate respondsToSelector:@selector(editFileListViewDeleteFile:)]) {
        [(id<EditFileListViewDeleteDelegate>)self.delegate editFileListViewDeleteFile:fileName];
    }

    if (self.fileList.count < (NSUInteger)slotLim) {
        if (!self.isShared) {
            menuCell[0].textLabel.textColor = UIColor.blackColor;
            menuCell[0].selectionStyle = UITableViewCellSelectionStyleBlue;
            menuCell[1].textLabel.textColor = UIColor.blackColor;
            menuCell[1].selectionStyle = UITableViewCellSelectionStyleBlue;
        }
        [tableView deselectRowAtIndexPath:indexPath animated:NO];
    }

    // colorWithRed:0.65 green:0.69 blue:0.73 alpha:1.0 from __const 0x100293d78, 0x100293d80, and
    // 0x100293d88.
    UIColor *labelColor = [UIColor colorWithRed:0.65 green:0.69 blue:0.73 alpha:1.0];
    sectionLabel[0].backgroundColor = labelColor;
    sectionLabel[1].backgroundColor = labelColor;
    sectionLabel[2].backgroundColor = labelColor;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    /** @ghidraAddress 0x1fa274 */
    if (indexPath.section == kSectionFiles) {
        if ((NSUInteger)indexPath.row < self.fileList.count) {
            NSString *name = self.fileList[indexPath.row][kFileNameKey];
            (void)[selectName isEqualToString:name]; // Yes, the binary discards this comparison.
            return YES;
        }
    }
    return NO;
}

#pragma mark - Footer

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    /** @ghidraAddress 0x1fa3d0 */
    // fmov immediates: 4.0 at 0x1fa3e4, 1.0 at 0x1fa3d4.
    if (section == kSectionMenu) {
        return 4.0;
    }
    if (section == kSectionFiles) {
        return 0.0;
    }
    return 1.0;
}

- (nullable UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
    /** @ghidraAddress 0x1fa3f0 */
    if (self.fileList.count < (NSUInteger)slotLim) {
        return nil;
    }
    UIView *footer = [[UIView alloc] init];
    CGFloat width = tableView.frame.size.width;
    CGFloat height = [self tableView:tableView heightForFooterInSection:section];
    footer.backgroundColor = UIColor.clearColor;
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0.0, 0.0, width, height)];
    sectionLabel[section] = label;
    // colorWithRed:0.9333 green:0.3686 blue:0.4784 alpha:1.0 from __const 0x100293d90, 0x100293d98,
    // and 0x100293b08.
    label.backgroundColor = [UIColor colorWithRed:0.9333333373069763
                                            green:0.3686274588108063
                                             blue:0.47843137383461
                                            alpha:1.0];
    [footer addSubview:label];
    return footer;
}

#pragma mark - Selection

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    /** @ghidraAddress 0x1fa5e4 */
    if (indexPath.section == kSectionMenu) {
        int index = menuIndex[indexPath.row];
        if (self.isShared) {
            return;
        }
        if (self.fileList.count < (NSUInteger)slotLim) {
            id<EditFileListViewDeleteDelegate> delegate =
                (id<EditFileListViewDeleteDelegate>)self.delegate;
            if (index == kMenuIndexDownload) {
                if (![JubeatAppDelegate appDelegate].isPad) {
                    JcfDownloadPageViewController *page =
                        [[JcfDownloadPageViewController alloc] initWithMusicID:self.tuneID
                                                                      delegate:self.delegate];
                    [page setBFromNavigate:YES];
                    [self.navigationController pushViewController:page animated:YES];
                    return;
                }
                if ([delegate respondsToSelector:@selector(editFileListViewSelectDownload)]) {
                    [delegate editFileListViewSelectDownload];
                }
            } else if (index == kMenuIndexNewFile) {
                if ([delegate respondsToSelector:@selector(editFileListViewSelectNewFile)]) {
                    [delegate editFileListViewSelectNewFile];
                }
            }
        } else {
            NSString *ok = [[NSBundle mainBundle] localizedStringForKey:@"OK" value:@"" table:nil];
            [[AlertViewManager sharedManager]
                makeAlert:0
                 delegate:nil
                      tag:0
                    title:nil
                      msg:@"スロットがいっぱいです。どれか削除して下さい。"
                   cancel:ok
                  btnText:nil
                     show:YES];
        }
        return;
    }

    if (indexPath.section == kSectionFiles) {
        if ((NSUInteger)indexPath.row < self.fileList.count) {
            if ([self.delegate respondsToSelector:@selector(editFileListViewSelectItem:)]) {
                [self.delegate editFileListViewSelectItem:indexPath.row];
            }
        }
    }
}

#pragma mark - Data

- (void)setTargetFileName:(nullable NSString *)targetFileName {
    /** @ghidraAddress 0x1faa34 */
    selectName = targetFileName;
}

- (void)setFileList:(nullable NSMutableArray *)fileList {
    /** @ghidraAddress 0x1faa48 */
    [super setFileList:fileList];
    fileCnt = (int)self.fileList.count;
    if (slotLim < fileCnt) {
        fileCnt = slotLim;
    }
    blankCnt = slotLim - fileCnt;
}

- (void)reloadTable {
    /** @ghidraAddress 0x1fab04 */
    [self.tableView reloadData];
}

@end

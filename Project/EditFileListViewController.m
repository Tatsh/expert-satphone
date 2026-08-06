#import "EditFileListViewController.h"

#import <QuartzCore/QuartzCore.h>

static NSString *const kCellIdentifier = @"EditFileListViewTableCell";

// The two keys each element of fileList carries.
static NSString *const kFumenNameKey = @"fumenName";
static NSString *const kNotesNumKey = @"notesNum";

static NSString *const kNoteCountFormat = @"%d";

@implementation EditFileListViewController {
    // Declared in the metadata and written by nothing in this class.
    UILabel *labelMessage;
    UITableView *tableFiles;
    UIView *shadowView;
}

/** @ghidraAddress 0x208318 */
+ (Class)layerClass {
    return CAGradientLayer.class;
}

/** @ghidraAddress 0x20832c */
- (instancetype)initWithSize:(CGSize)size {
    self = [super initWithStyle:UITableViewStylePlain];
    if (self) {
        self.preferredContentSize = size;
    }
    return self;
}

/** @ghidraAddress 0x2083a4 */
- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kCellIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
                                      reuseIdentifier:kCellIdentifier];
    }

    NSDictionary *file = [self.fileList objectAtIndex:indexPath.row];
    cell.textLabel.text = [file objectForKey:kFumenNameKey];

    // The key is fetched twice, once to test for its presence and once to read it.
    unsigned int noteCount = 0;
    if ([file objectForKey:kNotesNumKey]) {
        noteCount = [[file objectForKey:kNotesNumKey] unsignedIntValue];
    }
    cell.detailTextLabel.text = [[NSString alloc] initWithFormat:kNoteCountFormat, noteCount];
    cell.detailTextLabel.textAlignment = NSTextAlignmentRight;

    return cell;
}

/** @ghidraAddress 0x208634 */
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // The section is not consulted; there is only ever one.
    return self.fileList.count;
}

/** @ghidraAddress 0x20864c */
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    // The row index goes to the delegate, not the chart itself. The delegate is loaded from the
    // weak slot twice, once to test and once to send to.
    if ([self.delegate respondsToSelector:@selector(editFileListViewSelectItem:)]) {
        [self.delegate editFileListViewSelectItem:indexPath.row];
    }
}

@end

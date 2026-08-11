#import "EditModalView.h"

#import "EditModalTableViewController.h"

// Not yet reconstructed: the table controller that holds the edit form's rows and upload button.

// The edit-mode value that turns on uploading and hides the Cancel and Update bar-button items.
static const int kEditTypeUpload = 1;

// The navigation bar's translucent tint, from the double at 0x28f230.
static const CGFloat kNavigationBarTintWhite = 0.6;
// The lighter tint used for the bar's foreground when it accepts a bar-tint colour, from the double
// at 0x28f448.
static const CGFloat kNavigationBarForegroundWhite = 0.9;

// The text field's black border, one point wide.
static const CGFloat kTextFieldBorderWidth = 1.0;

@interface EditModalView () <UITextFieldDelegate>
@end

@implementation EditModalView {
    EditModalTableViewController *tableCtrl;
    UITextField *titleText;
    UITextField *editorText;
    UITextField *commentText;
    UITableView *infoTableView;
    UILabel *testText;
    UISlider *levelSlider;
    int editType;
    // Weak: the binary stores it with objc_storeWeak, not objc_storeStrong.
    __weak id<EditModalViewDelegate> _editDelegate;
}

@synthesize editDelegate = _editDelegate;

/** @ghidraAddress 0x1e5060 */
- (instancetype)initWithType:(int)type {
    self = [super init];
    if (self) {
        editType = type;
        self.modalPresentationStyle = UIModalPresentationFormSheet;
        self.navigationBar.barStyle = UIBarStyleBlack;
        if ([self.navigationBar respondsToSelector:@selector(setBarTintColor:)]) {
            [self.navigationBar performSelector:@selector(setBarTintColor:)
                                     withObject:[UIColor colorWithWhite:kNavigationBarTintWhite
                                                                  alpha:1.0]];
            self.navigationBar.tintColor = [UIColor colorWithWhite:kNavigationBarForegroundWhite
                                                             alpha:1.0];
        } else {
            self.navigationBar.tintColor = [UIColor colorWithWhite:kNavigationBarTintWhite
                                                             alpha:1.0];
        }

        tableCtrl =
            [[EditModalTableViewController alloc] initEnableUpload:(editType == kEditTypeUpload)];
        [tableCtrl setDelegate:self];

        if (editType != kEditTypeUpload) {
            NSString *cancelTitle = [NSBundle.mainBundle localizedStringForKey:@"Cancel"
                                                                         value:@""
                                                                         table:nil];
            UIBarButtonItem *cancelItem =
                [[UIBarButtonItem alloc] initWithTitle:cancelTitle
                                                 style:UIBarButtonItemStyleDone
                                                target:self
                                                action:@selector(pushClose:)];
            tableCtrl.navigationItem.leftBarButtonItem = cancelItem;

            UIBarButtonItem *updateItem =
                [[UIBarButtonItem alloc] initWithTitle:@"更新"
                                                 style:UIBarButtonItemStyleDone
                                                target:self
                                                action:@selector(pushUpdate:)];
            tableCtrl.navigationItem.rightBarButtonItem = updateItem;
        }

        self.viewControllers = @[ tableCtrl ];
    }
    return self;
}

/** @ghidraAddress 0x1e4e38 */
- (void)setTextField:(UITextField *)textField frame:(CGRect)frame {
    // The passed field is ignored; the method builds and configures its own.
    UITextField *field = [[UITextField alloc] initWithFrame:frame];
    field.keyboardType = UIKeyboardTypeDefault;
    field.textAlignment = NSTextAlignmentLeft;
    field.delegate = self;
    [self.view addSubview:field];
    field.layer.borderColor = UIColor.blackColor.CGColor;
    field.layer.borderWidth = kTextFieldBorderWidth;
    field.backgroundColor = UIColor.whiteColor;
    field.autocapitalizationType = UITextAutocapitalizationTypeNone;
    field.autocorrectionType = UITextAutocorrectionTypeNo;
    field.returnKeyType = UIReturnKeyDone;
    [field addTarget:self
                  action:@selector(fieldChanged:)
        forControlEvents:UIControlEventEditingChanged];
}

/** @ghidraAddress 0x1e547c */
- (void)pushClose:(id)sender {
    [NSUserDefaults.standardUserDefaults synchronize];
    if ([self.editDelegate respondsToSelector:@selector(editModalViewClose:)]) {
        [self.editDelegate performSelector:@selector(editModalViewClose:) withObject:self];
    }
}

/** @ghidraAddress 0x1e5568 */
- (void)pushUpdate:(id)sender {
    [tableCtrl setEditorInfo];
    [self.editDelegate editModalViewDelegateSaveEditFile];
    [self pushClose:sender];
}

/** @ghidraAddress 0x1e5600 */
- (void)selectUpdate:(id)sender {
    [tableCtrl setEditorInfo];
    [self.editDelegate editModalViewDelegateSaveEditFile];
    if ([self.editDelegate respondsToSelector:@selector(selectUpdate:)]) {
        [self.editDelegate performSelector:@selector(selectUpdate:) withObject:self];
    }
}

/** @ghidraAddress 0x1e56fc */
- (void)openEditModal {
}

#pragma mark - UIViewController

/** @ghidraAddress 0x1e5700 */
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)orientation {
    // The mask is Portrait | PortraitUpsideDown, tested as the unsigned (orientation - 1) < 2.
    return (NSUInteger)(orientation - 1) < 2;
}

/** @ghidraAddress 0x1e5710 */
- (void)viewDidLoad {
}

/** @ghidraAddress 0x1e5714 */
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

/** @ghidraAddress 0x1e574c */
- (void)viewDidUnload {
}

// The binary's -dealloc (0x1e5750) only forwards to [super dealloc]; under ARC that is implicit, so
// it is intentionally omitted.

/** @ghidraAddress 0x1e5788 */
- (void)terminate {
}

#pragma mark - UITableViewDelegate

/** @ghidraAddress 0x1e578c */
- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    return 0.0;
}

@end

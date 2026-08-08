#import "AlertViewManager.h"

#import "JubeatAppDelegate.h"

// The App Store product page opened when the update alert's button is tapped.
static NSString *const kAppStoreURL =
    @"https://itunes.apple.com/WebObjects/MZStore.woa/wa/viewSoftware?id=395192484&mt=8";

// The keys of the dictionary handed to the delegate.
static NSString *const kAlertInfoTagKey = @"Tag";
static NSString *const kAlertInfoButtonKey = @"btnMessage";
static NSString *const kAlertInfoMessageKey = @"Message";

// The alert type that adds a single plain-text input field.
static const int kAlertTypeTextInput = 1;

// The alert type whose "other" button (index 1) opens the App Store.
static const int kAlertTypeAppStore = 2;

// The shared singleton, created once by +sharedManager. From the global at 0x354148.
static AlertViewManager *g_pAlertViewManagerShared = nil;

@interface AlertViewManager () {
    UIAlertController *alertController;             // +0x8
    UIAlertView *alertView;                         // +0x10
    __weak id<AlertViewManagerDelegate> alDelegate; // +0x18, objc_storeWeak at 0xa8dbc
    int alertTag;                                   // +0x20
    int alertType;                                  // +0x24
    NSString *alertText;                            // +0x28
}
- (void)setAlert:(nullable UIAlertView *)alert;
- (void)setAlert:(nullable UIAlertView *)alert tag:(int)tag show:(BOOL)show;
- (void)showAlert;
- (void)changeDelegate:(nullable id<AlertViewManagerDelegate>)delegate;
- (void)alertControllerEvent:(int)buttonIndex;
- (void)alertTextFieldTextDidChangeNotification:(nonnull NSNotification *)notification;
@end

@implementation AlertViewManager

#pragma mark - Singleton

/** @ghidraAddress 0xa89b4 */
+ (instancetype)sharedManager {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
      /** @ghidraAddress 0xa89f4 */
      g_pAlertViewManagerShared = [[AlertViewManager alloc] init];
    });
    return g_pAlertViewManagerShared;
}

/** @ghidraAddress 0xa8a34 */
- (instancetype)init {
    return [super init];
}

#pragma mark - Legacy setters

/** @ghidraAddress 0xa8a6c */
- (void)setAlert:(UIAlertView *)alert {
    alertView = alert;
}

/** @ghidraAddress 0xa8a80 */
- (void)setAlert:(UIAlertView *)alert tag:(int)tag show:(BOOL)show {
    alertView = alert;
    alertView.tag = tag;
    if (show) {
        [alertView show];
    }
}

#pragma mark - Construction

/** @ghidraAddress 0xa8b08 */
- (void)closeAlert {
    if (NSClassFromString(@"UIAlertController")) {
        if (alertController) {
            [alertController
                dismissViewControllerAnimated:NO
                                   completion:^{
                                     /** @ghidraAddress 0xa8bd8 */
                                     // Tell the delegate the alert closed, passing its
                                     // tag; the finished flag is ignored.
                                     NSMutableDictionary *info = [[NSMutableDictionary alloc] init];
                                     info[kAlertInfoTagKey] = @(self->alertTag);
                                     if ([self->alDelegate
                                             respondsToSelector:@selector(alertClose:)]) {
                                         [self->alDelegate performSelector:@selector(alertClose:)
                                                                withObject:info];
                                     }
                                   }];
        }
        return;
    }
    if (alertView) {
        [alertView dismissWithClickedButtonIndex:0 animated:NO];
    }
}

/** @ghidraAddress 0xa8cfc */
- (void)makeAlert:(int)type
          delegate:(id<AlertViewManagerDelegate>)delegate
               tag:(int)tag
             title:(NSString *)title
               msg:(NSString *)msg
            cancel:(NSString *)cancelBtnText
           btnText:(NSArray<NSString *> *)otherButtonTitles
              show:(BOOL)show
    viewController:(UIViewController *)viewController {
    [self closeAlert];
    alDelegate = delegate;
    alertTag = tag;
    alertType = type;
    alertText = nil;
    if (!title) {
        title = @"";
    }
    if (!NSClassFromString(@"UIAlertController")) {
        alertView = [[UIAlertView alloc] init];
        alertView.delegate = self;
        alertView.title = title;
        alertView.message = msg;
        if (type == kAlertTypeTextInput) {
            alertView.alertViewStyle = UIAlertViewStylePlainTextInput;
        }
        [alertView addButtonWithTitle:cancelBtnText];
        for (NSString *buttonTitle in otherButtonTitles) {
            [alertView addButtonWithTitle:buttonTitle];
        }
        if (show) {
            [alertView show];
        }
        return;
    }

    alertController = [UIAlertController alertControllerWithTitle:title
                                                          message:msg
                                                   preferredStyle:UIAlertControllerStyleAlert];
    if (type == kAlertTypeTextInput) {
        __weak AlertViewManager *weakSelf = self;
        [alertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
          /** @ghidraAddress 0xa93e8 */
          self->alertText = @"";
          textField.placeholder = @"";
          [NSNotificationCenter.defaultCenter
              addObserver:weakSelf
                 selector:@selector(alertTextFieldTextDidChangeNotification:)
                     name:UITextFieldTextDidChangeNotification
                   object:textField];
        }];
    }
    int buttonIndex = 1;
    for (NSString *buttonTitle in otherButtonTitles) {
        int index = buttonIndex;
        UIAlertAction *action = [UIAlertAction actionWithTitle:buttonTitle
                                                         style:UIAlertActionStyleDefault
                                                       handler:^(UIAlertAction *action) {
                                                         /** @ghidraAddress 0xa9520 */
                                                         [self alertControllerEvent:index];
                                                       }];
        [alertController addAction:action];
        ++buttonIndex;
    }
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:cancelBtnText
                                                           style:UIAlertActionStyleCancel
                                                         handler:^(UIAlertAction *action) {
                                                           /** @ghidraAddress 0xa9548 */
                                                           [self alertControllerEvent:0];
                                                         }];
    [alertController addAction:cancelAction];
    if (show) {
        if (viewController) {
            [viewController presentViewController:alertController animated:YES completion:nil];
        } else {
            [JubeatAppDelegate.appDelegate.rootViewCtrl presentViewController:alertController
                                                                     animated:YES
                                                                   completion:nil];
        }
    }
}

/** @ghidraAddress 0xa956c */
- (void)makeAlert:(int)type
         delegate:(id<AlertViewManagerDelegate>)delegate
              tag:(int)tag
            title:(NSString *)title
              msg:(NSString *)msg
           cancel:(NSString *)cancelBtnText
          btnText:(NSArray<NSString *> *)otherButtonTitles
             show:(BOOL)show {
    [self makeAlert:type
              delegate:delegate
                   tag:tag
                 title:title
                   msg:msg
                cancel:cancelBtnText
               btnText:otherButtonTitles
                  show:show
        viewController:nil];
}

/** @ghidraAddress 0xa964c */
- (void)showUpdateAlert {
    NSString *title = [NSBundle.mainBundle localizedStringForKey:@"App update is required."
                                                           value:@""
                                                           table:nil];
    NSString *cancel = [NSBundle.mainBundle localizedStringForKey:@"Cancel" value:@"" table:nil];
    NSArray<NSString *> *others = @[ @"アップデート" ];
    [self makeAlert:kAlertTypeAppStore
              delegate:nil
                   tag:0
                 title:title
                   msg:nil
                cancel:cancel
               btnText:others
                  show:YES
        viewController:nil];
}

/** @ghidraAddress 0xa97dc */
- (void)showAlert {
}

/** @ghidraAddress 0xa97e0 */
- (void)changeDelegate:(id<AlertViewManagerDelegate>)delegate {
}

#pragma mark - Delegate notification

// Shared by the UIAlertController button/cancel handlers and (as -alertView:clickedButtonAtIndex:)
// the UIAlertView path: package the tag and tapped-button index and hand them to the delegate.
/** @ghidraAddress 0xa97e4 */
- (void)alertControllerEvent:(int)buttonIndex {
    if (alDelegate) {
        NSMutableDictionary *info = [[NSMutableDictionary alloc] init];
        info[kAlertInfoTagKey] = @(alertTag);
        info[kAlertInfoButtonKey] = @(buttonIndex);
        if (alertType == kAlertTypeTextInput) {
            info[kAlertInfoMessageKey] = alertText;
        }
        if ([alDelegate respondsToSelector:@selector(alertSelect:)]) {
            [alDelegate performSelector:@selector(alertSelect:) withObject:info];
        }
    }
    if (buttonIndex == 1 && alertType == kAlertTypeAppStore) {
        [UIApplication.sharedApplication openURL:[NSURL URLWithString:kAppStoreURL]];
    }
}

#pragma mark - UIAlertViewDelegate

/** @ghidraAddress 0xa9a28 */
- (void)alertView:(UIAlertView *)theAlertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (alDelegate) {
        NSMutableDictionary *info = [[NSMutableDictionary alloc] init];
        info[kAlertInfoTagKey] = @(alertTag);
        info[kAlertInfoButtonKey] = @((int)buttonIndex);
        if (alertType == kAlertTypeTextInput) {
            info[kAlertInfoMessageKey] = [alertView textFieldAtIndex:0].text;
        }
        if ([alDelegate respondsToSelector:@selector(alertSelect:)]) {
            [alDelegate performSelector:@selector(alertSelect:) withObject:info];
        }
    }
    if (buttonIndex == 1 && alertType == kAlertTypeAppStore) {
        [UIApplication.sharedApplication openURL:[NSURL URLWithString:kAppStoreURL]];
    }
}

#pragma mark - Text field observation

/** @ghidraAddress 0xa9cb4 */
- (void)alertTextFieldTextDidChangeNotification:(NSNotification *)notification {
    if (alertController) {
        alertText = alertController.textFields.firstObject.text;
    }
}

@end

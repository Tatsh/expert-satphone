#import "ChallengeMenuRootView.h"

#import "AudioManager.h"
#import "ChallengePrevRankingView.h"
#import "JubeatAppDelegate.h"

// ChallengePrevRankingView is not yet reconstructed; its case in -createMenuView: is stubbed to
// track the binary until its header lands.

// Sub-view selectors passed to -createMenuView: and -enterMenuSelectedView:.
typedef enum {
    ChallengeMenuRootViewIndexPresent = 0,
    ChallengeMenuRootViewIndexNameSetting = 1,
    ChallengeMenuRootViewIndexRivalSearch = 2,
    ChallengeMenuRootViewIndexRivalList = 3,
    ChallengeMenuRootViewIndexPrevRanking = 4,
    ChallengeMenuRootViewIndexLoginInformation = 5,
} ChallengeMenuRootViewIndex;

// Every animation in this class uses the same 0.2 s linear tween with no delay. Duration read
// from the __const pool at 0x28e040; options 0x30000 is UIViewAnimationOptionCurveLinear.
static const NSTimeInterval kChallengeMenuAnimationDuration = 0.2; // @ghidraAddress 0x28e040

// The dimming cover's black is 40% opaque. Alpha read from the __const pool at 0x28f2c0.
static const CGFloat kChallengeMenuCoverAlpha = 0.4; // @ghidraAddress 0x28f2c0

// The default challenge how-to page, seeded into user defaults when absent.
static NSString *const kChallengeHowtoURLKey = @"PrefChallengeHowtoURL";
static NSString *const kChallengeHowtoURLDefault =
    @"https://stg-agx11.s.konaminet.jp/agx/web/info/iOS/v1/Scratch/";

// Sound-effect resource names.
static NSString *const kChallengeCancelSE = @"SD_CHALLENGE_CANCEL";
static NSString *const kChallengeLaboMenuSE = @"SD_LABO_MENU";

@interface ChallengeMenuRootView () {
    UIView *coverView;
    BOOL isPad;
    UIView *currentView;
    ChallengeMenuView *menuView;
    ChallengePresentView *presentView;
    ChallengeNameSettingView *nameSettingView;
    ChallengeRivalSearchView *rivalSearchView;
    ChallengeRivalListView *rivalListView;
    ChallengePrevRankingView *prevRankingView;
    ChallengeLoginInformationView *loginInformation;
}
@end

@implementation ChallengeMenuRootView

@synthesize aDelegate = _aDelegate;

#pragma mark - Lifecycle

/** @ghidraAddress 0x100ed8 */
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        isPad = [JubeatAppDelegate.appDelegate isPad];
        self.opaque = NO;
        self.layer.doubleSided = NO;

        coverView = [[UIView alloc] initWithFrame:frame];
        coverView.opaque = NO;
        coverView.backgroundColor = [UIColor colorWithWhite:0 alpha:kChallengeMenuCoverAlpha];
        coverView.alpha = 0;
        [self addSubview:coverView];

        menuView = [[ChallengeMenuView alloc] initWithFrame:frame];
        menuView.aDelegate = self;
        menuView.alpha = 0;
        [self addSubview:menuView];

        if (![NSUserDefaults.standardUserDefaults objectForKey:kChallengeHowtoURLKey]) {
            [NSUserDefaults.standardUserDefaults setObject:kChallengeHowtoURLDefault
                                                    forKey:kChallengeHowtoURLKey];
        }
    }
    return self;
}

#pragma mark - Transitions

/** @ghidraAddress 0x1011bc */
- (void)enterRootMenu {
    __weak UIView *weakCover = coverView;
    __weak ChallengeMenuView *weakMenu = menuView;
    [UIView animateWithDuration:kChallengeMenuAnimationDuration
                          delay:0
                        options:UIViewAnimationOptionCurveLinear
                     animations:^{
                       /** @ghidraAddress 0x1012e0 */
                       weakCover.alpha = 1;
                       weakMenu.alpha = 1;
                     }
                     completion:^(BOOL __attribute__((unused)) finished){
                         /** @ghidraAddress 0x1013b0 */
                     }];
}

/** @ghidraAddress 0x1013b4 */
- (void)enterMenuSelectedView:(int)index {
    [self createMenuView:index];
    if (currentView) {
        __weak UIView *weakCurrent = currentView;
        [UIView animateWithDuration:kChallengeMenuAnimationDuration
                              delay:0
                            options:UIViewAnimationOptionCurveLinear
                         animations:^{
                           /** @ghidraAddress 0x10149c */
                           weakCurrent.alpha = 1;
                         }
                         completion:^(BOOL __attribute__((unused)) finished){
                             /** @ghidraAddress 0x1014e8 */
                         }];
    }
}

/** @ghidraAddress 0x1014ec */
- (void)closeRootMenu {
    [[AudioManager sharedManager] playSeResFile:kChallengeCancelSE inDirectory:nil];
    __weak UIView *weakCover = coverView;
    __weak ChallengeMenuView *weakMenu = menuView;
    [UIView animateWithDuration:kChallengeMenuAnimationDuration
        delay:0
        options:UIViewAnimationOptionCurveLinear
        animations:^{
          /** @ghidraAddress 0x101688 */
          weakCover.alpha = 0;
          weakMenu.alpha = 0;
        }
        completion:^(BOOL __attribute__((unused)) finished) {
          /** @ghidraAddress 0x10174c */
          [self.aDelegate closeMenuView];
        }];
}

/** @ghidraAddress 0x1017a0 */
- (void)enterMenu {
    __weak ChallengeMenuView *weakMenu = menuView;
    [UIView animateWithDuration:kChallengeMenuAnimationDuration
                          delay:0
                        options:UIViewAnimationOptionCurveLinear
                     animations:^{
                       /** @ghidraAddress 0x101874 */
                       weakMenu.alpha = 1;
                     }
                     completion:^(BOOL __attribute__((unused)) finished){
                         /** @ghidraAddress 0x1018c0 */
                     }];
}

/** @ghidraAddress 0x1018c4 */
- (void)outerMenu {
    [[AudioManager sharedManager] playSeResFile:kChallengeCancelSE inDirectory:nil];
    __weak ChallengeMenuView *weakMenu = menuView;
    [UIView animateWithDuration:kChallengeMenuAnimationDuration
                          delay:0
                        options:UIViewAnimationOptionCurveLinear
                     animations:^{
                       /** @ghidraAddress 0x1019dc */
                       weakMenu.alpha = 0;
                     }
                     completion:^(BOOL __attribute__((unused)) finished){
                         /** @ghidraAddress 0x101a28 */
                     }];
}

/** @ghidraAddress 0x101a2c */
- (void)switchInMenu {
    __weak ChallengeMenuView *weakMenu = menuView;
    __weak UIView *weakCurrent = currentView;
    [UIView animateWithDuration:kChallengeMenuAnimationDuration
        delay:0
        options:UIViewAnimationOptionCurveLinear
        animations:^{
          /** @ghidraAddress 0x101b78 */
          weakMenu.alpha = 0;
        }
        completion:^(BOOL __attribute__((unused)) finished) {
          /** @ghidraAddress 0x101bc4 */
          [UIView animateWithDuration:kChallengeMenuAnimationDuration
                                delay:0
                              options:UIViewAnimationOptionCurveLinear
                           animations:^{
                             /** @ghidraAddress 0x101c74 */
                             weakCurrent.alpha = 1;
                           }
                           completion:^(BOOL __attribute__((unused)) finished2){
                               /** @ghidraAddress 0x101cc0 */
                           }];
        }];
}

/** @ghidraAddress 0x101cd8 */
- (void)switchOutMenu {
    __weak ChallengeMenuView *weakMenu = menuView;
    __weak UIView *weakCurrent = currentView;
    [[AudioManager sharedManager] playSeResFile:kChallengeCancelSE inDirectory:nil];
    [self.aDelegate refreshView];
    [UIView animateWithDuration:kChallengeMenuAnimationDuration
        delay:0
        options:UIViewAnimationOptionCurveLinear
        animations:^{
          /** @ghidraAddress 0x101eb0 */
          // The current view is faded out and unmounted in the same step; the alpha change is
          // never seen because the removal is immediate rather than deferred to completion.
          weakCurrent.alpha = 0;
          [self->currentView removeFromSuperview];
          self->currentView = nil;
        }
        completion:^(BOOL __attribute__((unused)) finished) {
          /** @ghidraAddress 0x101f6c */
          [UIView animateWithDuration:kChallengeMenuAnimationDuration
                                delay:0
                              options:UIViewAnimationOptionCurveLinear
                           animations:^{
                             /** @ghidraAddress 0x10201c */
                             weakMenu.alpha = 1;
                             [weakMenu refreshView];
                           }
                           completion:^(BOOL __attribute__((unused)) finished2){
                               /** @ghidraAddress 0x10208c */
                           }];
        }];
}

#pragma mark - Sub-view construction

/** @ghidraAddress 0x1020a4 */
- (void)createMenuView:(int)index {
    // Every sub-view is built at the container's full bounds. The binary reads self.frame twice
    // (once for the width, once for the height); a single read of self.frame.size is equivalent.
    CGRect bounds = CGRectMake(0, 0, self.frame.size.width, self.frame.size.height);
    switch (index) {
    case ChallengeMenuRootViewIndexPresent:
        if (presentView) {
            presentView = nil;
        }
        presentView = [[ChallengePresentView alloc] initWithFrame:bounds];
        presentView.aDelegate = self;
        presentView.userInteractionEnabled = YES;
        presentView.alpha = 0;
        [self addSubview:presentView];
        currentView = presentView;
        break;
    case ChallengeMenuRootViewIndexNameSetting:
        if (nameSettingView) {
            nameSettingView = nil;
        }
        nameSettingView = [[ChallengeNameSettingView alloc] initWithFrame:bounds backEnable:YES];
        nameSettingView.aDelegate = self;
        nameSettingView.userInteractionEnabled = YES;
        nameSettingView.alpha = 0;
        [self addSubview:nameSettingView];
        currentView = nameSettingView;
        break;
    case ChallengeMenuRootViewIndexRivalSearch:
        if (rivalSearchView) {
            rivalSearchView = nil;
        }
        rivalSearchView = [[ChallengeRivalSearchView alloc] initWithFrame:bounds];
        rivalSearchView.aDelegate = self;
        rivalSearchView.userInteractionEnabled = YES;
        rivalSearchView.alpha = 0;
        [self addSubview:rivalSearchView];
        currentView = rivalSearchView;
        break;
    case ChallengeMenuRootViewIndexRivalList:
        if (rivalListView) {
            rivalListView = nil;
        }
        rivalListView = [[ChallengeRivalListView alloc] initWithFrame:bounds];
        rivalListView.aDelegate = self;
        rivalListView.userInteractionEnabled = YES;
        rivalListView.alpha = 0;
        [self addSubview:rivalListView];
        currentView = rivalListView;
        break;
    case ChallengeMenuRootViewIndexPrevRanking:
        if (prevRankingView) {
            prevRankingView = nil;
        }
        prevRankingView = [[ChallengePrevRankingView alloc] initWithFrame:bounds];
        prevRankingView.aDelegate = self;
        prevRankingView.userInteractionEnabled = YES;
        prevRankingView.alpha = 0;
        [self addSubview:prevRankingView];
        currentView = prevRankingView;
        break;
    case ChallengeMenuRootViewIndexLoginInformation: {
        if (loginInformation) {
            loginInformation = nil;
        }
        NSString *dispURL =
            [NSUserDefaults.standardUserDefaults objectForKey:kChallengeHowtoURLKey];
        loginInformation = [[ChallengeLoginInformationView alloc] initWithFrame:bounds
                                                                        dispURL:dispURL
                                                                        btnType:1];
        loginInformation.aDelegate = self;
        loginInformation.userInteractionEnabled = YES;
        loginInformation.alpha = 0;
        [self addSubview:loginInformation];
        currentView = loginInformation;
        break;
    }
    default:
        return;
    }
}

#pragma mark - Child-view delegate callbacks

/** @ghidraAddress 0x102424 */
- (void)selectMenu:(nullable NSNumber *)menu {
    int index = menu.intValue;
    [[AudioManager sharedManager] playSeResFile:kChallengeLaboMenuSE inDirectory:nil];
    [self createMenuView:index];
    if (currentView) {
        [self switchInMenu];
    }
}

/** @ghidraAddress 0x1024dc */
- (void)closeMenu {
    [self switchOutMenu];
}

/** @ghidraAddress 0x1024e8 */
- (void)refreshStatus {
    if ([self.aDelegate respondsToSelector:@selector(refreshStatus)]) {
        [self.aDelegate performSelector:@selector(refreshStatus)];
    }
}

/** @ghidraAddress 0x102598 */
- (void)cubePurchase {
    if ([self.aDelegate respondsToSelector:@selector(cubePurchaseStart)]) {
        [self.aDelegate performSelector:@selector(cubePurchaseStart)];
    }
}

@end

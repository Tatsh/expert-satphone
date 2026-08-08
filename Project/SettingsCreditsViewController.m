#import "SettingsCreditsViewController.h"

#import "JubeatAppDelegate.h"

// The property-list decoding helpers the credits rows lean on. NSArray parses a plist blob into an
// array; NSDictionary exposes typed lookups. Both are reconstructed as categories elsewhere in the
// tree (ChallengeResourceManager.m, StorePackInfo.m); declared here for this file's use.
@interface NSArray (PropertyList)
+ (nullable NSArray *)arrayFromPropertyListData:(nullable NSData *)data;
@end

@interface NSDictionary (TypedAccessors)
- (nullable NSString *)stringForKey:(nonnull id)key;
- (nullable NSArray *)arrayForKey:(nonnull id)key;
@end

// The navigation-bar title shown on the credits screen.
static NSString *const kTitle = @"CREDITS";

// The two label fonts: the role/title labels use Helvetica at font_size0, the name labels use
// Helvetica-Bold at font_size1.
static NSString *const kTitleFontName = @"Helvetica";
static NSString *const kNameFontName = @"Helvetica-Bold";

// The plist keys naming a credit entry's role and its list of names.
static NSString *const kCreditKeyTitle = @"title";
static NSString *const kCreditKeyValue = @"value";

// The per-idiom label metrics written into the ivars at the top of -loadView.
static const int kPadFontSizeTitle = 13;
static const int kPadFontSizeName = 14;
static const int kPadIndentWidth = 20;
static const int kPhoneFontSizeTitle = 11;
static const int kPhoneFontSizeName = 12;
static const int kPhoneIndentWidth = 10;

// Each credit label is created at a fixed 100 x 25 frame before being shrunk to fit its text.
// @ghidraAddress 0x28f3f0 (width)
static const CGFloat kLabelWidth = 100.0;
static const CGFloat kLabelHeight = 25.0;

// The raw supported-orientation mask the binary returns: 6, i.e. portrait and portrait-upside-down
// (UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskPortraitUpsideDown). Kept as the
// literal the binary uses rather than a named mask, since it is not one of the common combinations.
static const UIInterfaceOrientationMask kSupportedOrientations =
    UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskPortraitUpsideDown;

@interface SettingsCreditsViewController () {
    int font_size0;   // +0x8; the role/title label point size.
    int font_size1;   // +0xc; the name label point size.
    int indent_width; // +0x10; the horizontal indent applied to each name label.
}

// Lays out one credit block, returning the vertical advance it consumed. The block is a plist
// string of either a name array or an array of {title, value} entries.
- (CGFloat)addCredit:(nullable const char *)credit
             atPoint:(CGPoint)point
                span:(CGFloat)span
            nameSpan:(CGFloat)nameSpan;
@end

@implementation SettingsCreditsViewController

#pragma mark - Construction

/** @ghidraAddress 0xe90b4 */
- (instancetype)init {
    self = [super init];
    if (!self) {
        return self;
    }
    self.navigationItem.title = kTitle;
    // An iOS 7 property, reached by selector so the class still builds against an older SDK.
    if ([self respondsToSelector:@selector(setExtendedLayoutIncludesOpaqueBars:)]) {
        [self performSelector:@selector(setExtendedLayoutIncludesOpaqueBars:) withObject:nil];
    }
    return self;
}

#pragma mark - Credit row layout

/** @ghidraAddress 0xe9170 */
- (CGFloat)addCredit:(const char *)credit
             atPoint:(CGPoint)point
                span:(CGFloat)span
            nameSpan:(CGFloat)nameSpan {
    NSData *data = [NSData dataWithBytes:credit length:strlen(credit)];
    NSArray *entries = [NSArray arrayFromPropertyListData:data];
    UIColor *clear = UIColor.clearColor;
    if (!entries) {
        return 0.0;
    }

    CGFloat cursor = 0.0;
    for (id entry in entries) {
        if ([entry isKindOfClass:[NSDictionary class]]) {
            // A {title, value} entry: a title label, then one indented label per name. The row's
            // span is only consumed when the entry actually carries a value array.
            NSString *title = [(NSDictionary *)entry stringForKey:kCreditKeyTitle];

            UILabel *titleLabel = [[UILabel alloc]
                initWithFrame:CGRectMake(point.x, point.y + cursor, kLabelWidth, kLabelHeight)];
            titleLabel.backgroundColor = clear;
            titleLabel.textColor = UIColor.whiteColor;
            titleLabel.font = [UIFont fontWithName:kTitleFontName size:(CGFloat)font_size0];
            titleLabel.text = title ?: @"";
            [titleLabel sizeToFit];
            [self.view addSubview:titleLabel];
            (void)titleLabel.frame; // Yes, the binary reads the frame and discards it.
            cursor += kLabelHeight + nameSpan;

            NSArray *names = [(NSDictionary *)entry arrayForKey:kCreditKeyValue];
            if (names) {
                for (id name in names) {
                    UILabel *nameLabel =
                        [[UILabel alloc] initWithFrame:CGRectMake(point.x + (CGFloat)indent_width,
                                                                  point.y + cursor,
                                                                  kLabelWidth,
                                                                  kLabelHeight)];
                    nameLabel.backgroundColor = clear;
                    nameLabel.textColor = UIColor.whiteColor;
                    nameLabel.font = [UIFont fontWithName:kNameFontName size:(CGFloat)font_size1];
                    nameLabel.text = name;
                    [nameLabel sizeToFit];
                    [self.view addSubview:nameLabel];
                    (void)nameLabel.frame; // Yes, the binary reads the frame and discards it.
                    cursor += kLabelHeight + nameSpan;
                }
                cursor += span;
            }
        } else {
            // A bare name entry: a single bold name label. The row's span is always consumed, even
            // for an element that is neither a dictionary nor a string.
            if ([entry isKindOfClass:[NSString class]]) {
                UILabel *nameLabel = [[UILabel alloc]
                    initWithFrame:CGRectMake(point.x, point.y + cursor, kLabelWidth, kLabelHeight)];
                nameLabel.backgroundColor = clear;
                nameLabel.textColor = UIColor.whiteColor;
                nameLabel.font = [UIFont fontWithName:kNameFontName size:(CGFloat)font_size1];
                nameLabel.text = entry;
                [nameLabel sizeToFit];
                [self.view addSubview:nameLabel];
                (void)nameLabel.frame; // Yes, the binary reads the frame and discards it.
                cursor += kLabelHeight + nameSpan;
            }
            cursor += span;
        }
    }
    return cursor;
}

#pragma mark - View construction

/** @ghidraAddress 0xe9968 */
- (void)loadView {
    [super loadView];
    self.view.backgroundColor = UIColor.blackColor;

    if (![JubeatAppDelegate appDelegate].isPad) {
        // Handset idiom. The four-inch handset (device type 2) tightens some of the row gaps.
        JubeatDeviceType deviceType = [JubeatAppDelegate appDelegate].deviceType;
        font_size0 = kPhoneFontSizeTitle;
        font_size1 = kPhoneFontSizeName;
        indent_width = kPhoneIndentWidth;

        CGFloat x = 170.0;
        [self addCredit:"(    { title = \"Server Programmers\";  value = ( \"Kazuki Shimizu\", "
                        "\"Kenji Maeda\", \"Makoto Harada\" ); },    { title = \"Sound "
                        "Designers\";     value = ( \"Eri Arakawa\" ); },)"
                atPoint:CGPointMake(x, deviceType == JubeatDeviceTypePhoneRetina4Inch ? 71.0 : 47.0)
                   span:0.0
               nameSpan:0.0];

        CGFloat cursor;
        CGFloat gap;
        if (deviceType == JubeatDeviceTypePhoneRetina4Inch) {
            cursor = [self addCredit:"(    { title = Director;                value = ( \"Hideyuki "
                                     "Seino\" ); },    { title = Artist;                  value = "
                                     "( \"Takamitsu Kinjo\", \"Miho Matsuo\" ); },    { title = "
                                     "Programmers;             value = ( \"Shogo Yoshida\", "
                                     "\"Takuji Terada\" ); },)"
                             atPoint:CGPointMake(15.0, 44.0)
                                span:0.0
                            nameSpan:0.0];
            cursor += 44.0;
            gap = 24.0;
        } else {
            cursor = [self addCredit:"(    { title = Director;                value = ( \"Hideyuki "
                                     "Seino\" ); },    { title = Artist;                  value = "
                                     "( \"Takamitsu Kinjo\", \"Miho Matsuo\" ); },    { title = "
                                     "Programmers;             value = ( \"Shogo Yoshida\", "
                                     "\"Takuji Terada\" ); },)"
                             atPoint:CGPointMake(15.0, 20.0)
                                span:0.0
                            nameSpan:0.0];
            cursor += 20.0;
            gap = 10.0;
        }

        cursor = [self addCredit:"( { title = Supervisors; value = ( \"Bemani Staff\" ); } )"
                         atPoint:CGPointMake(15.0, cursor + gap)
                            span:0.0
                        nameSpan:0.0] +
                 cursor + gap;

        [self addCredit:"(    { title = Director;           value = ( \"Yuto Nishino\" ); },    { "
                        "title = \"Art Director\";   value = ( \"Erina Takeda\" ); },    { title = "
                        "\"Sound Director\"; value = ( \"Shigeharu Saeki\" ); },    { title = "
                        "Producer;           value = ( \"Hiroyuki Masuda\" ); },)"
                atPoint:CGPointMake(35.0, cursor)
                   span:1.0
               nameSpan:-1.0];
        cursor += 12.0;

        cursor = [self addCredit:"(    \"Yoshito Fukuda\",    \"Shohei Sakuraba\",    \"Hitomi "
                                 "Isono\",    \"Michi Ryu\",    \"Natsumi Otsuka\",)"
                         atPoint:CGPointMake(180.0, cursor)
                            span:1.0
                        nameSpan:0.0] +
                 cursor + 4.0;

        cursor = [self addCredit:"( { title = \"and all arcade staff\"; } )"
                         atPoint:CGPointMake(x, cursor)
                            span:0.0
                        nameSpan:0.0] +
                 cursor + gap;

        [self
            addCredit:"(    { title = \"Licensing Coordinator\";   value = ( \"Kazunori "
                      "Miyahara\"); },    { title = \"Licensing Manager\";       value = ( "
                      "\"Kazuko Kuwabata\"); },    { title = \"QA Manager\";              value = "
                      "( \"Naoki Suya\" ); },    { title = \"Sales Promotion\";         value = ( "
                      "\"Hiroyuki Kabasawa\", \"Akira Goshima\", \"Kazuya Imura\" ); },)"
              atPoint:CGPointMake(15.0, cursor)
                 span:3.0
             nameSpan:-2.0];
        cursor += 26.0;

        cursor = [self addCredit:"(    { title = \"Special Thanks\";      value = ( \"Daji "
                                 "Takeuchi\", \"Hidetoshi Kuraishi\", \"Manami Kochi\", "
                                 "\"Shinsaku Inukai\" ); },)"
                         atPoint:CGPointMake(x, cursor)
                            span:4.0
                        nameSpan:-1.0] +
                 cursor + 6.0;

        [self addCredit:"(    { title = Producer;                value = ( \"Katsuyoshi Tanabe\" "
                        "); },)"
                atPoint:CGPointMake(x, cursor)
                   span:6.0
               nameSpan:0.0];
    } else {
        // Pad idiom.
        font_size0 = kPadFontSizeTitle;
        font_size1 = kPadFontSizeName;
        indent_width = kPadIndentWidth;

        CGFloat x = 290.0;
        [self addCredit:"(    { title = \"Server Programmers\";  value = ( \"Kazuki Shimizu\", "
                        "\"Kenji Maeda\", \"Makoto Harada\" ); },    { title = \"Sound "
                        "Designers\";     value = ( \"Eri Arakawa\" ); },)"
                atPoint:CGPointMake(x, 72.0)
                   span:0.0
               nameSpan:0.0];

        CGFloat cursor = [self addCredit:"(    { title = Director;                value = ( "
                                         "\"Hideyuki Seino\" ); },    { title = Artist;            "
                                         "      value = ( \"Takamitsu Kinjo\", \"Miho Matsuo\" ); "
                                         "},    { title = Programmers;             value = ( "
                                         "\"Shogo Yoshida\", \"Takuji Terada\" ); },)"
                                 atPoint:CGPointMake(70.0, 40.0)
                                    span:0.0
                                nameSpan:0.0];
        cursor += 40.0 + 18.0;

        cursor = [self addCredit:"( { title = Supervisors; value = ( \"Bemani Staff\" ); } )"
                         atPoint:CGPointMake(70.0, cursor)
                            span:0.0
                        nameSpan:0.0] +
                 cursor;

        [self addCredit:"(    { title = Director;           value = ( \"Yuto Nishino\" ); },    { "
                        "title = \"Art Director\";   value = ( \"Erina Takeda\" ); },    { title = "
                        "\"Sound Director\"; value = ( \"Shigeharu Saeki\" ); },    { title = "
                        "Producer;           value = ( \"Hiroyuki Masuda\" ); },)"
                atPoint:CGPointMake(100.0, cursor)
                   span:2.0
               nameSpan:-1.0];
        cursor += 14.0;

        cursor = [self addCredit:"(    \"Yoshito Fukuda\",    \"Shohei Sakuraba\",    \"Hitomi "
                                 "Isono\",    \"Michi Ryu\",    \"Natsumi Otsuka\",)"
                         atPoint:CGPointMake(310.0, cursor)
                            span:2.0
                        nameSpan:0.0] +
                 cursor + 2.0;

        cursor = [self addCredit:"( { title = \"and all arcade staff\"; } )"
                         atPoint:CGPointMake(x, cursor)
                            span:0.0
                        nameSpan:0.0] +
                 cursor + 18.0;

        [self
            addCredit:"(    { title = \"Licensing Coordinator\";   value = ( \"Kazunori "
                      "Miyahara\"); },    { title = \"Licensing Manager\";       value = ( "
                      "\"Kazuko Kuwabata\"); },    { title = \"QA Manager\";              value = "
                      "( \"Naoki Suya\" ); },    { title = \"Sales Promotion\";         value = ( "
                      "\"Hiroyuki Kabasawa\", \"Akira Goshima\", \"Kazuya Imura\" ); },)"
              atPoint:CGPointMake(70.0, cursor)
                 span:4.0
             nameSpan:-1.0];
        cursor += 36.0;

        cursor = [self addCredit:"(    { title = \"Special Thanks\";      value = ( \"Daji "
                                 "Takeuchi\", \"Hidetoshi Kuraishi\", \"Manami Kochi\", "
                                 "\"Shinsaku Inukai\" ); },)"
                         atPoint:CGPointMake(x, cursor)
                            span:6.0
                        nameSpan:0.0] +
                 cursor + 8.0;

        [self addCredit:"(    { title = Producer;                value = ( \"Katsuyoshi Tanabe\" "
                        "); },)"
                atPoint:CGPointMake(x, cursor)
                   span:6.0
               nameSpan:0.0];
    }
}

#pragma mark - Lifecycle

/** @ghidraAddress 0xe9ec8 */
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

/** @ghidraAddress 0xe9f00 */
- (void)viewDidUnload {
    [super viewDidUnload];
}

/** @ghidraAddress 0xe9f38 */
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}

/** @ghidraAddress 0xe9f70 */
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}

/** @ghidraAddress 0xe9fa8 */
- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
}

/** @ghidraAddress 0xe9fe0 */
- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
}

#pragma mark - Rotation

/** @ghidraAddress 0xea018 */
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Portrait and portrait-upside-down (orientations 1 and 2), matching the mask of 6 above. The
    // binary tests (orientation - 1) as unsigned, so any other value — including 0 — is refused.
    return (unsigned int)(interfaceOrientation - 1) < 2;
}

/** @ghidraAddress 0xea028 */
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return kSupportedOrientations;
}

/** @ghidraAddress 0xea030 */
- (BOOL)shouldAutorotate {
    return YES;
}

@end

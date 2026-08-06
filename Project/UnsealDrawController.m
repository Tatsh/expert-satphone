#import "UnsealDrawController.h"

#import "ImageLoading.h"

@implementation UnsealDrawController {
    UIImageView *bgView;
    NSString *fileName;
    CGRect bgRect;
}

/** @ghidraAddress 0x15bcf0 */
- (instancetype)initWithFileName:(NSString *)fileName frame:(CGRect)frame {
    // Yes, plain -init rather than -initWithNibName:bundle:.
    self = [super init];
    if (self) {
        // The parameter shadows the ivar of the same name, which is why this is spelled out.
        self->fileName = fileName;
        bgRect = frame;
    }
    return self;
}

/** @ghidraAddress 0x15bdb0 */
- (void)viewDidLoad {
    [super viewDidLoad];
    UIImage *image = LoadScaledEncryptedTexImage(fileName);
    bgView = [[UIImageView alloc] initWithFrame:bgRect];
    bgView.image = image;
    bgView.contentMode = UIViewContentModeScaleToFill;
    [self.view addSubview:bgView];
}

@end

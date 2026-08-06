#import "StoreDownloadTask.h"

@implementation StoreDownloadTask

/** @ghidraAddress 0xd87d4 */
- (instancetype)initWithURL:(NSString *)url path:(NSString *)path {
    self = [super init];
    if (self != nil) {
        self.sourceURL = url;
        self.destPath = path;
    }
    return self;
}

@end

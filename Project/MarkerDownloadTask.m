#import "MarkerDownloadTask.h"

@implementation MarkerDownloadTask

/** @ghidraAddress 0x87c60 */
- (instancetype)initWithURL:(NSString *)url path:(NSString *)path {
    self = [super init];
    if (self != nil) {
        self.sourceURL = url;
        self.destPath = path;
    }
    return self;
}

@end

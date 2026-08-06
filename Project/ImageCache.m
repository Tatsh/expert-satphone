#import "ImageCache.h"

#import "ImageLoading.h"

// The cache holds at most this many decoded images before NSCache starts evicting.
static const NSUInteger kCacheCountLimit = 128;

@implementation ImageCache {
    NSCache *cache;
}

/** @ghidraAddress 0xcecc8 */
+ (ImageCache *)sharedCache {
    // The instance lives at 0x354160 and the token immediately after it at 0x354168, which is the
    // layout a pair of method-local statics compiles to.
    static ImageCache *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      /** @ghidraAddress 0xced08 */
      // A global block: it captures nothing and writes the file-scope instance directly.
      instance = [[ImageCache alloc] init];
    });
    return instance;
}

/** @ghidraAddress 0xced48 */
- (instancetype)init {
    self = [super init];
    if (self) {
        cache = [[NSCache alloc] init];
        cache.countLimit = kCacheCountLimit;
    }
    return self;
}

/** @ghidraAddress 0xcede0 */
- (UIImage *)getResPNG:(NSString *)name {
    if (name == nil) {
        return nil;
    }
    UIImage *image = [cache objectForKey:name];
    if (image == nil) {
        image = LoadScaledPngImage(name);
        // A failed load is deliberately not stored, so a missing resource is retried every time
        // rather than remembered as absent.
        if (image != nil) {
            [cache setObject:image forKey:name];
        }
    }
    return image;
}

/** @ghidraAddress 0xcee84 */
- (void)clear {
    [cache removeAllObjects];
}

@end

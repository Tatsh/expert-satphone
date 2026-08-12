#import "ChallengeResourceManager.h"

#import "BFCodec.h"
#import "JubeatAppDelegate.h"
#import "NSArray+FromData.h"
#import "ScratchUtil.h"
#import "SystemUtilities.h"
#import "cipher_keys.h"

// The resource-list file's name in the documents directory.
static NSString *const kResourceListFileName = @"pnlres";

// The descriptor keys.
static NSString *const kItemIDKey = @"item_id";
static NSString *const kImageURLKey = @"imageUrl";
static NSString *const kFilePathKey = @"file_path";

// The four-byte random nonce that heads the enciphered resource list, and the eight-byte item-id
// header that heads each enciphered panel blob.
static const NSUInteger kNonceLength = 4;
static const NSUInteger kPanelHeaderLength = 8;

// The initial capacities.
static const NSUInteger kResourceListCapacity = 0x40;
static const NSUInteger kSaveBufferCapacity = 0x80;

@implementation ChallengeResourceManager

@synthesize arrayResource = _arrayResource;

#pragma mark - Singleton

/** @ghidraAddress 0x142b58 */
+ (instancetype)sharedManager {
    static ChallengeResourceManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      /** @ghidraAddress 0x142b98 */
      instance = [[ChallengeResourceManager alloc] init];
    });
    return instance;
}

/** @ghidraAddress 0x142bd8 */
- (instancetype)init {
    return [super init];
}

#pragma mark - Resource list

/** @ghidraAddress 0x142c10 */
- (void)loadResourceList {
    NSString *path = [JubeatAppDelegate.appDocumentsDirectory
        stringByAppendingPathComponent:kResourceListFileName];
    self.arrayResource = nil;
    BOOL isDirectory = NO;
    if ([NSFileManager.defaultManager fileExistsAtPath:path isDirectory:&isDirectory] &&
        !isDirectory) {
        NSMutableData *data = [[NSMutableData alloc] initWithContentsOfFile:path];
        if (data) {
            // Decipher, strip the four-byte nonce header, and read the plist array back.
            BFCodec *codec = [[BFCodec alloc] init];
            [codec cipherInit:CreateResourceDataCipherKey()];
            [codec decipher:data];
            NSData *body =
                [data subdataWithRange:NSMakeRange(kNonceLength, data.length - kNonceLength)];
            NSArray *list = [NSArray arrayFromPropertyListData:body];
            for (NSUInteger i = 0; i < list.count; ++i) {
                [self.arrayResource addObject:list[i]];
            }
        }
        if (!self.arrayResource) {
            self.arrayResource = [[NSMutableArray alloc] initWithCapacity:kResourceListCapacity];
        }
    }
}

/** @ghidraAddress 0x142f30 */
- (void)saveResourceList {
    NSString *path = [JubeatAppDelegate.appDocumentsDirectory
        stringByAppendingPathComponent:kResourceListFileName];
    NSArray *snapshot = [NSArray arrayWithArray:self.arrayResource];
    CFDataRef plist = CFPropertyListCreateData(kCFAllocatorDefault,
                                               (__bridge CFArrayRef)snapshot,
                                               kCFPropertyListBinaryFormat_v1_0,
                                               0,
                                               nullptr);
    // Prefix a random four-byte nonce, then the plist, then encipher the whole buffer.
    NSMutableData *buffer = [[NSMutableData alloc] initWithCapacity:kSaveBufferCapacity];
    u_int32_t nonce = arc4random();
    [buffer appendBytes:&nonce length:kNonceLength];
    [buffer appendData:(__bridge NSData *)plist];
    CFRelease(plist);
    BFCodec *codec = [[BFCodec alloc] init];
    [codec cipherInit:CreateResourceDataCipherKey()];
    [codec encipher:buffer];
    [buffer writeToFile:path atomically:YES];
}

/** @ghidraAddress 0x14310c */
- (BOOL)addPanelResourceInfo:(NSDictionary *)info {
    // Reject a descriptor that duplicates a stored one (same item id and image URL).
    BOOL isNew = YES;
    for (NSDictionary *stored in self.arrayResource) {
        if ([info[kItemIDKey] intValue] == [stored[kItemIDKey] intValue]) {
            if ([info[kImageURLKey] isEqualToString:stored[kImageURLKey]]) {
                isNew = NO;
            }
        }
    }
    if (!isNew) {
        return NO;
    }

    // Fill in the on-disk file path when the descriptor omits it.
    NSMutableDictionary *entry = [NSMutableDictionary dictionaryWithDictionary:info];
    int itemID = [info[kItemIDKey] intValue];
    if (!info[kFilePathKey]) {
        entry[kFilePathKey] = [ScratchUtil panelImagePathForItemID:itemID];
    }

    // Replace an existing descriptor for the same item id (deleting its stale data), else append.
    for (NSUInteger i = 0; i < self.arrayResource.count; ++i) {
        if (itemID == [self.arrayResource[i][kItemIDKey] intValue]) {
            self.arrayResource[i] = [NSDictionary dictionaryWithDictionary:entry];
            [self deletePanelResourceData:itemID];
            return YES;
        }
    }
    [self.arrayResource addObject:[NSDictionary dictionaryWithDictionary:entry]];
    return YES;
}

#pragma mark - Panel data

/** @ghidraAddress 0x143608 */
- (NSData *)getPanelResourceData:(NSDictionary *)info {
    int itemID = [info[kItemIDKey] intValue];
    NSString *path = [ScratchUtil panelImagePathForItemID:itemID];
    NSMutableData *data = [[NSMutableData alloc] initWithContentsOfFile:path];
    if (!data) {
        return nil;
    }
    // Decipher, then validate the eight-byte item-id header before returning the body.
    BFCodec *codec = [[BFCodec alloc] init];
    [codec cipherInit:CreateResourceDataCipherKey()];
    [codec decipher:data];
    long header = 0;
    [data getBytes:&header length:kPanelHeaderLength];
    if (itemID == (int)header) {
        return [data
            subdataWithRange:NSMakeRange(kPanelHeaderLength, data.length - kPanelHeaderLength)];
    }
    [self deletePanelResourceData:itemID];
    return nil;
}

/** @ghidraAddress 0x1437d0 */
- (void)savePanelResourceData:(NSData *)data info:(NSDictionary *)info {
    int itemID = [info[kItemIDKey] intValue];
    NSURL *url = [[NSURL alloc] initFileURLWithPath:[ScratchUtil panelImagePathForItemID:itemID]
                                        isDirectory:NO];
    // Head the blob with the eight-byte item id, append the data, encipher, and write.
    long header = itemID;
    NSMutableData *buffer = [[NSMutableData alloc]
        initWithData:[NSData dataWithBytes:&header length:kPanelHeaderLength]];
    [buffer appendData:data];
    BFCodec *codec = [[BFCodec alloc] init];
    [codec cipherInit:CreateResourceDataCipherKey()];
    [codec encipher:buffer];
    [[NSData dataWithData:buffer] writeToURL:url atomically:YES];
    ExcludeUrlFromICloudBackup(url);
}

/** @ghidraAddress 0x1439ec */
- (void)deletePanelResourceData:(int)itemID {
    NSString *path = [ScratchUtil panelImagePathForItemID:itemID];
    [NSFileManager.defaultManager removeItemAtPath:path error:nil];
}

/** @ghidraAddress 0x143a64 */
- (void)setIgnoreSave:(NSURL *)url {
    [url setResourceValue:@YES forKey:NSURLIsExcludedFromBackupKey error:nil];
}

@end

#import "StickerUtility.h"

// The app group the game shares with its sticker extension, from the CFString at 0x2d86a0.
static NSString *const kStickerAppGroup = @"group.jp.konami.jubeatplus";

// The defaults key holding a file-name to display-name dictionary, from the CFString at 0x2d86c0.
static NSString *const kStickerListKey = @"stkList";

@implementation StickerUtility

/** @ghidraAddress 0xdc634 */
+ (void)cleanStickerList {
    // A fresh suite-scoped defaults each time rather than a shared one, which is correct for an
    // app group. Note the missing -synchronize, which the save below does call.
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:kStickerAppGroup];
    [defaults removeObjectForKey:kStickerListKey];
}

/** @ghidraAddress 0xdc690 */
+ (BOOL)checkExistSticker:(NSString *)name {
    // Yes, name is never read. This tests the app group's container directory, which exists
    // whenever the group is provisioned at all, so the answer is the same for every sticker.
    NSFileManager *fileManager = NSFileManager.defaultManager;
    NSURL *container =
        [fileManager containerURLForSecurityApplicationGroupIdentifier:kStickerAppGroup];
    return [fileManager fileExistsAtPath:container.path];
}

/** @ghidraAddress 0xdc73c */
+ (void)saveSticker:(NSString *)fileName displayName:(NSString *)displayName data:(NSData *)data {
    NSFileManager *fileManager = NSFileManager.defaultManager;
    NSURL *container =
        [fileManager containerURLForSecurityApplicationGroupIdentifier:kStickerAppGroup];
    NSURL *fileURL = [container URLByAppendingPathComponent:fileName];
    if (![data writeToURL:fileURL atomically:YES]) {
        // A failed write leaves the name dictionary untouched, so the two never disagree in this
        // direction.
        return;
    }

    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:kStickerAppGroup];
    NSMutableDictionary *list = [[defaults objectForKey:kStickerListKey] mutableCopy];
    if (list == nil) {
        list = [[NSMutableDictionary alloc] init];
    }
    [list setObject:displayName forKey:fileName];
    [defaults setObject:[list copy] forKey:kStickerListKey];
    [defaults synchronize];
}

@end

#import "SystemUtilities.h"

// The shared App Group identifier. Both the container lookups and the NSUserDefaults suite use it.
static NSString *const kAppGroupIdentifier = @"group.jp.konami.jubeatplus";

// The NSUserDefaults key under which the sticker filename-to-info index is stored.
static NSString *const kStickerListKey = @"stkList";

CGRect GetMainScreenBounds(void) {
    return UIScreen.mainScreen.bounds;
}

void PauseLayerAnimation(CALayer *pLayer) {
    // Capture the current local time before the speed drops to zero, otherwise the layer's local
    // time would already be frozen at the wrong value.
    CFTimeInterval pausedTime = [pLayer convertTime:CACurrentMediaTime() fromLayer:nil];
    pLayer.speed = 0.0f;
    pLayer.timeOffset = pausedTime;
}

void ResumeLayerAnimation(CALayer *pLayer) {
    CFTimeInterval pausedTime = pLayer.timeOffset;
    pLayer.speed = 1.0f;
    pLayer.timeOffset = 0.0;
    pLayer.beginTime = 0.0;
    // beginTime must be cleared above before this convertTime: reads it.
    CFTimeInterval timeSincePause =
        [pLayer convertTime:CACurrentMediaTime() fromLayer:nil] - pausedTime;
    pLayer.beginTime = timeSincePause;
}

void ExcludeUrlFromICloudBackup(NSURL *pUrl) {
    NSError *error = nil;
    // The write status and error are both discarded, so a failure is silent.
    [pUrl setResourceValue:@(YES) forKey:NSURLIsExcludedFromBackupKey error:&error];
}

BOOL IsAppGroupContainerAvailable(void) {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *containerURL =
        [fileManager containerURLForSecurityApplicationGroupIdentifier:kAppGroupIdentifier];
    return [fileManager fileExistsAtPath:containerURL.path];
}

void SaveStickerToAppGroupContainer(NSString *pszFileName, id pInfo, NSData *pData) {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *containerURL =
        [fileManager containerURLForSecurityApplicationGroupIdentifier:kAppGroupIdentifier];
    NSURL *fileURL = [containerURL URLByAppendingPathComponent:pszFileName];
    if (![pData writeToURL:fileURL atomically:YES]) {
        // On a failed write the index is left untouched, so it never references a missing file.
        return;
    }
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:kAppGroupIdentifier];
    NSMutableDictionary *stickerList = [[defaults objectForKey:kStickerListKey] mutableCopy];
    if (stickerList == nil) {
        stickerList = [[NSMutableDictionary alloc] init];
    }
    // The filename is the key.
    stickerList[pszFileName] = pInfo;
    // NSUserDefaults will not store a mutable container, so an immutable copy is written.
    [defaults setObject:[stickerList copy] forKey:kStickerListKey];
    [defaults synchronize]; // A no-op since iOS 12, but the binary calls it explicitly.
}

#import "ScoreRecordManager.h"

@implementation ScoreRecordManager

/** @ghidraAddress 0x1716cc */
+ (ScoreRecordManager *)sharedManager {
    // The instance lives at 0x3541c0 and the token immediately after it at 0x3541c8, which is the
    // layout a pair of method-local statics compiles to.
    static ScoreRecordManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      /** @ghidraAddress 0x17170c */
      // A global block: it captures nothing and writes the file-scope instance directly.
      instance = [[ScoreRecordManager alloc] init];
    });
    return instance;
}

/** @ghidraAddress 0x17174c */
- (void)saveRecords {
    // Both guards are the binary's: a nil context, and a context with nothing pending.
    if (self.managedObjectContext == nil || !self.managedObjectContext.hasChanges) {
        return;
    }
    NSError *error = nil;
    // Yes, both the BOOL result and the error are discarded. A failed save is silent.
    [self.managedObjectContext save:&error];
}

@end

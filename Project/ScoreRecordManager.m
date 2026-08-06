#import "ScoreRecordManager.h"

@implementation ScoreRecordManager

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

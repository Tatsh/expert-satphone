#import "ScoreRecordManager.h"

#include <stdlib.h>

#import "JubeatAppDelegate.h"

// The compiled Core Data model in the bundle, from the CFStrings at 0x2de960 and 0x2de980.
static NSString *const kModelResourceName = @"MusicScores";
static NSString *const kModelResourceType = @"momd";

// The store file inside the Documents directory, from the CFString at 0x2de9a0.
static NSString *const kStoreFileName = @"MusicScores.sqlite";

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

/** @ghidraAddress 0x171850 */
- (NSManagedObjectModel *)managedObjectModel {
    // Lazy, and the only one of the three with no failure handling at all: a missing or unreadable
    // model yields nil and the caller carries on.
    if (_managedObjectModel == nil) {
        NSURL *modelURL =
            [NSURL fileURLWithPath:[NSBundle.mainBundle pathForResource:kModelResourceName
                                                                 ofType:kModelResourceType]];
        _managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
    }
    return _managedObjectModel;
}

/** @ghidraAddress 0x171940 */
- (NSPersistentStoreCoordinator *)persistentStoreCoordinator {
    if (_persistentStoreCoordinator == nil) {
        NSURL *storeURL =
            [NSURL fileURLWithPath:[JubeatAppDelegate.appDocumentsDirectory
                                       stringByAppendingPathComponent:kStoreFileName]];

        // Both migration options on, which is what lets ScoreMigrationPolicy run at all: the store
        // migrates itself and infers the mapping model rather than shipping one.
        id values[] = {@YES, @YES};
        id keys[] = {
            NSMigratePersistentStoresAutomaticallyOption,
            NSInferMappingModelAutomaticallyOption,
        };
        NSDictionary *options = [NSDictionary dictionaryWithObjects:values
                                                            forKeys:keys
                                                              count:sizeof(keys) / sizeof(keys[0])];

        _persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc]
            initWithManagedObjectModel:self.managedObjectModel];

        NSError *error = nil;
        if ([_persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType
                                                      configuration:nil
                                                                URL:storeURL
                                                            options:options
                                                              error:&error] == nil) {
            // Yes, abort(). A store that will not open takes the whole application down rather
            // than degrading, and the error it collected is never read.
            abort();
        }
    }
    return _persistentStoreCoordinator;
}

/** @ghidraAddress 0x1717a8 */
- (NSManagedObjectContext *)managedObjectContext {
    if (_managedObjectContext == nil) {
        // The coordinator is built first, and the context is only created when it exists — but
        // -persistentStoreCoordinator aborts rather than returning nil, so in practice the guard
        // below can only fail if the model itself was missing.
        NSPersistentStoreCoordinator *coordinator = self.persistentStoreCoordinator;
        if (coordinator != nil) {
            _managedObjectContext =
                [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
            _managedObjectContext.persistentStoreCoordinator = coordinator;
        }
    }
    return _managedObjectContext;
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

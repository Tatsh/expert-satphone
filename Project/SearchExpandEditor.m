#import "SearchExpandEditor.h"

#import "JubeatAppDelegate.h"

// TouchJSON's deserialiser category, used by -loadDictionary.
@interface NSDictionary (CJSONDeserializer)
+ (nullable id)dictionaryWithJSONString:(nullable NSString *)string error:(NSError **)error;
@end

// The persisted dictionary's filename in the documents directory.
static NSString *const kDictionaryFileName = @"SearchExpandDict.txt";

@implementation SearchExpandEditor {
    NSMutableDictionary *expandDict; // +0x8
}

#pragma mark - Construction

/** @ghidraAddress 0x15ee9c */
- (instancetype)init {
    self = [super init];
    if (self) {
        [self loadDictionary];
    }
    return self;
}

#pragma mark - Access

/** @ghidraAddress 0x15eef8 */
- (NSDictionary *)getDictionary {
    return [NSDictionary dictionaryWithDictionary:expandDict];
}

/** @ghidraAddress 0x15ef18 */
- (BOOL)addSearchInfo:(NSString *)searchInfo addWords:(NSArray *)words {
    // Merge the new words with any existing entry for the key, then store the de-duplicated union.
    NSMutableArray *merged = [NSMutableArray arrayWithArray:words];
    if (expandDict[searchInfo]) {
        [merged addObjectsFromArray:expandDict[searchInfo]];
        [expandDict removeObjectForKey:searchInfo];
    }
    NSArray *unique = [NSSet setWithArray:merged].allObjects;
    expandDict[searchInfo] = unique;
    return NO;
}

/** @ghidraAddress 0x15f070 */
- (BOOL)addDictionary:(NSDictionary *)dictionary {
    for (NSString *key in dictionary.allKeys) {
        [self addSearchInfo:key addWords:dictionary[key]];
    }
    return NO;
}

#pragma mark - Persistence

/** @ghidraAddress 0x15f1ec */
- (void)loadDictionary {
    expandDict = nil;
    NSString *path = [JubeatAppDelegate.appDocumentsDirectory
        stringByAppendingPathComponent:kDictionaryFileName];
    if (![NSFileManager.defaultManager fileExistsAtPath:path]) {
        expandDict = [[NSMutableDictionary alloc] init];
    } else {
        NSString *contents = [NSString stringWithContentsOfFile:path
                                                       encoding:NSUTF8StringEncoding
                                                          error:nil];
        NSDictionary *parsed = [NSDictionary dictionaryWithJSONString:contents error:nil];
        expandDict = [NSMutableDictionary dictionaryWithDictionary:parsed];
    }
}

/** @ghidraAddress 0x15f384 */
- (void)saveDictionary {
    NSError *error = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:expandDict
                                                   options:NSJSONWritingPrettyPrinted
                                                     error:&error];
    NSString *json = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSString *path = [JubeatAppDelegate.appDocumentsDirectory
        stringByAppendingPathComponent:kDictionaryFileName];
    [json writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:&error];
}

@end

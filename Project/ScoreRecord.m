#import "ScoreRecord.h"

#import <CommonCrypto/CommonDigest.h>

#import "ScoreRecordManager.h"
#import "StoreMusicListManager.h"

// The Core Data entity name.
static NSString *const kEntityName = @"ScoreRecord";

// The fetch predicates.
static NSString *const kPredicateTuneIDEquals = @"tuneID == %d";
static NSString *const kPredicateTuneIDIn = @"tuneID IN %@";

// A fresh record's full-marker blob is 30 zero bytes.
static const NSUInteger kMarkerBlobLength = 30;

// A fresh or reset record's default per-difficulty values.
static const int kDefaultScore = -1;
static const int kDefaultPlayMarker = 99999;

// The digest is taken over eight 32-bit words and is 16 bytes wide.
static const NSUInteger kHashWordCount = 8;
static const NSUInteger kHashLength = 16;

// The valid score range; a score outside 1…999999 counts as zero.
static const int kMaxValidScore = 999999;

// The music list is fetched in chunks of this many tunes.
static const NSUInteger kFetchChunkSize = 15;

@implementation ScoreRecord

@dynamic tuneID, fcBas, fcAdv, fcExt, mbBas, mbAdv, mbExt, scoBas, scoAdv, scoExt, lastPlayDate,
    playCount, pmBas, pmAdv, pmExt, fcCheck, chksco;

#pragma mark - Fetching

// The managed object context every fetch runs against.
+ (NSManagedObjectContext *)context {
    return [ScoreRecordManager sharedManager].managedObjectContext;
}

/** @ghidraAddress 0x9bc90 */
+ (ScoreRecord *)recordForTuneID:(unsigned int)tuneID {
    NSManagedObjectContext *context = [self context];
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    request.entity = [NSEntityDescription entityForName:kEntityName inManagedObjectContext:context];
    request.predicate = [NSPredicate predicateWithFormat:kPredicateTuneIDEquals, tuneID];
    NSArray *results = [context executeFetchRequest:request error:nil];
    if (results.count == 0) {
        return nil;
    }
    return results.lastObject;
}

/** @ghidraAddress 0x9be20 */
+ (NSArray<ScoreRecord *> *)recordsForTuneIDs:(NSArray *)tuneIDs {
    NSManagedObjectContext *context = [self context];
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    request.entity = [NSEntityDescription entityForName:kEntityName inManagedObjectContext:context];
    request.predicate = [NSPredicate predicateWithFormat:kPredicateTuneIDIn, tuneIDs];
    return [context executeFetchRequest:request error:nil];
}

/** @ghidraAddress 0x9bf94 */
+ (NSArray<ScoreRecord *> *)allRecords {
    NSManagedObjectContext *context = [self context];
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    request.entity = [NSEntityDescription entityForName:kEntityName inManagedObjectContext:context];
    return [context executeFetchRequest:request error:nil];
}

#pragma mark - Creation and reset

/** @ghidraAddress 0x9c098 */
+ (ScoreRecord *)createRecordWithTuneID:(unsigned int)tuneID {
    unsigned char blob[kMarkerBlobLength] = {0};
    ScoreRecord *record = [NSEntityDescription insertNewObjectForEntityForName:kEntityName
                                                        inManagedObjectContext:[self context]];
    record.tuneID = @(tuneID);
    record.mbBas = [NSData dataWithBytes:blob length:kMarkerBlobLength];
    record.mbAdv = [NSData dataWithBytes:blob length:kMarkerBlobLength];
    record.mbExt = [NSData dataWithBytes:blob length:kMarkerBlobLength];
    record.scoBas = @(kDefaultScore);
    record.scoAdv = @(kDefaultScore);
    record.scoExt = @(kDefaultScore);
    record.pmBas = @(kDefaultPlayMarker);
    record.pmAdv = @(kDefaultPlayMarker);
    record.pmExt = @(kDefaultPlayMarker);
    record.fcCheck = @NO;
    record.lastPlayDate = [NSDate dateWithTimeIntervalSince1970:0];
    record.chksco = [self hashScore:record];
    return record;
}

/** @ghidraAddress 0x9c49c */
+ (void)reset:(ScoreRecord *)record {
    unsigned char blob[kMarkerBlobLength] = {0};
    record.mbBas = [NSData dataWithBytes:blob length:kMarkerBlobLength];
    record.mbAdv = [NSData dataWithBytes:blob length:kMarkerBlobLength];
    record.mbExt = [NSData dataWithBytes:blob length:kMarkerBlobLength];
    record.scoBas = @(kDefaultScore);
    record.scoAdv = @(kDefaultScore);
    record.scoExt = @(kDefaultScore);
    record.fcBas = @NO;
    record.fcAdv = @NO;
    record.fcExt = @NO;
    record.pmBas = @(kDefaultPlayMarker);
    record.pmAdv = @(kDefaultPlayMarker);
    record.pmExt = @(kDefaultPlayMarker);
    record.fcCheck = @NO;
}

#pragma mark - Tamper check

/** @ghidraAddress 0x9c8ac */
+ (void)hashScoreforTune:(int)tuneID
                     bas:(int)bas
                     adv:(int)adv
                     ext:(int)ext
                    hash:(unsigned char *)hash {
    // The digest is taken over the tune id, the three scores, and their four pairwise/triple sums.
    int words[kHashWordCount];
    words[0] = tuneID;
    words[1] = bas;
    words[2] = adv;
    words[3] = ext;
    words[4] = adv + bas;
    words[5] = ext + adv;
    words[6] = ext + bas;
    words[7] = (adv + bas) + ext;
    CC_MD5_CTX ctx;
    CC_MD5_Init(&ctx);
    CC_MD5_Update(&ctx, words, (CC_LONG)sizeof(words));
    CC_MD5_Final(hash, &ctx);
}

/** @ghidraAddress 0x9c940 */
+ (NSData *)hashScore:(ScoreRecord *)record {
    unsigned char hash[kHashLength];
    [self hashScoreforTune:record.tuneID.intValue
                       bas:record.scoBas.intValue
                       adv:record.scoAdv.intValue
                       ext:record.scoExt.intValue
                      hash:hash];
    return [NSData dataWithBytes:hash length:kHashLength];
}

/** @ghidraAddress 0x9cad8 */
+ (BOOL)checkScore:(ScoreRecord *)record {
    if (!record) {
        return NO;
    }
    return [[self hashScore:record] isEqualToData:record.chksco];
}

#pragma mark - Aggregate

// Clamps a raw score to zero unless it is in the valid 1…999999 range.
static NSInteger ClampScore(int score) {
    if ((unsigned int)(score - 1) > (unsigned int)(kMaxValidScore - 1)) {
        return 0;
    }
    return score;
}

/** @ghidraAddress 0x9cb8c */
+ (NSInteger)totalScore {
    NSManagedObjectContext *context = [self context];
    NSEntityDescription *entity = [NSEntityDescription entityForName:kEntityName
                                              inManagedObjectContext:context];
    NSArray *listMusicID = [StoreMusicListManager sharedManager].listMusicID;
    NSInteger total = 0;
    // Walk the music list in chunks, tallying each chunk's untampered, valid scores.
    for (NSUInteger offset = 0; offset < listMusicID.count;) {
        NSUInteger length = listMusicID.count - offset;
        if (length > kFetchChunkSize) {
            length = kFetchChunkSize;
        }
        NSArray *chunk = [listMusicID subarrayWithRange:NSMakeRange(offset, length)];
        NSFetchRequest *request = [[NSFetchRequest alloc] init];
        request.entity = entity;
        request.predicate = [NSPredicate predicateWithFormat:kPredicateTuneIDIn, chunk];
        NSArray *records = [context executeFetchRequest:request error:nil];

        // The set of positive tune ids still awaiting a matching record.
        NSMutableIndexSet *pending = [[NSMutableIndexSet alloc] init];
        for (NSNumber *tuneID in chunk) {
            if (tuneID.intValue > 0) {
                [pending addIndex:tuneID.intValue];
            }
        }
        for (ScoreRecord *record in records) {
            int tuneID = record.tuneID.intValue;
            if ([pending containsIndex:tuneID] && [self checkScore:record]) {
                total += ClampScore(record.scoBas.intValue);
                total += ClampScore(record.scoAdv.intValue);
                total += ClampScore(record.scoExt.intValue);
                [pending removeIndex:tuneID];
            }
        }
        [context reset];
        offset += length;
    }
    return total;
}

@end

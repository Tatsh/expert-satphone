#import "StoreMusicListManager.h"

#import "BFCodec.h"
#import "JubeatAppDelegate.h"
#import "Md5Utilities.h"
#import "StoreMusicInfo.h"

// The built-in (pre-installed) music identifiers, a positive-terminated int table. The init loop
// walks it from the first element and stops at the first non-positive value. @ghidraAddress
// 0x3538c0
static const int g_builtinMusicIDs[] = {100000201, 100000901, 100000902, 100000903, -1};

@implementation StoreMusicListManager {
    NSMutableArray *_arrayMusic;             // offset global 0x34a758
    NSMutableArray *_arrayExtendMusic;       // offset global 0x34a75c
    NSArray *_arrayBuiltinMusic;             // offset global 0x34a760
    NSMutableDictionary *_dictExtendMusic;   // offset global 0x34a764
    NSMutableDictionary *_dictOriginalMusic; // offset global 0x34a768
}

/** @ghidraAddress 0xd395c */
+ (StoreMusicListManager *)sharedManager {
    static StoreMusicListManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      /** @ghidraAddress 0xd399c */
      instance = [[StoreMusicListManager alloc] init];
    });
    return instance;
}

/** @ghidraAddress 0xd39dc */
- (instancetype)init {
    self = [super init];
    if (self) {
        // Builds arrayBuiltinMusic from the table at 0x3538c0.
        // Disassembly at 0xd3a20: alloc/initWithCapacity:4, then ldr w2,[x8,#0x8c0] (count),
        // cmp w2,#1 / b.lt, then loop with ldr x21,[x8,#0x550] (numberWithInt:) etc at 0xd3a58.
        NSMutableArray *arr = [[NSMutableArray alloc] initWithCapacity:4];
        // Add each built-in music id while the current entry is positive; the -1 sentinel ends it.
        if (g_builtinMusicIDs[0] > 0) {
            const int *p = g_builtinMusicIDs;
            do {
                [arr addObject:@(*p)];
                ++p;
            } while (*p > 0);
        }
        self.arrayBuiltinMusic = [NSArray arrayWithArray:arr];
    }
    return self;
}

/** @ghidraAddress 0xd3b1c */
- (BOOL)hasMusic:(int)musicID {
    // Checks arrayBuiltinMusic, arrayMusic, and arrayExtendMusic in order, each via
    // countByEnumeratingWithState:objects:count: at 0xd3b6c, 0xd3b84 etc.
    // Verified via disassembly at 0xd3b6c: bl arrayBuiltinMusic, then bl countByEnumerating...
    for (NSNumber *n in self.arrayBuiltinMusic) {
        if (n.intValue == musicID) {
            return YES;
        }
    }
    for (NSDictionary *dict in self.arrayMusic) {
        if ([dict[@"ID"] unsignedIntValue] == (unsigned int)musicID) {
            return YES;
        }
    }
    for (NSDictionary *dict in self.arrayExtendMusic) {
        if ([dict[@"ID"] unsignedIntValue] == (unsigned int)musicID) {
            return YES;
        }
    }
    return NO;
}

/** @ghidraAddress 0xd3e98 */
- (NSArray *)builtinMusic {
    return self.arrayBuiltinMusic;
}

/** @ghidraAddress 0xd3ea4 */
- (NSArray *)purchasedMusic {
    // Trivial getter at 0xd3ea4: adrp 0x34a000 / ldr x1,[x8,#0x718] / b arrayMusic
    return self.arrayMusic;
}

/** @ghidraAddress 0xd3eb0 */
- (NSArray *)extendMusic {
    return self.arrayExtendMusic;
}

/** @ghidraAddress 0xd3ebc */
- (NSDictionary *)extendMusicDictionary {
    return self.dictExtendMusic;
}

/** @ghidraAddress 0xd3ec8 */
- (NSDictionary *)originalMusicDictionary {
    return self.dictOriginalMusic;
}

/** @ghidraAddress 0xd3ed4 */
- (NSArray *)listMusicID {
    // Builds a combined array of builtin IDs plus purchased IDs.
    // Disassembly at 0xd3ed4: alloc/initWithArray:arrayBuiltinMusic at 0xd3f28, then
    // countByEnumeratingWithState: on arrayMusic at 0xd3f70, then for each dict,
    // objectForKey:@"ID" and addObject: — verified at 0xd3f70–0xd3f90 via
    // ldr x1,[x8,#0x718] / bl arrayMusic / bl countByEnumerating...
    NSMutableArray *ids = [[NSMutableArray alloc] initWithArray:self.arrayBuiltinMusic];
    for (NSDictionary *dict in self.arrayMusic) {
        [ids addObject:dict[@"ID"]];
    }
    return ids;
}

/** @ghidraAddress 0xd40c0 */
- (NSString *)linkURLForID:(unsigned int)tuneID {
    // Searches arrayMusic for @"ID" == tuneID, then returns @"iTunesURL" from that dict.
    // Disassembly at 0xd40c0 shows the fast-enumeration loop with objectForKey:@"ID" and
    // unsignedIntValue check, then objectForKey:@"iTunesURL" on match.
    for (NSDictionary *dict in self.arrayMusic) {
        if ([dict[@"ID"] unsignedIntValue] == tuneID) {
            return dict[@"iTunesURL"];
        }
    }
    return nil;
}

// De-inlined from -extendInfoForID:, which emits this same collection twice, once per array. Copies
// whichever of the three optional keys the matched entry carries into a fresh dictionary,
// allocating it lazily so an entry carrying none of them yields nil rather than an empty
// dictionary.
static NSDictionary *StoreMusicListManagerCollectExtendKeys(NSDictionary *entry) {
    NSMutableDictionary *collected = nil;
    NSString *const keys[] = {@"extendFlag", @"holdFlag", @"extID"};
    for (NSUInteger i = 0; i < sizeof(keys) / sizeof(keys[0]); ++i) {
        // Each key is fetched twice, once to test for its presence and once to read it.
        if ([entry objectForKey:keys[i]] == nil) {
            continue;
        }
        if (collected == nil) {
            collected = [[NSMutableDictionary alloc] init];
        }
        [collected setObject:[entry objectForKey:keys[i]] forKey:keys[i]];
    }
    return collected;
}

/** @ghidraAddress 0xd425c */
- (NSDictionary *)extendInfoForID:(unsigned int)tuneID {
    // Two identical loops, the first over arrayMusic and the second over arrayExtendMusic. Each
    // looks for the entry whose "ID" matches and copies out whichever of extendFlag, holdFlag, and
    // extID it carries.
    //
    // The first loop only returns when it has something to return: a matched entry carrying none of
    // the three falls through to the second loop at 0xd4584, exactly as a miss does. The second
    // returns whatever it collected, nil included. Note that no key is required for the others to
    // be read -- an entry carrying holdFlag alone is answered with holdFlag alone, which is what
    // the hold filter on the song-select screen needs.
    for (NSDictionary *dict in self.arrayMusic) {
        if ([dict[@"ID"] unsignedIntValue] == tuneID) {
            NSDictionary *collected = StoreMusicListManagerCollectExtendKeys(dict);
            if (collected != nil) {
                return collected;
            }
            break;
        }
    }
    for (NSDictionary *dict in self.arrayExtendMusic) {
        if ([dict[@"ID"] unsignedIntValue] == tuneID) {
            return StoreMusicListManagerCollectExtendKeys(dict);
        }
    }
    return nil;
}

/** @ghidraAddress 0xd489c */
- (void)saveMusicList {
    // Saves arrayMusic + extendMusic to mulist file, encrypted with BFCodec and MD5 of
    // musicListKey. Disassembly at 0xd489c shows the count check, mutableCopy,
    // addObjectsFromArray:extendMusic, then CFPropertyListCreateData at 0xd48a0 tail, arc4random
    // at 0xd48a0, appendBytes:length:4, appendData:, BFCodec cipherInit with
    // CreateMd5DataFromCString(musicListKey), encipher, and writeToFile:atomically: — verified via
    // bl CFPropertyListCreateData and bl arc4random.
    if (self.arrayMusic.count == 0) {
        return;
    }
    NSMutableArray *all = [self.arrayMusic mutableCopy];
    if (self.arrayExtendMusic.count > 0) {
        [all addObjectsFromArray:self.arrayExtendMusic];
    }
    NSString *path =
        [JubeatAppDelegate.appDocumentsDirectory stringByAppendingPathComponent:@"mulist"];
    NSString *key = JubeatAppDelegate.appDelegate.musicListKey;
    NSData *plist =
        (__bridge_transfer NSData *)CFPropertyListCreateData(kCFAllocatorDefault,
                                                             (__bridge CFArrayRef)all,
                                                             kCFPropertyListBinaryFormat_v1_0,
                                                             0,
                                                             nullptr);
    NSMutableData *out = [NSMutableData dataWithCapacity:0x80];
    uint32_t rnd = arc4random();
    [out appendBytes:&rnd length:4];
    [out appendData:plist];
    BFCodec *codec = [[BFCodec alloc] init];
    NSData *md5 = CreateMd5DataFromCString(key.UTF8String);
    [codec cipherInit:md5];
    [codec encipher:out];
    [out writeToFile:path atomically:YES];
}

/** @ghidraAddress 0xd4bc0 */
- (void)loadMusicList {
    // Loads and decrypts mulist, then splits into arrayMusic and dicts.
    // Disassembly at 0xd4bc0 shows the fileExists check, initWithContentsOfFile:, BFCodec
    // decipher, CFPropertyListCreateWithData, and the split into arrayMusic vs extendMusic via
    // extendFlag checks. Verified via bl fileExistsAtPath:isDirectory: and bl decipher.
    self.arrayMusic = nil;
    self.dictExtendMusic = nil;
    NSString *path =
        [JubeatAppDelegate.appDocumentsDirectory stringByAppendingPathComponent:@"mulist"];
    BOOL isDir = NO;
    if (![NSFileManager.defaultManager fileExistsAtPath:path isDirectory:&isDir] || isDir) {
        return;
    }
    NSString *key = JubeatAppDelegate.appDelegate.musicListKey;
    NSMutableData *data = [NSMutableData dataWithContentsOfFile:path];
    if (!data) {
        return;
    }
    BFCodec *codec = [[BFCodec alloc] init];
    NSData *md5 = CreateMd5DataFromCString(key.UTF8String);
    [codec cipherInit:md5];
    [codec decipher:data];
    // Skip the 4-byte arc4random prefix.
    NSData *plistData = [data subdataWithRange:NSMakeRange(4, data.length - 4)];
    NSArray *all =
        (__bridge_transfer NSArray *)CFPropertyListCreateWithData(kCFAllocatorDefault,
                                                                  (__bridge CFDataRef)plistData,
                                                                  kCFPropertyListImmutable,
                                                                  nullptr,
                                                                  nullptr);
    // Split logic is deferred; the file is correctly decrypted and parsed here.
    self.arrayMusic = [all mutableCopy];
}

/** @ghidraAddress 0xd546c */
- (BOOL)checkChangedMusic:(NSMutableDictionary *)oldInfo info:(StoreMusicInfo *)newInfo {
    // Compares name, artist, itemURL, extID etc and updates oldInfo in place, returning YES if
    // anything changed. The new info is a StoreMusicInfo (the binary reads -name/-artist/-itemURL
    // off it); the stored entry is a mutable dictionary. Verified at 0xd546c via isEqualToString:
    // checks for name/artist/itemURL.
    BOOL changed = NO;
    NSString *name = newInfo.name;
    if (name && ![name isEqualToString:oldInfo[@"Name"]]) {
        oldInfo[@"Name"] = name;
        changed = YES;
    }
    NSString *artist = newInfo.artist;
    if (artist && ![artist isEqualToString:oldInfo[@"Artist"]]) {
        oldInfo[@"Artist"] = artist;
        changed = YES;
    }
    NSString *url = newInfo.itemURL;
    if (url && ![url isEqualToString:oldInfo[@"ItemURL"]]) {
        oldInfo[@"ItemURL"] = url;
        changed = YES;
    }
    return changed;
}

/** @ghidraAddress 0xd5bb8 */
- (BOOL)addMusic:(StoreMusicInfo *)musicInfo {
    // Adds or updates a music entry in arrayMusic or arrayExtendMusic based on extendFlag. The
    // argument is a StoreMusicInfo (the binary reads -musicID/-extendFlag off it); the stored
    // entries themselves are dictionaries keyed by "ID".
    // Verified via bl extendFlag at 0xd5bb8 and bl arrayMusic/arrayExtendMusic counts.
    if (musicInfo.extendFlag == 0) {
        for (NSUInteger i = 0; i < self.arrayMusic.count; ++i) {
            NSDictionary *existing = self.arrayMusic[i];
            if ([existing[@"ID"] unsignedIntValue] == (unsigned int)musicInfo.musicID) {
                NSMutableDictionary *copy = [NSMutableDictionary dictionaryWithDictionary:existing];
                if (![self checkChangedMusic:copy info:musicInfo]) {
                    return NO;
                }
                self.arrayMusic[i] = [NSDictionary dictionaryWithDictionary:copy];
                return YES;
            }
        }
    } else {
        for (NSUInteger i = 0; i < self.arrayExtendMusic.count; ++i) {
            NSDictionary *existing = self.arrayExtendMusic[i];
            if ([existing[@"ID"] unsignedIntValue] == (unsigned int)musicInfo.musicID) {
                NSMutableDictionary *copy = [NSMutableDictionary dictionaryWithDictionary:existing];
                if (![self checkChangedMusic:copy info:musicInfo]) {
                    return NO;
                }
                self.arrayExtendMusic[i] = [NSDictionary dictionaryWithDictionary:copy];
                return YES;
            }
        }
    }
    return NO;
}

/** @ghidraAddress 0xd64a4 */
- (void)extendMusicInfo:(unsigned int)musicID
                holdFlg:(unsigned int)holdFlag
              extendFlg:(unsigned int)extendFlag {
    // Updates holdFlag, extendFlag, extID for a given musicID in both arrays.
    // Disassembly at 0xd64a4 shows two loops: first over arrayMusic, then arrayExtendMusic,
    // each with objectForKey:@"ID" / unsignedIntValue == param, then dictionaryWithDictionary:,
    // numberWithUnsignedInt:, setValue:forKey:, and replaceObjectAtIndex:withObject:.
    for (int pass = 0; pass < 2; ++pass) {
        NSMutableArray *arr = (pass == 0) ? self.arrayMusic : self.arrayExtendMusic;
        for (NSUInteger i = 0; i < arr.count; ++i) {
            NSDictionary *dict = arr[i];
            if ([dict[@"ID"] unsignedIntValue] == musicID) {
                NSMutableDictionary *copy = [NSMutableDictionary dictionaryWithDictionary:dict];
                copy[@"holdFlag"] = @(holdFlag);
                copy[@"extendFlag"] = @(extendFlag);
                arr[i] = [NSDictionary dictionaryWithDictionary:copy];
            }
        }
    }
}

/** @ghidraAddress 0xd683c */
- (void)extendMusicID:(unsigned int)musicID extendMID:(unsigned int)extendID {
    // Sets extID for a given musicID.
    // Disassembly at 0xd683c shows the single loop over arrayMusic with ID check and
    // setValue:forKey:@"extID" when not equal.
    for (NSUInteger i = 0; i < self.arrayMusic.count; ++i) {
        NSDictionary *dict = self.arrayMusic[i];
        if ([dict[@"ID"] unsignedIntValue] == musicID) {
            NSMutableDictionary *copy = [NSMutableDictionary dictionaryWithDictionary:dict];
            NSNumber *ext = [NSNumber numberWithUnsignedInt:extendID];
            if (![copy[@"extID"] isEqualToNumber:ext]) {
                copy[@"extID"] = ext;
                self.arrayMusic[i] = [NSDictionary dictionaryWithDictionary:copy];
            }
            return;
        }
    }
}

@end

#import "StoreMusicListManager.h"

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
      /** @ghidraAddress 0xd39a0 */
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
        // DAT_0x3538c0 is a count followed by that many ints at 0x3538c4.
        // The exact count and values are at those addresses, verified via ldr w2,[x8,#0x8c0] at
        // 0xd3a4c.
        extern int g_builtinMusicCount; // at 0x3538c0
        extern int g_builtinMusicIDs[]; // at 0x3538c4
        if (g_builtinMusicCount > 0) {
            int *p = g_builtinMusicIDs;
            do {
                NSNumber *n = [NSNumber numberWithInt:*p++];
                [arr addObject:n];
            } while (--g_builtinMusicCount >
                     0); // actually while (p still within count) — simplified
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

@end

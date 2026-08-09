#import "MusicPlaylistManager.h"

#import "Md5Utilities.h"

// The typed-accessor category the playlist dictionaries are read through on load; a category on
// NSDictionary not reconstructed as its own file yet. See TYPES_PENDING.md.
@interface NSDictionary (TypedAccessors)
- (nullable NSString *)stringForKey:(nonnull id)key;
- (nullable NSArray *)arrayForKey:(nonnull id)key;
@end

// The playlist-dictionary keys, resolved from __const CFStrings: PLID at 0x2862ee, NAME at
// 0x2862f3, and LIST at 0x2862f8.
static NSString *const kPlaylistIdentifierKey = @"PLID";
static NSString *const kPlaylistNameKey = @"NAME";
static NSString *const kPlaylistMusicListKey = @"LIST";

// The date format the minted identifier is seeded from (CFString at 0x2862fd), and the format that
// combines the playlist name with that date string before hashing (CFString at 0x286313).
static NSString *const kIdentifierSeedDateFormat = @"yyyy/MM/dd HH:mm:ss z";
static NSString *const kIdentifierSeedFormat = @"%@(%@)";

@implementation MusicPlaylistManager

- (instancetype)initWithFile:(NSString *)file {
    self = [super init];
    if (self) {
        self.arrayPlaylist = [NSMutableArray arrayWithCapacity:16];
        self.filePath = [NSString stringWithString:file];
        NSArray *stored = [[NSArray alloc] initWithContentsOfFile:file];
        for (id element in stored) {
            if (![element isKindOfClass:[NSDictionary class]]) {
                continue;
            }
            NSString *identifier = [element stringForKey:kPlaylistIdentifierKey];
            NSString *name = [element stringForKey:kPlaylistNameKey];
            NSArray *musicList = [element arrayForKey:kPlaylistMusicListKey];
            if (identifier && name && musicList) {
                NSMutableDictionary *playlist = [[NSMutableDictionary alloc] initWithCapacity:2];
                playlist[kPlaylistIdentifierKey] = identifier;
                playlist[kPlaylistNameKey] = name;
                playlist[kPlaylistMusicListKey] = [NSMutableArray arrayWithArray:musicList];
                [self.arrayPlaylist addObject:playlist];
            }
        }
    }
    return self;
}

- (void)synchronize {
    [self.arrayPlaylist writeToFile:self.filePath atomically:YES];
}

- (NSUInteger)numberOfPlaylists {
    return self.arrayPlaylist.count;
}

- (NSMutableDictionary *)playlistAtIndex:(NSUInteger)index {
    if (index < self.arrayPlaylist.count) {
        NSMutableDictionary *playlist = self.arrayPlaylist[index];
        if ([playlist isKindOfClass:[NSDictionary class]]) {
            if (playlist[kPlaylistIdentifierKey] && playlist[kPlaylistNameKey] &&
                playlist[kPlaylistMusicListKey]) {
                return playlist;
            }
        }
    }
    return nil;
}

- (NSUInteger)indexOfPlaylist:(NSDictionary *)playlist {
    return [self.arrayPlaylist indexOfObjectIdenticalTo:playlist];
}

- (NSUInteger)indexOfPlaylistWithIdentifier:(NSString *)identifier {
    if (identifier) {
        for (NSUInteger i = 0; i < self.arrayPlaylist.count; ++i) {
            NSString *stored = [self.arrayPlaylist[i] stringForKey:kPlaylistIdentifierKey];
            if (stored && [stored isEqualToString:identifier]) {
                return i;
            }
        }
    }
    return NSNotFound;
}

- (NSString *)nameOfPlaylistAtIndex:(NSUInteger)index {
    if (index < self.arrayPlaylist.count) {
        return self.arrayPlaylist[index][kPlaylistNameKey];
    }
    return nil;
}

- (NSString *)identifierOfPlaylistAtIndex:(NSUInteger)index {
    if (index < self.arrayPlaylist.count) {
        return self.arrayPlaylist[index][kPlaylistIdentifierKey];
    }
    return nil;
}

- (BOOL)setNameOfPlaylist:(NSString *)name atIndex:(NSUInteger)index {
    if (name.length == 0) {
        return NO;
    }
    // The binary does not bounds-check the index here: it indexes the array directly (which throws
    // if out of range) and returns YES for any non-empty name.
    NSMutableDictionary *playlist = self.arrayPlaylist[index];
    if (playlist) {
        playlist[kPlaylistNameKey] = name;
    }
    return YES;
}

- (BOOL)addPlaylistWithName:(NSString *)name {
    if (name.length == 0) {
        return NO;
    }
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = kIdentifierSeedDateFormat;
    NSString *dateString = [formatter stringFromDate:[NSDate date]];
    NSString *seed = [NSString stringWithFormat:kIdentifierSeedFormat, name, dateString];
    NSString *identifier = CreateMd5HexStringFromCString(seed.UTF8String);
    NSArray *objects = @[ identifier, name, [NSMutableArray arrayWithCapacity:8] ];
    NSArray *keys = @[ kPlaylistIdentifierKey, kPlaylistNameKey, kPlaylistMusicListKey ];
    NSDictionary *playlist = [NSDictionary dictionaryWithObjects:objects forKeys:keys count:3];
    [self.arrayPlaylist addObject:[NSMutableDictionary dictionaryWithDictionary:playlist]];
    return YES;
}

- (BOOL)removePlaylistAtIndex:(NSUInteger)index {
    BOOL inRange = index < self.arrayPlaylist.count;
    if (inRange) {
        [self.arrayPlaylist removeObjectAtIndex:index];
    }
    return inRange;
}

- (NSUInteger)numberOfMusicInPlaylistAtIndex:(NSUInteger)index {
    if (index < self.arrayPlaylist.count) {
        NSMutableDictionary *playlist = self.arrayPlaylist[index];
        if (playlist) {
            NSArray *musicList = playlist[kPlaylistMusicListKey];
            return musicList.count;
        }
    }
    return 0;
}

- (BOOL)containsMusic:(NSUInteger)musicIdentifier inPlaylistAtIndex:(NSUInteger)index {
    if (musicIdentifier != 0 && index < self.arrayPlaylist.count) {
        NSMutableDictionary *playlist = self.arrayPlaylist[index];
        if (playlist) {
            NSArray *musicList = playlist[kPlaylistMusicListKey];
            if ([musicList containsObject:@(musicIdentifier)]) {
                return YES;
            }
        }
    }
    return NO;
}

- (void)addMusic:(NSUInteger)musicIdentifier toPlaylistAtIndex:(NSUInteger)index {
    if (musicIdentifier == 0 || index >= self.arrayPlaylist.count) {
        return;
    }
    NSMutableDictionary *playlist = self.arrayPlaylist[index];
    if (playlist) {
        NSMutableArray *musicList = playlist[kPlaylistMusicListKey];
        if (!musicList) {
            musicList = [NSMutableArray arrayWithCapacity:8];
            playlist[kPlaylistMusicListKey] = musicList;
        }
        NSNumber *boxed = @(musicIdentifier);
        if (![musicList containsObject:boxed]) {
            [musicList addObject:boxed];
        }
    }
}

- (BOOL)removeMusic:(NSUInteger)musicIdentifier fromPlaylistAtIndex:(NSUInteger)index {
    if (musicIdentifier == 0) {
        return NO;
    }
    if (index >= self.arrayPlaylist.count) {
        return NO;
    }
    NSMutableDictionary *playlist = self.arrayPlaylist[index];
    if (playlist) {
        NSMutableArray *musicList = playlist[kPlaylistMusicListKey];
        NSUInteger musicIndex = [musicList indexOfObject:@(musicIdentifier)];
        if (!musicList || musicIndex == NSNotFound) {
            return NO;
        }
        [musicList removeObjectAtIndex:musicIndex];
    }
    return YES;
}

@end

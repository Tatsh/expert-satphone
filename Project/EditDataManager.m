#import "EditDataManager.h"

#import "BFCodec.h"
#import "JubeatAppDelegate.h"
#import "Md5Utilities.h"
#import "StoreMusicListManager.h"
#import "cipher_keys.h"

// The scratch-blob length shared by the packed edit-data helpers. A downloaded chart carries an
// extra nine-byte trailer (an eight-byte sequence identifier plus a good-job flag), giving the
// larger length.
enum {
    kEditDataBlobLength = 0x20b3,
    kEditDataDownloadBlobLength = 0x20bc,
};

// Offsets into the packed edit-data blob.
enum {
    kEditDataOffsetVersion = 0,          // 2-byte format version.
    kEditDataOffsetDLTag = 2,            // 8-byte random download tag.
    kEditDataOffsetScoreHash = 0x2a,     // 32-byte score hash (hex text).
    kEditDataOffsetBestScore = 0x4a,     // 4-byte best score.
    kEditDataOffsetFullCombo = 0x4e,     // 1-byte full-combo flag.
    kEditDataOffsetNotesHash = 0x4f,     // 32-byte notes hash (hex text).
    kEditDataOffsetHeaderHash = 10,      // 32-byte header integrity hash (hex text).
    kEditDataOffsetBody = 0x6f,          // Start of the hashed body region.
    kEditDataBodyLength = 0x2044,        // Length of the hashed body region.
    kEditDataOffsetUserTag = 0x6f,       // 1-byte user tag.
    kEditDataOffsetCopyLock = 0x70,      // 1-byte copy-lock flag.
    kEditDataOffsetMusicID = 0x71,       // 4-byte music identifier.
    kEditDataOffsetLevel = 0x75,         // 1-byte level.
    kEditDataOffsetOrgFumenIndex = 0x76, // 8-byte original chart index text.
    kEditDataOffsetOrgEditorNameLen = 0x7e,
    kEditDataOffsetOrgEditorName = 0x7f,    // Up to 20-byte original editor name text.
    kEditDataOffsetEditorID = 0x93,         // 5-byte editor identifier text.
    kEditDataOffsetNames = 0x98,            // Length-prefixed fumenName, editorName, and comment.
    kEditDataOffsetEventNum = 0x103,        // 4-byte event count.
    kEditDataOffsetNotesNum = 0x107,        // 4-byte notes count.
    kEditDataOffsetEndSector = 0x10b,       // 4-byte end sector.
    kEditDataOffsetFirstMarker = 0x10f,     // 4-byte first-marker bitmask.
    kEditDataOffsetFirstSector = 0x113,     // 4-byte first-marker sector.
    kEditDataOffsetMusicBar = 0x117,        // 60-byte music bar.
    kEditDataOffsetSimpleNotesHash = 0x153, // 32-byte simple-data notes hash (hex text).
    kEditDataOffsetSequenceTable = 0x173,   // 2000 4-byte note words.
    kEditDataOffsetSequenceID = 0x20b3,     // 8-byte download sequence identifier text.
    kEditDataOffsetGoodJobSend = 0x20bb,    // 1-byte good-job flag.
};

enum {
    kEditDataMusicBarLength = 0x3c,       // 60 bytes.
    kEditDataSequenceTableCount = 2000,   // Note words.
    kEditDataSequenceTableLength = 8000,  // Bytes hashed for the notes hash.
    kEditDataHashHexLength = 0x20,        // 32 hexadecimal characters.
    kEditDataOrgEditorNameMaxLength = 10, // The orgEditorName is clamped to this.
    kEditDataDLTagLength = 8,             // The random download tag length.
    kEditDataDLTagFlagIndex = 5,          // The download-flag byte within the tag.
    kEditDataEditorIDLength = 5,
    kEditDataOrgFumenIndexLength = 8,
};

// The maximum stored length of each of the three length-prefixed name fields (fumenName,
// editorName, and comment), read from __const at 0x293cc4.
static const char kEditDataNameMaxLengths[] = {20, 20, 60};

// The three name-field dictionary keys, in the packed order.
static NSString *const kEditDataNameKeys[] = {@"fumenName", @"editorName", @"comment"};

// The editable-slot arithmetic: a base allotment plus one slot per this many music.
enum {
    kEditSlotBaseCount = 4,
    kEditSlotMusicPerSlot = 40,
};

// The maximum acceptable score; scoreUpdate: ignores anything at or above it.
static const int kEditDataMaxScore = 0xf4241;

// The random tag characters span this many letters starting at 'A'.
static const int kEditDataTagLetterSpan = 25;

// The editor-name application-defaults key and the default field values, from __const.
static NSString *const kPrefEditorNameKey = @"PrefEditorName";
// The default fumenName ("°eW0D") and editorName ("\O\x10") assembled on the stack in the binary;
// the raw bytes are reproduced here from __const at 0x2c17fc and 0x2c17f4 respectively.
static NSString *const kEditDataZeroHashText = @"00000000000000000000000000000000"; // 32 zeros.

@interface EditDataManager () {
    NSMutableArray *sequenceTable;
    NSMutableDictionary *editorInfo;
    NSMutableDictionary *editSimpleData;
    NSMutableDictionary *scoreData;
    NSMutableData *writeData;
    unsigned int version;
    char musicBarTable[60];
    BOOL _bEnableCopy;
    BOOL _bIsDownload;
}
@end

@implementation EditDataManager

#pragma mark - Lifecycle

+ (instancetype)sharedManager {
    static EditDataManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      /** @ghidraAddress 0x1c5a18 */
      instance = [[EditDataManager alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        sequenceTable = nil;
        editorInfo = nil;
        writeData = nil;
        _bEnableCopy = YES;
        _bIsDownload = NO;
        version = 0;
        memset(musicBarTable, 0, sizeof(musicBarTable));
    }
    return self;
}

#pragma mark - Custom sequence directory tree

- (NSArray<NSString *> *)getCustomSequenceDirectoryList {
    NSString *path =
        [[JubeatAppDelegate appDocumentsDirectory] stringByAppendingPathComponent:@"edit"];
    NSFileManager *manager = [NSFileManager defaultManager];
    if (![manager fileExistsAtPath:path]) {
        return nil;
    }
    return [manager contentsOfDirectoryAtPath:path error:nil];
}

- (void)deleteCustomSequenceDirectory:(NSNumber *)musicID {
    NSString *path = [self getDirectoryPath:musicID.intValue];
    if (path) {
        [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
    }
}

- (BOOL)addIgnoreBackUpAttribute:(NSString *)path {
    // The binary body only returns YES; the resource-value call was compiled out.
    return YES;
}

- (NSString *)getDirectoryPath:(int)musicID {
    NSString *editPath =
        [[JubeatAppDelegate appDocumentsDirectory] stringByAppendingPathComponent:@"edit"];
    NSString *subDir = [NSString stringWithFormat:@"%09d", musicID];
    NSFileManager *manager = [NSFileManager defaultManager];
    NSError *error = nil;
    if (![manager fileExistsAtPath:editPath]) {
        [manager createDirectoryAtPath:editPath
            withIntermediateDirectories:YES
                             attributes:nil
                                  error:&error];
        [self addIgnoreBackUpAttribute:editPath];
    }
    NSString *musicPath = [editPath stringByAppendingPathComponent:subDir];
    if (![manager fileExistsAtPath:musicPath]) {
        [manager createDirectoryAtPath:musicPath
            withIntermediateDirectories:YES
                             attributes:nil
                                  error:&error];
    }
    return musicPath;
}

- (NSString *)createJCFName {
    NSDate *now = [NSDate date];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyyMMddHHmmssSSS";
    NSString *stamp = [formatter stringFromDate:now];
    return [NSString stringWithFormat:@"%@.jcf", stamp];
}

- (BOOL)deleteJCF:(NSString *)path {
    if (!path) {
        return NO;
    }
    NSFileManager *manager = [NSFileManager defaultManager];
    if ([manager fileExistsAtPath:path]) {
        NSError *error = nil;
        [manager removeItemAtPath:path error:&error];
    }
    return YES;
}

- (BOOL)loadJCF:(NSString *)path {
    if (!path) {
        return NO;
    }
    sequenceTable = nil;
    editorInfo = nil;
    writeData = nil;
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        return NO;
    }
    NSMutableData *raw = [NSMutableData dataWithContentsOfFile:path];
    NSData *decoded = [self exeLoadBFDec:raw];
    NSData *body;
    if ([self checkDownloadFile:decoded]) {
        body = [self exeBFDec:decoded];
    } else {
        body = [NSMutableData dataWithData:decoded];
    }
    writeData = (NSMutableData *)body;
    return [self decodeBinary];
}

- (BOOL)saveJCF:(NSString *)path {
    if (!path) {
        return NO;
    }
    if (!sequenceTable || !editorInfo) {
        return YES;
    }
    [self encodeBinary];
    if ([editorInfo[@"dlFlag"] intValue] == 1) {
        NSData *inner = [self exeBFEnc:writeData];
        NSData *encoded = [self exeSaveBFEnc:inner];
        [encoded writeToFile:path atomically:YES];
    } else {
        NSData *encoded = [self exeSaveBFEnc:writeData];
        [encoded writeToFile:path atomically:YES];
    }
    return YES;
}

#pragma mark - Blowfish encode/decode

- (BOOL)createEditDataWithNSData:(NSData *)data {
    writeData = (NSMutableData *)data;
    [self decodeBinary];
    return YES;
}

- (NSMutableData *)exeSaveBFEnc:(NSData *)data {
    NSMutableData *buffer = [NSMutableData dataWithData:data];
    BFCodec *codec = [[BFCodec alloc] init];
    [codec cipherInit:CreateSaveDataCipherKey()];
    [codec encipher:buffer];
    return buffer;
}

- (NSMutableData *)exeLoadBFDec:(NSData *)data {
    NSMutableData *buffer = [NSMutableData dataWithData:data];
    BFCodec *codec = [[BFCodec alloc] init];
    [codec cipherInit:CreateSaveDataCipherKey()];
    [codec decipher:buffer];
    return buffer;
}

- (NSData *)exeBFEnc:(NSData *)data {
    // The binary returns its argument unchanged; the second cipher layer was compiled out.
    return data;
}

- (NSData *)exeBFDec:(NSData *)data {
    // The binary returns its argument unchanged; the second cipher layer was compiled out.
    return data;
}

#pragma mark - Download tagging

- (NSString *)createDLString:(char *)buffer isDL:(BOOL)isDL {
    for (int i = 0; i < kEditDataDLTagLength; ++i) {
        int value = rand();
        char letter = (char)('A' + value % kEditDataTagLetterSpan);
        if (i == kEditDataDLTagFlagIndex) {
            if (isDL) {
                letter &= 0xfe;
            } else {
                letter |= 1;
            }
        }
        buffer[i] = letter;
    }
    return [NSString stringWithUTF8String:buffer];
}

- (BOOL)checkDownLoad:(const char *)buffer {
    if (!buffer) {
        return NO;
    }
    return (buffer[kEditDataDLTagFlagIndex] & 1) == 0;
}

- (BOOL)checkDownloadFile:(NSData *)data {
    // The binary copies the tag out of the blob's bytes onto the stack, then tests the DL bit; here
    // the tag is read in place from the blob at the version+tag offset.
    const char *bytes = (const char *)data.bytes;
    return [self checkDownLoad:bytes + kEditDataOffsetDLTag];
}

- (BOOL)localSaveDLFile:(NSData *)data serial:(NSString *)serial usrTag:(int)usrTag {
    NSMutableDictionary *info = [self pickUpEditorInfoFromData:data];
    int musicID = [info[@"musicID"] intValue];
    NSString *dir = [self getDirectoryPath:musicID];
    NSString *fileName = [[NSString alloc] initWithFormat:@"%@.jcf", serial];
    NSString *path = [dir stringByAppendingPathComponent:fileName];
    if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
        return [self loadJCF:path];
    }
    if (![self createEditDataWithNSData:data]) {
        return NO;
    }
    int storedMusicID = [editorInfo[@"musicID"] intValue];
    NSString *storedDir = [self getDirectoryPath:storedMusicID];
    NSString *storedName = [[NSString alloc] initWithFormat:@"%@.jcf", serial];
    NSString *storedPath = [storedDir stringByAppendingPathComponent:storedName];
    if (![[NSFileManager defaultManager] fileExistsAtPath:storedPath]) {
        editorInfo[@"dlFlag"] = @1;
        editorInfo[@"userTag"] = @(usrTag);
        _bIsDownload = YES;
        editorInfo[@"sequenceID"] = serial;
        editorInfo[@"goodJobSend"] = @0;
        [self scoreDataReset];
        [self saveJCF:storedPath];
    }
    return YES;
}

#pragma mark - Packed binary format helpers

- (NSMutableDictionary *)pickUpEditorInfoFromData:(NSData *)data {
    char *scratch = malloc(kEditDataBlobLength);
    memcpy(scratch, data.bytes, kEditDataBlobLength);
    NSMutableDictionary *info = [self pickUpEditorInfo:scratch];
    free(scratch);
    return info;
}

- (void)setCharArray:(char *)buffer setData:(unsigned int)data byte:(int)byte {
    for (int i = 0; i < byte; ++i) {
        buffer[i] = (char)(data >> (i * 8));
    }
}

- (unsigned int)getCharArrayValue:(const char *)buffer byte:(int)byte {
    unsigned int value = 0;
    for (int i = 0; i < byte; ++i) {
        value += (unsigned int)(unsigned char)buffer[i] << (i * 8);
    }
    return value;
}

- (BOOL)validateHash:(NSData *)data {
    char *scratch = malloc(kEditDataBlobLength);
    memcpy(scratch, writeData.bytes, kEditDataBlobLength);
    NSData *body = [[NSData alloc] initWithBytes:scratch + kEditDataOffsetBody
                                          length:kEditDataBodyLength];
    NSUInteger computed = body.hash;
    unsigned int stored = [self getCharArrayValue:scratch + kEditDataDLTagLength byte:8];
    free(scratch);
    return (unsigned int)computed == stored;
}

#pragma mark - Score data

- (void)scoreDataReset {
    scoreData[@"bestScore"] = @(-1);
    scoreData[@"fullcomboFlg"] = @NO;
    scoreData[@"notesHash"] = [NSString stringWithFormat:@"%@", kEditDataZeroHashText];
    scoreData[@"scoreHash"] = [NSString stringWithFormat:@"%@", kEditDataZeroHashText];
}

- (NSMutableDictionary *)pickUpScoreData:(const char *)buffer {
    if (!buffer) {
        return nil;
    }
    NSMutableDictionary *info = [[NSMutableDictionary alloc] init];
    NSString *scoreHash = [[NSString alloc] initWithBytes:buffer + kEditDataOffsetScoreHash
                                                   length:kEditDataHashHexLength
                                                 encoding:NSUTF8StringEncoding];
    info[@"scoreHash"] = scoreHash;
    unsigned int bestScore = [self getCharArrayValue:buffer + kEditDataOffsetBestScore byte:4];
    info[@"bestScore"] = @(bestScore);
    info[@"fullcomboFlg"] = @(buffer[kEditDataOffsetFullCombo] != 0);
    NSString *notesHash = [[NSString alloc] initWithBytes:buffer + kEditDataOffsetNotesHash
                                                   length:kEditDataHashHexLength
                                                 encoding:NSUTF8StringEncoding];
    info[@"notesHash"] = notesHash;
    BOOL scoreOK = [scoreHash isEqualToString:[self getScoreHash:bestScore]];
    NSString *bodyHash =
        CreateMD5HexString(buffer + kEditDataOffsetSequenceTable, kEditDataSequenceTableLength);
    BOOL notesOK = [notesHash isEqualToString:bodyHash];
    if (!scoreOK || !notesOK) {
        [self scoreDataReset];
    }
    return info;
}

- (NSMutableDictionary *)pickUpEditorInfo:(const char *)buffer {
    if (!buffer) {
        return nil;
    }
    NSMutableDictionary *info = [[NSMutableDictionary alloc] init];
    (void)[self getCharArrayValue:buffer byte:2]; // Yes, the binary discards this version read.
    BOOL isDL = [self checkDownLoad:buffer + kEditDataOffsetDLTag];
    info[@"dlFlag"] = @(isDL);
    info[@"userTag"] = @((char)buffer[kEditDataOffsetUserTag]);
    info[@"copyLock"] = @((int)buffer[kEditDataOffsetCopyLock]);
    unsigned int musicID = [self getCharArrayValue:buffer + kEditDataOffsetMusicID byte:4];
    info[@"musicID"] = @(musicID);
    info[@"level"] = @((unsigned int)(char)buffer[kEditDataOffsetLevel]);
    info[@"orgFumenIndex"] = [[NSString alloc] initWithBytes:buffer + kEditDataOffsetOrgFumenIndex
                                                      length:kEditDataOrgFumenIndexLength
                                                    encoding:NSShiftJISStringEncoding];
    char orgEditorNameLen = buffer[kEditDataOffsetOrgEditorNameLen];
    NSString *orgEditorName = [[NSString alloc] initWithBytes:buffer + kEditDataOffsetOrgEditorName
                                                       length:orgEditorNameLen
                                                     encoding:NSShiftJISStringEncoding];
    if (orgEditorName.length > kEditDataOrgEditorNameMaxLength) {
        orgEditorName =
            [orgEditorName substringWithRange:NSMakeRange(0, kEditDataOrgEditorNameMaxLength)];
    }
    info[@"orgEditorName"] = orgEditorName;
    info[@"editorID"] = [[NSString alloc] initWithBytes:buffer + kEditDataOffsetEditorID
                                                 length:kEditDataEditorIDLength
                                               encoding:NSShiftJISStringEncoding];
    // Each name is a fixed-width slot: a one-byte stored length followed by a max-length payload.
    // The cursor advances by the field's maximum length (not its stored length), so the three
    // slots sit at the fixed offsets 0x98, 0xad, and 0xc2 that encodeBinary writes.
    int offset = kEditDataOffsetNames;
    for (int i = 0; i < 3; ++i) {
        char fieldLen = buffer[offset];
        NSString *name = [[NSString alloc] initWithBytes:buffer + (offset + 1)
                                                  length:fieldLen
                                                encoding:NSShiftJISStringEncoding];
        // Each field is clamped to half its maximum length.
        NSInteger limit = kEditDataNameMaxLengths[i] / 2;
        if ((NSInteger)name.length > limit) {
            name = [name substringWithRange:NSMakeRange(0, limit)];
        }
        if (!name) {
            name = @"";
        }
        info[kEditDataNameKeys[i]] = name;
        offset += kEditDataNameMaxLengths[i] + 1;
    }
    unsigned int notesNum = [self getCharArrayValue:buffer + kEditDataOffsetNotesNum byte:4];
    info[@"notesNum"] = @(notesNum);
    return info;
}

- (NSMutableDictionary *)pickUpEditSimpleData:(const char *)buffer {
    NSMutableDictionary *info = [[NSMutableDictionary alloc] init];
    // Yes, the binary reads the event-count field twice; the first result is discarded.
    (void)[self getCharArrayValue:buffer + kEditDataOffsetEventNum byte:4];
    unsigned int eventNum = [self getCharArrayValue:buffer + kEditDataOffsetEventNum byte:4];
    info[@"eventNum"] = @(eventNum);
    info[@"notesNum"] = @([self getCharArrayValue:buffer + kEditDataOffsetNotesNum byte:4]);
    info[@"endSector"] = @([self getCharArrayValue:buffer + kEditDataOffsetEndSector byte:4]);
    info[@"firstMarker"] = @([self getCharArrayValue:buffer + kEditDataOffsetFirstMarker byte:4]);
    info[@"firstSector"] = @([self getCharArrayValue:buffer + kEditDataOffsetFirstSector byte:4]);
    info[@"musicBar"] = [[NSMutableData alloc] initWithBytes:buffer + kEditDataOffsetMusicBar
                                                      length:kEditDataMusicBarLength];
    info[@"notesHash"] = [[NSString alloc] initWithBytes:buffer + kEditDataOffsetSimpleNotesHash
                                                  length:kEditDataHashHexLength
                                                encoding:NSUTF8StringEncoding];
    return info;
}

- (NSMutableArray<NSNumber *> *)pickUpSequenceTable:(const char *)buffer {
    NSMutableArray<NSNumber *> *table = [[NSMutableArray alloc] init];
    const char *cursor = buffer + kEditDataOffsetSequenceTable;
    for (int i = 0; i < kEditDataSequenceTableCount; ++i) {
        unsigned int word = [self getCharArrayValue:cursor byte:4];
        [table addObject:@(word)];
        cursor += 4;
    }
    return table;
}

- (BOOL)decodeBinary {
    BOOL isDL = [self checkDownloadFile:writeData];
    size_t length = isDL ? kEditDataDownloadBlobLength : kEditDataBlobLength;
    char *scratch = malloc(length);
    memcpy(scratch, writeData.bytes, length);
    editorInfo = nil;
    sequenceTable = nil;
    version = [self getCharArrayValue:scratch byte:2];
    NSString *headerHash = CreateMD5HexString(scratch + kEditDataOffsetBody, kEditDataBodyLength);
    NSString *storedHash = [[NSString alloc] initWithBytes:scratch + kEditDataOffsetHeaderHash
                                                    length:kEditDataHashHexLength
                                                  encoding:NSUTF8StringEncoding];
    if (![storedHash isEqualToString:headerHash]) {
        editSimpleData = nil;
        scoreData = nil;
        editorInfo = nil;
        sequenceTable = nil;
        free(scratch);
        return NO;
    }
    scoreData = [self pickUpScoreData:scratch];
    editorInfo = [self pickUpEditorInfo:scratch];
    _bIsDownload = [editorInfo[@"dlFlag"] intValue] != 0;
    _bEnableCopy = [editorInfo[@"copyLock"] intValue] != 0;
    editSimpleData = [self pickUpEditSimpleData:scratch];
    sequenceTable = [self pickUpSequenceTable:scratch];
    if (_bIsDownload) {
        NSString *sequenceID = [[NSString alloc] initWithBytes:scratch + kEditDataOffsetSequenceID
                                                        length:kEditDataDLTagLength
                                                      encoding:NSUTF8StringEncoding];
        if (sequenceID) {
            editorInfo[@"sequenceID"] = sequenceID;
        }
        editorInfo[@"goodJobSend"] = @((int)scratch[kEditDataOffsetGoodJobSend]);
    }
    free(scratch);
    return YES;
}

- (BOOL)encodeBinary {
    size_t length = _bIsDownload ? kEditDataDownloadBlobLength : kEditDataBlobLength;
    char *scratch = malloc(length);
    bzero(scratch, length);
    scratch[kEditDataOffsetUserTag] = (char)[editorInfo[@"userTag"] intValue];
    scratch[kEditDataOffsetCopyLock] = (char)[editorInfo[@"copyLock"] intValue];
    [self setCharArray:scratch + kEditDataOffsetMusicID
               setData:[editorInfo[@"musicID"] intValue]
                  byte:4];
    scratch[kEditDataOffsetLevel] = (char)[editorInfo[@"level"] intValue];
    NSData *orgFumenIndex =
        [editorInfo[@"orgFumenIndex"] dataUsingEncoding:NSShiftJISStringEncoding];
    [orgFumenIndex getBytes:scratch + kEditDataOffsetOrgFumenIndex
                     length:kEditDataOrgFumenIndexLength];
    NSData *orgEditorName =
        [editorInfo[@"orgEditorName"] dataUsingEncoding:NSShiftJISStringEncoding];
    // The binary first writes eight bytes to the length slot, then immediately overwrites its first
    // byte with the real length and the payload at 0x7f; the first write is thus a discarded quirk.
    [orgEditorName getBytes:scratch + kEditDataOffsetOrgEditorNameLen
                     length:kEditDataOrgFumenIndexLength];
    scratch[kEditDataOffsetOrgEditorNameLen] = (char)orgEditorName.length;
    [orgEditorName getBytes:scratch + kEditDataOffsetOrgEditorName
                     length:(int)orgEditorName.length];
    NSData *editorID = [editorInfo[@"editorID"] dataUsingEncoding:NSShiftJISStringEncoding];
    [editorID getBytes:scratch + kEditDataOffsetEditorID length:kEditDataEditorIDLength];
    // The three length-prefixed name fields: fumenName at 0x98, editorName at 0xad, comment at
    // 0xc2.
    static const int kNameLenOffsets[] = {0x98, 0xad, 0xc2};
    static const int kNameDataOffsets[] = {0x99, 0xae, 0xc3};
    NSString *nameSourceKeys[] = {@"fumenName", @"editorName", @"comment"};
    for (int i = 0; i < 3; ++i) {
        NSData *name = [editorInfo[nameSourceKeys[i]] dataUsingEncoding:NSShiftJISStringEncoding];
        scratch[kNameLenOffsets[i]] = (char)name.length;
        [name getBytes:scratch + kNameDataOffsets[i] length:(int)name.length];
    }
    for (int i = 0; i < kEditDataSequenceTableCount; ++i) {
        unsigned int word = [sequenceTable[i] unsignedIntValue];
        [self setCharArray:scratch + kEditDataOffsetSequenceTable + i * 4 setData:word byte:4];
    }
    [self setCharArray:scratch + kEditDataOffsetEventNum
               setData:[editSimpleData[@"eventNum"] unsignedIntValue]
                  byte:4];
    [self setCharArray:scratch + kEditDataOffsetNotesNum
               setData:[editSimpleData[@"notesNum"] unsignedIntValue]
                  byte:4];
    [self setCharArray:scratch + kEditDataOffsetEndSector
               setData:[editSimpleData[@"endSector"] unsignedIntValue]
                  byte:4];
    [self setCharArray:scratch + kEditDataOffsetFirstMarker
               setData:[editSimpleData[@"firstMarker"] unsignedIntValue]
                  byte:4];
    [self setCharArray:scratch + kEditDataOffsetFirstSector
               setData:[editSimpleData[@"firstSector"] unsignedIntValue]
                  byte:4];
    [editSimpleData[@"musicBar"] getBytes:scratch + kEditDataOffsetMusicBar
                                   length:kEditDataMusicBarLength];
    NSString *bodyHash =
        [[NSString alloc] initWithString:CreateMD5HexString(scratch + kEditDataOffsetSequenceTable,
                                                            kEditDataSequenceTableLength)];
    memcpy(scratch + kEditDataOffsetSimpleNotesHash, bodyHash.UTF8String, kEditDataHashHexLength);
    if (![bodyHash isEqualToString:scoreData[@"notesHash"]]) {
        [self scoreDataReset];
    }
    scoreData[@"notesHash"] = bodyHash;
    NSString *scoreHash =
        [[NSString alloc] initWithString:[self getScoreHash:[scoreData[@"bestScore"] intValue]]];
    memcpy(scratch + kEditDataOffsetScoreHash, scoreHash.UTF8String, kEditDataHashHexLength);
    [self setCharArray:scratch + kEditDataOffsetBestScore
               setData:[scoreData[@"bestScore"] intValue]
                  byte:4];
    scratch[kEditDataOffsetFullCombo] = (char)[scoreData[@"fullcomboFlg"] boolValue];
    NSString *notesHash = scoreData[@"notesHash"];
    memcpy(scratch + kEditDataOffsetNotesHash, notesHash.UTF8String, kEditDataHashHexLength);
    [self setCharArray:scratch setData:1 byte:2];
    char tag[kEditDataDLTagLength];
    [self createDLString:tag isDL:_bIsDownload];
    memcpy(scratch + kEditDataOffsetDLTag, tag, kEditDataDLTagLength);
    NSString *headerHash = CreateMD5HexString(scratch + kEditDataOffsetBody, kEditDataBodyLength);
    memcpy(scratch + kEditDataOffsetHeaderHash, headerHash.UTF8String, kEditDataHashHexLength);
    if (_bIsDownload) {
        NSString *sequenceID = editorInfo[@"sequenceID"];
        memcpy(scratch + kEditDataOffsetSequenceID, sequenceID.UTF8String, kEditDataDLTagLength);
        scratch[kEditDataOffsetGoodJobSend] = (char)[editorInfo[@"goodJobSend"] intValue];
    }
    writeData = [[NSMutableData alloc] initWithBytes:scratch length:length];
    free(scratch);
    return YES;
}

- (NSMutableArray<NSMutableDictionary *> *)getFileInfoList:(unsigned int)musicID {
    NSString *dir = [self getDirectoryPath:musicID];
    NSFileManager *manager = [NSFileManager defaultManager];
    NSArray<NSString *> *entries = [manager contentsOfDirectoryAtPath:dir error:nil];
    NSMutableArray<NSMutableDictionary *> *list = [[NSMutableArray alloc] init];
    for (NSUInteger i = 0; i < entries.count; ++i) {
        NSString *entry = entries[i];
        if ([entry rangeOfString:@".jcf"].location == NSNotFound) {
            continue;
        }
        NSString *path = [dir stringByAppendingPathComponent:entry];
        if (![manager fileExistsAtPath:path]) {
            continue;
        }
        NSMutableData *raw = [NSMutableData dataWithContentsOfFile:path];
        NSData *decoded = [self exeLoadBFDec:raw];
        NSData *body;
        if ([self checkDownloadFile:decoded]) {
            body = [self exeBFDec:decoded];
        } else {
            body = [NSMutableData dataWithData:decoded];
        }
        int bodyLength = (int)body.length;
        char *scratch = malloc(bodyLength);
        memcpy(scratch, body.bytes, bodyLength);
        NSMutableDictionary *info = [self pickUpEditorInfo:scratch];
        info[@"fileName"] = entry;
        [list addObject:info];
        free(scratch);
    }
    return list;
}

#pragma mark - Edit state

- (BOOL)isEnableEdit {
    return _bEnableCopy == NO;
}

- (void)disableEdit {
    _bEnableCopy = YES;
}

- (NSMutableDictionary *)getScoreData {
    return scoreData;
}

- (void)setScoreData:(NSDictionary *)aScoreData {
    scoreData = nil;
    scoreData = [[NSMutableDictionary alloc] initWithDictionary:aScoreData];
}

- (NSMutableDictionary *)getEditorInfo {
    return editorInfo;
}

- (void)setEditorInfo:(NSDictionary *)anEditorInfo {
    editorInfo = nil;
    editorInfo = [[NSMutableDictionary alloc] initWithDictionary:anEditorInfo];
}

- (NSMutableDictionary *)getEditSimpleData {
    return editSimpleData;
}

- (void)setEditSimpleData:(NSDictionary *)anEditSimpleData {
    editSimpleData = nil;
    editSimpleData = [[NSMutableDictionary alloc] initWithDictionary:anEditSimpleData];
}

- (void)clearEditData {
    sequenceTable = nil;
    editorInfo = nil;
    editSimpleData = nil;
    writeData = nil;
    scoreData = nil;
}

- (void)resetEditorInfo {
    editorInfo = nil;
    editorInfo = [[NSMutableDictionary alloc] init];
    NSString *savedName = [[NSUserDefaults standardUserDefaults] stringForKey:kPrefEditorNameKey];
    if (!savedName) {
        // The default editor name, "creator" (UTF-16 CFString in the binary).
        savedName = @"作成者";
    }
    // The default chart name, "new chart" (UTF-16 CFString in the binary).
    editorInfo[@"fumenName"] = @"新しい譜面";
    editorInfo[@"editorName"] = savedName;
    editorInfo[@"comment"] = @"";
    editorInfo[@"level"] = @0;
    editorInfo[@"copyLock"] = @((char)1);
    editorInfo[@"dlFlag"] = @((char)0);
    _bIsDownload = NO;
    _bEnableCopy = NO;
    editorInfo[@"notesNum"] = @0;
    editSimpleData[@"notesNum"] = @0;
    scoreData = nil;
    scoreData = [[NSMutableDictionary alloc] init];
    [self scoreDataReset];
    editSimpleData = nil;
    sequenceTable = nil;
}

- (NSMutableArray<NSNumber *> *)getSequenceTable {
    return sequenceTable;
}

- (void)setSequenceTable:(NSMutableArray<NSNumber *> *)aSequenceTable {
    sequenceTable = aSequenceTable;
}

#pragma mark - Last-edited file

- (NSString *)getLastEditFileName:(int)musicID {
    NSFileManager *manager = [NSFileManager defaultManager];
    NSString *dir = [self getDirectoryPath:musicID];
    NSString *markerPath = [dir stringByAppendingPathComponent:@"lastplay.txt"];
    if (![manager fileExistsAtPath:markerPath]) {
        return nil;
    }
    NSData *data = [NSData dataWithContentsOfFile:markerPath];
    if (data.length == 0) {
        return nil;
    }
    NSString *name = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSString *filePath = [dir stringByAppendingPathComponent:name];
    if (![manager fileExistsAtPath:filePath]) {
        return nil;
    }
    return name;
}

- (NSString *)getLastEditFilePath:(int)musicID {
    NSString *name = [self getLastEditFileName:musicID];
    if (!name) {
        return nil;
    }
    return [[self getDirectoryPath:musicID] stringByAppendingPathComponent:name];
}

- (void)setLastEditFileName:(int)musicID fileName:(NSString *)fileName {
    NSFileManager *manager = [NSFileManager defaultManager];
    NSString *dir = [self getDirectoryPath:musicID];
    NSString *markerPath = [dir stringByAppendingPathComponent:@"lastplay.txt"];
    if (![manager fileExistsAtPath:dir]) {
        NSError *error = nil;
        [manager createDirectoryAtPath:dir
            withIntermediateDirectories:YES
                             attributes:nil
                                  error:&error];
    }
    NSData *data = [fileName dataUsingEncoding:NSUTF8StringEncoding];
    [data writeToFile:markerPath atomically:YES];
}

- (BOOL)IsExistEditFile:(int)musicID {
    NSFileManager *manager = [NSFileManager defaultManager];
    NSString *dir = [self getDirectoryPath:musicID];
    if (![manager fileExistsAtPath:dir]) {
        return NO;
    }
    NSString *markerPath = [dir stringByAppendingPathComponent:@"lastplay.txt"];
    return [manager fileExistsAtPath:markerPath];
}

#pragma mark - Score hashing and update

- (NSString *)getScoreHash:(int)score {
    char packed[4];
    [self setCharArray:packed setData:(unsigned int)score byte:4];
    return CreateMD5HexString(packed, 4);
}

- (BOOL)checkScoreHash {
    NSString *storedHash = scoreData[@"scoreHash"];
    int bestScore = [scoreData[@"bestScore"] intValue];
    NSString *computedHash = [self getScoreHash:bestScore];
    return [storedHash isEqualToString:computedHash];
}

- (void)scoreUpdate:(int)score fullCombo:(BOOL)fullCombo tuneID:(int)tuneID {
    if (score >= kEditDataMaxScore) {
        return;
    }
    if (![self checkScoreHash]) {
        scoreData[@"bestScore"] = [[NSNumber alloc] initWithInt:score];
        scoreData[@"scoreHash"] = [self getScoreHash:score];
        scoreData[@"fullcomboFlg"] = [[NSNumber alloc] initWithBool:fullCombo];
    } else {
        if ([scoreData[@"bestScore"] intValue] < score) {
            scoreData[@"bestScore"] = [[NSNumber alloc] initWithInt:score];
            scoreData[@"scoreHash"] = [self getScoreHash:score];
        }
        BOOL priorFullCombo = [scoreData[@"fullcomboFlg"] boolValue];
        scoreData[@"fullcomboFlg"] = [[NSNumber alloc] initWithBool:(priorFullCombo | fullCombo)];
    }
    NSString *path = [self getLastEditFilePath:tuneID];
    [self saveJCF:path];
}

#pragma mark - Music catalogue

- (NSMutableArray<NSString *> *)getMusicIDList {
    NSMutableArray<NSString *> *list = [[NSMutableArray alloc] init];
    NSString *musicPlist = [[NSBundle mainBundle] pathForResource:@"Music" ofType:@""];
    if (musicPlist) {
        NSArray *builtin = [[StoreMusicListManager sharedManager] builtinMusic];
        for (id music in builtin) {
            [list addObject:[NSString stringWithFormat:@"%@", music]];
        }
    }
    NSArray<NSDictionary *> *purchased = [[StoreMusicListManager sharedManager] purchasedMusic];
    for (NSDictionary *music in purchased) {
        [list addObject:[NSString stringWithFormat:@"%@", music[@"ID"]]];
    }
    return list;
}

- (int)getMusicNum {
    int builtinCount = 0;
    NSString *musicPlist = [[NSBundle mainBundle] pathForResource:@"Music" ofType:@""];
    if (musicPlist) {
        builtinCount = (int)[[StoreMusicListManager sharedManager] builtinMusic].count;
    }
    int purchasedCount = (int)[[StoreMusicListManager sharedManager] purchasedMusic].count;
    return purchasedCount + builtinCount;
}

- (int)getEditSlotLimit {
    return [self getMusicNum] / kEditSlotMusicPerSlot + kEditSlotBaseCount;
}

- (NSMutableData *)getCurrentCustomData {
    return writeData;
}

@end

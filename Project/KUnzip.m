#import "KUnzip.h"

#import <strings.h>

#import "ioapi.h"

// The archive read buffer is a fixed 64 KiB ivar the binary reads and reuses across chunks. The
// filename scratch buffer is 256 bytes; its last byte is reserved for the terminator, so the
// length passed to minizip is one less than the buffer.
enum {
    kReadBufferSize = 0x10000,
    kFileNameBufferSize = 256,
    kFileNameBufferMaxLength = kFileNameBufferSize - 1,
};

// The minizip unz* API is third-party and used as-is. Only the entry points KUnzip calls are
// declared here; the implementations live in the shipped minizip translation units. The archive
// handle and the I/O callback types come from ioapi.h.

/** minizip's opaque unzip archive handle. */
typedef void *unzFile;

/** minizip's 64-bit position type (zlib's ZPOS64_T). */
typedef unsigned long long ZPOS64_T;

/** The archive-wide header info filled by unzGetGlobalInfo64. */
typedef struct unz_global_info64_s {
    ZPOS64_T number_entry;
    uLong size_comment;
} unz_global_info64;

/** The date an entry was last modified, as filled by unzGetCurrentFileInfo64. */
typedef struct tm_unz_s {
    unsigned int tm_sec;
    unsigned int tm_min;
    unsigned int tm_hour;
    unsigned int tm_mday;
    unsigned int tm_mon;
    unsigned int tm_year;
} tm_unz;

/** The per-entry header info filled by unzGetCurrentFileInfo64. */
typedef struct unz_file_info64_s {
    uLong version;
    uLong version_needed;
    uLong flag;
    uLong compression_method;
    uLong dosDate;
    uLong crc;
    ZPOS64_T compressed_size;
    ZPOS64_T uncompressed_size;
    uLong size_filename;
    uLong size_file_extra;
    uLong size_file_comment;
    uLong disk_num_start;
    uLong internal_fa;
    uLong external_fa;
    tm_unz tmu_date;
} unz_file_info64;

extern unzFile unzOpen(const char *path);
extern unzFile unzOpenInternal(voidpf file, zlib_filefunc_def *pzlib_filefunc_def);
extern int unzClose(unzFile file);
extern int unzGetGlobalInfo64(unzFile file, unz_global_info64 *pglobal_info);
extern int unzGoToFirstFile(unzFile file);
extern int unzGoToNextFile(unzFile file);
extern int unzLocateFile(unzFile file, const char *szFileName, int iCaseSensitivity);
extern int unzGetCurrentFileInfo64(unzFile file,
                                   unz_file_info64 *pfile_info,
                                   char *szFileName,
                                   uLong fileNameBufferSize,
                                   void *extraField,
                                   uLong extraFieldBufferSize,
                                   char *szComment,
                                   uLong commentBufferSize);
extern int unzOpenCurrentFile(unzFile file);
extern int unzReadCurrentFile(unzFile file, void *buf, unsigned len);
extern int unzCloseCurrentFile(unzFile file);

// KUnzip's own I/O callback sets, installed for the file-handle-backed and memory-backed archives.
// They are free functions reconstructed in a later pass; forward-declared here so the initialisers
// can build the zlib_filefunc_def tables the same way the binary does, filling matching the inline
// stores in the binary rather than a fill_* helper.
// 0x76338
extern voidpf KUnzip_fopen_filehandle_func(voidpf opaque, const char *filename, int mode);
extern uLong KUnzip_fread_filehandle_func(voidpf opaque,
                                          voidpf stream,
                                          void *buf,
                                          uLong size); // 0x763d8
extern uLong KUnzip_fwrite_filehandle_func(voidpf opaque,
                                           voidpf stream,
                                           const void *buf,
                                           uLong size);                 // 0x76528
extern long KUnzip_ftell_filehandle_func(voidpf opaque, voidpf stream); // 0x76530
extern long KUnzip_fseek_filehandle_func(voidpf opaque,
                                         voidpf stream,
                                         uLong offset,
                                         int origin);                   // 0x7657c
extern int KUnzip_fclose_filehandle_func(voidpf opaque, voidpf stream); // 0x7667c
extern int KUnzip_ferror_filehandle_func(voidpf opaque, voidpf stream); // 0x766c4

extern voidpf KUnzip_fopen_mem_func(voidpf opaque, const char *filename, int mode);      // 0x76828
extern uLong KUnzip_fread_mem_func(voidpf opaque, voidpf stream, void *buf, uLong size); // 0x7688c
extern uLong KUnzip_fwrite_mem_func(voidpf opaque,
                                    voidpf stream,
                                    const void *buf,
                                    uLong size);                 // 0x769d0
extern long KUnzip_ftell_mem_func(voidpf opaque, voidpf stream); // 0x769d8
// 0x76a34
extern long KUnzip_fseek_mem_func(voidpf opaque, voidpf stream, uLong offset, int origin);
extern int KUnzip_fclose_mem_func(voidpf opaque, voidpf stream); // 0x76b2c
extern int KUnzip_ferror_mem_func(voidpf opaque, voidpf stream); // 0x76b34

@implementation KUnzip {
    unzFile zipfile;
    unsigned char buffer[kReadBufferSize];
}

- (instancetype)initWithPath:(nullable NSString *)path {
    self = [super init];
    if (self) {
        zipfile = unzOpen(path.UTF8String);
        if (zipfile == nullptr) {
            return nil;
        }
    }
    return self;
}

- (instancetype)initWithPath:(nullable NSString *)path tail:(NSUInteger)tail {
    NSDictionary<NSFileAttributeKey, id> *attributes =
        [NSFileManager.defaultManager attributesOfItemAtPath:path error:nil];
    NSUInteger fileSize = [attributes[NSFileSize] unsignedIntegerValue];
    if (tail < fileSize) {
        self = [super init];
        if (self) {
            _dataRange = NSMakeRange(0, fileSize - tail);
            zlib_filefunc_def filefunc;
            filefunc.zopen_file = KUnzip_fopen_filehandle_func;
            filefunc.zread_file = KUnzip_fread_filehandle_func;
            filefunc.zwrite_file = KUnzip_fwrite_filehandle_func;
            filefunc.ztell_file = KUnzip_ftell_filehandle_func;
            filefunc.zseek_file = KUnzip_fseek_filehandle_func;
            filefunc.zclose_file = KUnzip_fclose_filehandle_func;
            filefunc.zerror_file = KUnzip_ferror_filehandle_func;
            filefunc.opaque = (__bridge voidpf)self;
            zipfile = unzOpenInternal(path.UTF8String, &filefunc);
            if (zipfile == nullptr) {
                return nil;
            }
        }
    } else {
        return nil;
    }
    return self;
}

- (instancetype)initWithData:(nullable NSData *)data range:(NSRange)range {
    if (data == nil || range.location + range.length > data.length) {
        return nil;
    }
    self = [super init];
    if (self) {
        _dataRange = range;
        self.data = data;
        zlib_filefunc_def filefunc;
        filefunc.zopen_file = KUnzip_fopen_mem_func;
        filefunc.zread_file = KUnzip_fread_mem_func;
        filefunc.zwrite_file = KUnzip_fwrite_mem_func;
        filefunc.ztell_file = KUnzip_ftell_mem_func;
        filefunc.zseek_file = KUnzip_fseek_mem_func;
        filefunc.zclose_file = KUnzip_fclose_mem_func;
        filefunc.zerror_file = KUnzip_ferror_mem_func;
        filefunc.opaque = (__bridge voidpf)self;
        zipfile = unzOpenInternal(nullptr, &filefunc);
        if (zipfile == nullptr) {
            return nil;
        }
    }
    return self;
}

- (BOOL)fileExists:(nullable NSString *)name {
    if (zipfile == nullptr) {
        return NO;
    }
    return unzLocateFile(zipfile, name.UTF8String, 0) == 0;
}

- (NSUInteger)uncompressedSize:(nullable NSString *)name {
    if (zipfile == nullptr) {
        return 0;
    }
    if (unzLocateFile(zipfile, name.UTF8String, 1) != 0) {
        return 0;
    }
    unz_file_info64 info;
    if (unzGetCurrentFileInfo64(zipfile, &info, nullptr, 0, nullptr, 0, nullptr, 0) != 0) {
        return 0;
    }
    return info.uncompressed_size;
}

- (nullable NSArray<NSString *> *)fileList {
    unz_global_info64 globalInfo;
    if (zipfile == nullptr || unzGetGlobalInfo64(zipfile, &globalInfo) != 0 ||
        globalInfo.number_entry == 0 || unzGoToFirstFile(zipfile) != 0) {
        return nil;
    }
    NSMutableArray<NSString *> *names = [NSMutableArray arrayWithCapacity:globalInfo.number_entry];
    for (ZPOS64_T i = 0; i < globalInfo.number_entry; ++i) {
        unz_file_info64 info;
        char fileName[kFileNameBufferSize];
        if (unzGetCurrentFileInfo64(
                zipfile, &info, fileName, kFileNameBufferMaxLength, nullptr, 0, nullptr, 0) != 0) {
            return nil;
        }
        fileName[info.size_filename] = '\0';
        [names addObject:[NSString stringWithFormat:@"%s", fileName]];
        if (i + 1 < globalInfo.number_entry && unzGoToNextFile(zipfile) != 0) {
            return nil;
        }
    }
    return [NSArray arrayWithArray:names];
}

- (nullable NSMutableData *)uncompress:(nullable NSString *)name {
    if (zipfile == nullptr) {
        return nil;
    }
    if (unzLocateFile(zipfile, name.UTF8String, 0) != 0) {
        return nil;
    }
    unz_file_info64 info;
    if (unzGetCurrentFileInfo64(zipfile, &info, nullptr, 0, nullptr, 0, nullptr, 0) != 0) {
        return nil;
    }
    if (info.uncompressed_size == 0 || unzOpenCurrentFile(zipfile) != 0) {
        return nil;
    }
    NSMutableData *result = [NSMutableData dataWithCapacity:info.uncompressed_size];
    bzero(buffer, kReadBufferSize);
    int bytesRead = unzReadCurrentFile(zipfile, buffer, (unsigned)kReadBufferSize);
    while (bytesRead > 0) {
        [result appendBytes:buffer length:bytesRead];
        bytesRead = unzReadCurrentFile(zipfile, buffer, (unsigned)kReadBufferSize);
    }
    if (bytesRead < 0) {
        result = nil;
    }
    unzCloseCurrentFile(zipfile);
    return result;
}

- (void)dealloc {
    if (zipfile != nullptr) {
        unzClose(zipfile);
    }
    // [super dealloc] is compiler-emitted (ARC — .cxx_destruct at 0x76ffc).
}

@end

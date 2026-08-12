#import "KUnzip.h"

#import <strings.h>

#import "kunzip_filefunc.h"
#import "unzip.h"

// The archive read buffer is a fixed 64 KiB ivar the binary reads and reuses across chunks. The
// filename scratch buffer is 256 bytes; its last byte is reserved for the terminator, so the
// length passed to minizip is one less than the buffer.
enum {
    kReadBufferSize = 0x10000,
    kFileNameBufferSize = 256,
    kFileNameBufferMaxLength = kFileNameBufferSize - 1,
};

// The minizip unz* API (unzip.h) and KUnzip's own I/O callback sets (kunzip_filefunc.h) are used
// as-is; the archive handle, the info structs, and the I/O callback types come from those headers.

@implementation KUnzip {
    unzFile zipfile;
    unsigned char buffer[kReadBufferSize];
}

- (instancetype)initWithPath:(NSString *)path {
    self = [super init];
    if (self) {
        zipfile = unzOpen(path.UTF8String);
        if (zipfile == nullptr) {
            return nil;
        }
    }
    return self;
}

- (instancetype)initWithPath:(NSString *)path tail:(NSUInteger)tail {
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
            zipfile = unzOpenInternal((voidpf)path.UTF8String, &filefunc);
            if (zipfile == nullptr) {
                return nil;
            }
        }
    } else {
        return nil;
    }
    return self;
}

- (instancetype)initWithData:(NSData *)data range:(NSRange)range {
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

- (BOOL)fileExists:(NSString *)name {
    if (zipfile == nullptr) {
        return NO;
    }
    return unzLocateFile(zipfile, name.UTF8String, 0) == 0;
}

- (NSUInteger)uncompressedSize:(NSString *)name {
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

- (NSArray<NSString *> *)fileList {
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

- (NSMutableData *)uncompress:(NSString *)name {
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

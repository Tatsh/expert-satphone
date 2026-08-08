#import "kunzip_filefunc.h"

#import <Foundation/Foundation.h>

#import "KUnzip.h"

// KUnzip's own minizip I/O callback sets. Both take the KUnzip itself as the opaque cookie and
// ignore the stream argument. The file-handle set reads through the object's fileHandle, treating
// dataRange.length as an absolute end offset; the memory set reads out of its data over dataRange
// with the dataCurrentPos cursor, an absolute index into the NSData.

voidpf KUnzip_fopen_filehandle_func(voidpf opaque, const char *filename, int mode) {
    KUnzip *unzip = (__bridge KUnzip *)opaque;
    NSFileHandle *handle =
        [NSFileHandle fileHandleForReadingAtPath:[NSString stringWithUTF8String:filename]];
    if (handle != nil) {
        unzip.fileHandle = handle;
    }
    return (__bridge voidpf)handle;
}

uLong KUnzip_fread_filehandle_func(voidpf opaque, voidpf stream, void *buf, uLong size) {
    KUnzip *unzip = (__bridge KUnzip *)opaque;
    NSUInteger pos = unzip.fileHandle.offsetInFile;
    // This backend uses dataRange.length as an absolute end offset, not a length.
    if (unzip.dataRange.length <= pos) {
        return 0;
    }
    if (unzip.dataRange.length < pos + size) {
        size = unzip.dataRange.length - pos;
    }
    NSData *data = [unzip.fileHandle readDataOfLength:size];
    if (data == nil) {
        return 0;
    }
    [data getBytes:buf length:data.length];
    return data.length;
}

uLong KUnzip_fwrite_filehandle_func(voidpf opaque, voidpf stream, const void *buf, uLong size) {
    return 0;
}

long KUnzip_ftell_filehandle_func(voidpf opaque, voidpf stream) {
    KUnzip *unzip = (__bridge KUnzip *)opaque;
    return unzip.fileHandle.offsetInFile;
}

long KUnzip_fseek_filehandle_func(voidpf opaque, voidpf stream, uLong offset, int origin) {
    KUnzip *unzip = (__bridge KUnzip *)opaque;
    NSUInteger base;
    if (origin == ZLIB_FILEFUNC_SEEK_SET) {
        base = 0;
    } else if (origin == ZLIB_FILEFUNC_SEEK_END) {
        // dataRange.length is an absolute end offset here, so SEEK_END adds nothing to it.
        base = unzip.dataRange.length;
    } else if (origin == ZLIB_FILEFUNC_SEEK_CUR) {
        base = unzip.fileHandle.offsetInFile;
    } else {
        return -1;
    }
    if (unzip.dataRange.length < base + offset) {
        return -1;
    }
    [unzip.fileHandle seekToFileOffset:base + offset];
    return 0;
}

int KUnzip_fclose_filehandle_func(voidpf opaque, voidpf stream) {
    KUnzip *unzip = (__bridge KUnzip *)opaque;
    [unzip.fileHandle closeFile];
    return 0;
}

int KUnzip_ferror_filehandle_func(voidpf opaque, voidpf stream) {
    return 0;
}

voidpf KUnzip_fopen_mem_func(voidpf opaque, const char *filename, int mode) {
    KUnzip *unzip = (__bridge KUnzip *)opaque;
    if (unzip != nil) {
        unzip.dataCurrentPos = unzip.dataRange.location;
    }
    return opaque;
}

uLong KUnzip_fread_mem_func(voidpf opaque, voidpf stream, void *buf, uLong size) {
    KUnzip *unzip = (__bridge KUnzip *)opaque;
    NSUInteger pos = unzip.dataCurrentPos;
    NSUInteger end = unzip.dataRange.location + unzip.dataRange.length;
    if (pos >= end) {
        return 0;
    }
    if (pos + size > end) {
        size = end - pos;
    }
    [unzip.data getBytes:buf range:NSMakeRange(pos, size)];
    unzip.dataCurrentPos = unzip.dataCurrentPos + size;
    return size;
}

uLong KUnzip_fwrite_mem_func(voidpf opaque, voidpf stream, const void *buf, uLong size) {
    return 0;
}

long KUnzip_ftell_mem_func(voidpf opaque, voidpf stream) {
    KUnzip *unzip = (__bridge KUnzip *)opaque;
    return unzip.dataCurrentPos - unzip.dataRange.location;
}

long KUnzip_fseek_mem_func(voidpf opaque, voidpf stream, uLong offset, int origin) {
    KUnzip *unzip = (__bridge KUnzip *)opaque;
    NSUInteger base;
    if (origin == ZLIB_FILEFUNC_SEEK_SET) {
        base = unzip.dataRange.location;
    } else if (origin == ZLIB_FILEFUNC_SEEK_END) {
        base = unzip.dataRange.location + unzip.dataRange.length;
    } else if (origin == ZLIB_FILEFUNC_SEEK_CUR) {
        base = unzip.dataCurrentPos;
    } else {
        return -1;
    }
    if (unzip.dataRange.location + unzip.dataRange.length < base + offset) {
        return -1;
    }
    unzip.dataCurrentPos = base + offset;
    return 0;
}

int KUnzip_fclose_mem_func(voidpf opaque, voidpf stream) {
    return 0;
}

int KUnzip_ferror_mem_func(voidpf opaque, voidpf stream) {
    return 0;
}

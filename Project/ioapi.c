#include "ioapi.h"

#include <stdio.h>

// The three fopen mode strings live back to back in the string pool at 0x281257, 0x28125a, and
// 0x28125e. All three addresses are materialised on every call: the mode is chosen with a csel
// chain, not branches.
static const char *const kModeRead = "rb";
static const char *const kModeExisting = "r+b";
static const char *const kModeCreate = "wb";

voidpf fopen_file_func(voidpf opaque, const char *filename, int mode) {
    (void)opaque;
    const char *modeString = nullptr;
    if ((mode & ZLIB_FILEFUNC_MODE_READWRITEFILTER) == ZLIB_FILEFUNC_MODE_READ) {
        modeString = kModeRead;
    } else if (mode & ZLIB_FILEFUNC_MODE_EXISTING) {
        modeString = kModeExisting;
    } else if (mode & ZLIB_FILEFUNC_MODE_CREATE) {
        modeString = kModeCreate;
    }
    if (filename != nullptr && modeString != nullptr) {
        return fopen(filename, modeString);
    }
    return nullptr;
}

uLong fread_file_func(voidpf opaque, voidpf stream, void *buf, uLong size) {
    (void)opaque;
    return fread(buf, 1, size, (FILE *)stream);
}

uLong fwrite_file_func(voidpf opaque, voidpf stream, const void *buf, uLong size) {
    (void)opaque;
    return fwrite(buf, 1, size, (FILE *)stream);
}

long ftell_file_func(voidpf opaque, voidpf stream) {
    (void)opaque;
    return ftell((FILE *)stream);
}

long fseek_file_func(voidpf opaque, voidpf stream, uLong offset, int origin) {
    (void)opaque;
    // ZLIB_FILEFUNC_SEEK_SET/CUR/END are 0/1/2 and equal C's SEEK_SET/CUR/END on this platform, so
    // the binary uses a single unsigned range check with no remapping and rejects any other origin.
    if ((unsigned int)origin < 3) {
        // The binary returns -1 (all bits set) on any non-zero fseek result, not a boolean.
        return fseek((FILE *)stream, (long)offset, origin) != 0 ? -1 : 0;
    }
    return -1;
}

int fclose_file_func(voidpf opaque, voidpf stream) {
    (void)opaque;
    return fclose((FILE *)stream);
}

int ferror_file_func(voidpf opaque, voidpf stream) {
    (void)opaque;
    return ferror((FILE *)stream);
}

void fill_fopen_filefunc(zlib_filefunc_def *pzlib_filefunc_def) {
    pzlib_filefunc_def->zopen_file = fopen_file_func;
    pzlib_filefunc_def->zread_file = fread_file_func;
    pzlib_filefunc_def->zwrite_file = fwrite_file_func;
    pzlib_filefunc_def->ztell_file = ftell_file_func;
    pzlib_filefunc_def->zseek_file = fseek_file_func;
    pzlib_filefunc_def->zclose_file = fclose_file_func;
    pzlib_filefunc_def->zerror_file = ferror_file_func;
    pzlib_filefunc_def->opaque = nullptr;
}

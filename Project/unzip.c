// IO for reading .zip files, the subset of minizip's unz* API that KUnzip drives.
//
// This is upstream third-party library code, not a routine reconstructed from the binary. It is
// Gilles Vollant's minizip unzip.c (zlib's contrib/minizip), recovered as the library the way
// NSData+Base64 and ioapi.c are. The shipped KUnzip was built against a hybrid variant: the classic
// 1.01e reader with its 32-bit zlib_filefunc_def I/O table (see ioapi.h) and a two-argument
// internal open, but with the public info structures widened to the Zip64 *64 names, so the two
// size fields and the entry count are ZPOS64_T. The K&R function definitions of the original are
// written here as ANSI prototypes so the file compiles as C23, the password/raw variants KUnzip
// never uses are dropped, and braces are added to the nested if/else chains; the logic is otherwise
// the original.
//
// Condition of use and distribution are the same as zlib.

#include "unzip.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <zlib.h>

#ifndef CASESENSITIVITYDEFAULT_NO
#if !defined(unix) && !defined(CASESENSITIVITYDEFAULT_YES)
#define CASESENSITIVITYDEFAULT_NO
#endif
#endif

#ifndef UNZ_BUFSIZE
#define UNZ_BUFSIZE (16384)
#endif

#ifndef UNZ_MAXFILENAMEINZIP
#define UNZ_MAXFILENAMEINZIP (256)
#endif

#define ALLOC(size) (malloc(size))
#define TRYFREE(p)                                                                                 \
    {                                                                                              \
        if (p) {                                                                                   \
            free(p);                                                                               \
        }                                                                                          \
    }

#define SIZECENTRALDIRITEM (0x2e)
#define SIZEZIPLOCALHEADER (0x1e)

// The tree's ioapi.h omits minizip's ZREAD/ZTELL/ZSEEK/ZCLOSE/ZERROR dispatch macros, so they are
// defined here where the reader needs them. Each forwards through one of the zlib_filefunc_def
// callback pointers, passing the table's opaque cookie as the first argument.
#define ZREAD(filefunc, filestream, buf, size)                                                     \
    ((*((filefunc).zread_file))((filefunc).opaque, filestream, buf, size))
#define ZTELL(filefunc, filestream) ((*((filefunc).ztell_file))((filefunc).opaque, filestream))
#define ZSEEK(filefunc, filestream, pos, mode)                                                     \
    ((*((filefunc).zseek_file))((filefunc).opaque, filestream, pos, mode))
#define ZCLOSE(filefunc, filestream) ((*((filefunc).zclose_file))((filefunc).opaque, filestream))
#define ZERROR(filefunc, filestream) ((*((filefunc).zerror_file))((filefunc).opaque, filestream))

static const char unz_copyright[] =
    " unzip 1.01 Copyright 1998-2004 Gilles Vollant - http://www.winimage.com/zLibDll";

// unz_file_info_internal contains the one piece of per-entry data the public info struct omits.
typedef struct unz_file_info_internal_s {
    uLong offset_curfile; // relative offset of the local header
} unz_file_info_internal;

// file_in_zip_read_info_s holds the state of an entry that is currently open for reading.
typedef struct {
    char *read_buffer;                // internal buffer for compressed data
    z_stream stream;                  // zlib stream structure for inflate
    ZPOS64_T pos_in_zipfile;          // byte position in the zipfile, for seeking
    uLong stream_initialised;         // set once the stream structure is initialised
    ZPOS64_T offset_local_extrafield; // offset of the local extra field
    uInt size_local_extrafield;       // size of the local extra field
    ZPOS64_T pos_local_extrafield;    // read position within the local extra field
    uLong crc32;                      // running CRC-32 of the uncompressed data
    uLong crc32_wait;                 // CRC-32 that must match after decompression
    ZPOS64_T rest_read_compressed;    // compressed bytes still to read
    ZPOS64_T rest_read_uncompressed;  // uncompressed bytes still to produce
    zlib_filefunc_def z_filefunc;     // the archive's I/O callback table
    voidpf filestream;                // the archive's I/O stream cookie
    uLong compression_method;         // compression method (0 == store)
    uLong byte_before_the_zipfile;    // bytes before the zipfile (> 0 for a self-extractor)
    int raw;                          // set when the entry is read without decompression
} file_in_zip_read_info_s;

// unz_s holds the state of an open archive.
typedef struct {
    zlib_filefunc_def z_filefunc;  // the archive's I/O callback table
    voidpf filestream;             // the archive's I/O stream cookie
    unz_global_info64 gi;          // public archive-wide information
    uLong byte_before_the_zipfile; // bytes before the zipfile (> 0 for a self-extractor)
    uLong num_file;                // index of the current entry
    uLong pos_in_central_dir;      // position of the current entry in the central directory
    uLong current_file_ok;         // set when the current entry is usable
    uLong central_pos;             // position of the start of the central directory
    uLong size_central_dir;        // size of the central directory
    uLong offset_central_dir;      // offset of the start of the central directory
    unz_file_info64 cur_file_info; // public info about the current entry
    unz_file_info_internal cur_file_info_internal; // private info about the current entry
    file_in_zip_read_info_s *pfile_in_zip_read;    // state of the entry being decompressed, if any
} unz_s;

// Reads one byte from the stream. Returns UNZ_OK, UNZ_EOF, or UNZ_ERRNO.
static int
unzlocal_getByte(const zlib_filefunc_def *pzlib_filefunc_def, voidpf filestream, int *pi) {
    unsigned char c;
    int err = (int)ZREAD(*pzlib_filefunc_def, filestream, &c, 1);
    if (err == 1) {
        *pi = (int)c;
        return UNZ_OK;
    }
    if (ZERROR(*pzlib_filefunc_def, filestream)) {
        return UNZ_ERRNO;
    }
    return UNZ_EOF;
}

// Reads a two-byte little-endian value from the stream.
static int
unzlocal_getShort(const zlib_filefunc_def *pzlib_filefunc_def, voidpf filestream, uLong *pX) {
    uLong x;
    int i = 0;
    int err;

    err = unzlocal_getByte(pzlib_filefunc_def, filestream, &i);
    x = (uLong)i;

    if (err == UNZ_OK) {
        err = unzlocal_getByte(pzlib_filefunc_def, filestream, &i);
    }
    x += ((uLong)i) << 8;

    if (err == UNZ_OK) {
        *pX = x;
    } else {
        *pX = 0;
    }
    return err;
}

// Reads a four-byte little-endian value from the stream. @ghidraAddress 0x74880
// (unz64local_getLong; the two-byte unzlocal_getShort is inlined into its callers).
static int
unzlocal_getLong(const zlib_filefunc_def *pzlib_filefunc_def, voidpf filestream, uLong *pX) {
    uLong x;
    int i = 0;
    int err;

    err = unzlocal_getByte(pzlib_filefunc_def, filestream, &i);
    x = (uLong)i;

    if (err == UNZ_OK) {
        err = unzlocal_getByte(pzlib_filefunc_def, filestream, &i);
    }
    x += ((uLong)i) << 8;

    if (err == UNZ_OK) {
        err = unzlocal_getByte(pzlib_filefunc_def, filestream, &i);
    }
    x += ((uLong)i) << 16;

    if (err == UNZ_OK) {
        err = unzlocal_getByte(pzlib_filefunc_def, filestream, &i);
    }
    x += ((uLong)i) << 24;

    if (err == UNZ_OK) {
        *pX = x;
    } else {
        *pX = 0;
    }
    return err;
}

// Case-insensitive ASCII comparison, minizip's own strcmpi/strcasecmp.
static int strcmpcasenosensitive_internal(const char *fileName1, const char *fileName2) {
    for (;;) {
        char c1 = *(fileName1++);
        char c2 = *(fileName2++);
        if ((c1 >= 'a') && (c1 <= 'z')) {
            c1 -= 0x20;
        }
        if ((c2 >= 'a') && (c2 <= 'z')) {
            c2 -= 0x20;
        }
        if (c1 == '\0') {
            return ((c2 == '\0') ? 0 : -1);
        }
        if (c2 == '\0') {
            return 1;
        }
        if (c1 < c2) {
            return -1;
        }
        if (c1 > c2) {
            return 1;
        }
    }
}

#ifdef CASESENSITIVITYDEFAULT_NO
#define CASESENSITIVITYDEFAULTVALUE 2
#else
#define CASESENSITIVITYDEFAULTVALUE 1
#endif

// Compares two entry names. iCaseSensitivity: 1 case-sensitive, 2 case-insensitive, 0 the operating
// system default.
static int
unzStringFileNameCompare(const char *fileName1, const char *fileName2, int iCaseSensitivity) {
    if (iCaseSensitivity == 0) {
        iCaseSensitivity = CASESENSITIVITYDEFAULTVALUE;
    }
    if (iCaseSensitivity == 1) {
        return strcmp(fileName1, fileName2);
    }
    return strcmpcasenosensitive_internal(fileName1, fileName2);
}

#ifndef BUFREADCOMMENT
#define BUFREADCOMMENT (0x400)
#endif

// Locates the end-of-central-directory record, at the end of the archive just before the global
// comment. Returns its position, or 0 when it cannot be found.
static uLong unzlocal_SearchCentralDir(const zlib_filefunc_def *pzlib_filefunc_def,
                                       voidpf filestream) {
    unsigned char *buf;
    uLong uSizeFile;
    uLong uBackRead;
    uLong uMaxBack = 0xffff; // maximum size of the global comment
    uLong uPosFound = 0;

    if (ZSEEK(*pzlib_filefunc_def, filestream, 0, ZLIB_FILEFUNC_SEEK_END) != 0) {
        return 0;
    }

    uSizeFile = ZTELL(*pzlib_filefunc_def, filestream);

    if (uMaxBack > uSizeFile) {
        uMaxBack = uSizeFile;
    }

    buf = (unsigned char *)ALLOC(BUFREADCOMMENT + 4);
    if (buf == NULL) {
        return 0;
    }

    uBackRead = 4;
    while (uBackRead < uMaxBack) {
        uLong uReadSize;
        uLong uReadPos;
        int i;
        if (uBackRead + BUFREADCOMMENT > uMaxBack) {
            uBackRead = uMaxBack;
        } else {
            uBackRead += BUFREADCOMMENT;
        }
        uReadPos = uSizeFile - uBackRead;

        uReadSize = ((BUFREADCOMMENT + 4) < (uSizeFile - uReadPos)) ? (BUFREADCOMMENT + 4) :
                                                                      (uSizeFile - uReadPos);
        if (ZSEEK(*pzlib_filefunc_def, filestream, uReadPos, ZLIB_FILEFUNC_SEEK_SET) != 0) {
            break;
        }

        if (ZREAD(*pzlib_filefunc_def, filestream, buf, uReadSize) != uReadSize) {
            break;
        }

        for (i = (int)uReadSize - 3; (i--) > 0;) {
            if (((*(buf + i)) == 0x50) && ((*(buf + i + 1)) == 0x4b) &&
                ((*(buf + i + 2)) == 0x05) && ((*(buf + i + 3)) == 0x06)) {
                uPosFound = uReadPos + i;
                break;
            }
        }

        if (uPosFound != 0) {
            break;
        }
    }
    TRYFREE(buf);
    return uPosFound;
}

unzFile unzOpenInternal(voidpf file, zlib_filefunc_def *pzlib_filefunc_def) {
    unz_s us;
    unz_s *s;
    uLong central_pos;
    uLong uL;

    uLong number_disk;         // number of the current disk; spanning is unsupported, always 0
    uLong number_disk_with_CD; // disk with the central directory; unsupported, always 0
    uLong number_entry_CD;     // total number of entries in the central directory
    uLong number_entry_disk;   // number of entries on this disk

    int err = UNZ_OK;

    if (unz_copyright[0] != ' ') {
        return NULL;
    }

    if (pzlib_filefunc_def == NULL) {
        fill_fopen_filefunc(&us.z_filefunc);
    } else {
        us.z_filefunc = *pzlib_filefunc_def;
    }

    us.filestream =
        (*(us.z_filefunc.zopen_file))(us.z_filefunc.opaque,
                                      (const char *)file,
                                      ZLIB_FILEFUNC_MODE_READ | ZLIB_FILEFUNC_MODE_EXISTING);
    if (us.filestream == NULL) {
        return NULL;
    }

    central_pos = unzlocal_SearchCentralDir(&us.z_filefunc, us.filestream);
    if (central_pos == 0) {
        err = UNZ_ERRNO;
    }

    if (ZSEEK(us.z_filefunc, us.filestream, central_pos, ZLIB_FILEFUNC_SEEK_SET) != 0) {
        err = UNZ_ERRNO;
    }

    // the signature, already checked
    if (unzlocal_getLong(&us.z_filefunc, us.filestream, &uL) != UNZ_OK) {
        err = UNZ_ERRNO;
    }

    // number of this disk
    if (unzlocal_getShort(&us.z_filefunc, us.filestream, &number_disk) != UNZ_OK) {
        err = UNZ_ERRNO;
    }

    // number of the disk with the start of the central directory
    if (unzlocal_getShort(&us.z_filefunc, us.filestream, &number_disk_with_CD) != UNZ_OK) {
        err = UNZ_ERRNO;
    }

    // total number of entries in the central directory on this disk
    if (unzlocal_getShort(&us.z_filefunc, us.filestream, &number_entry_disk) != UNZ_OK) {
        err = UNZ_ERRNO;
    }
    us.gi.number_entry = number_entry_disk;

    // total number of entries in the central directory
    if (unzlocal_getShort(&us.z_filefunc, us.filestream, &number_entry_CD) != UNZ_OK) {
        err = UNZ_ERRNO;
    }

    if ((number_entry_CD != us.gi.number_entry) || (number_disk_with_CD != 0) ||
        (number_disk != 0)) {
        err = UNZ_BADZIPFILE;
    }

    // size of the central directory
    if (unzlocal_getLong(&us.z_filefunc, us.filestream, &us.size_central_dir) != UNZ_OK) {
        err = UNZ_ERRNO;
    }

    // offset of the start of the central directory relative to the starting disk
    if (unzlocal_getLong(&us.z_filefunc, us.filestream, &us.offset_central_dir) != UNZ_OK) {
        err = UNZ_ERRNO;
    }

    // zipfile comment length
    if (unzlocal_getShort(&us.z_filefunc, us.filestream, &us.gi.size_comment) != UNZ_OK) {
        err = UNZ_ERRNO;
    }

    if ((central_pos < us.offset_central_dir + us.size_central_dir) && (err == UNZ_OK)) {
        err = UNZ_BADZIPFILE;
    }

    if (err != UNZ_OK) {
        ZCLOSE(us.z_filefunc, us.filestream);
        return NULL;
    }

    us.byte_before_the_zipfile = central_pos - (us.offset_central_dir + us.size_central_dir);
    us.central_pos = central_pos;
    us.pfile_in_zip_read = NULL;

    s = (unz_s *)ALLOC(sizeof(unz_s));
    if (s == NULL) {
        ZCLOSE(us.z_filefunc, us.filestream);
        return NULL;
    }
    *s = us;
    unzGoToFirstFile((unzFile)s);
    return (unzFile)s;
}

unzFile unzOpen(const char *path) {
    return unzOpenInternal((voidpf)path, NULL);
}

int unzClose(unzFile file) {
    unz_s *s;
    if (file == NULL) {
        return UNZ_PARAMERROR;
    }
    s = (unz_s *)file;

    if (s->pfile_in_zip_read != NULL) {
        unzCloseCurrentFile(file);
    }

    ZCLOSE(s->z_filefunc, s->filestream);
    TRYFREE(s);
    return UNZ_OK;
}

int unzGetGlobalInfo64(unzFile file, unz_global_info64 *pglobal_info) {
    unz_s *s;
    if (file == NULL) {
        return UNZ_PARAMERROR;
    }
    s = (unz_s *)file;
    *pglobal_info = s->gi;
    return UNZ_OK;
}

// Translates a DOS-format date/time into a tm_unz.
static void unzlocal_DosDateToTmuDate(uLong ulDosDate, tm_unz *ptm) {
    uLong uDate;
    uDate = (uLong)(ulDosDate >> 16);
    ptm->tm_mday = (uInt)(uDate & 0x1f);
    ptm->tm_mon = (uInt)((((uDate) & 0x1E0) / 0x20) - 1);
    ptm->tm_year = (uInt)(((uDate & 0x0FE00) / 0x0200) + 1980);

    ptm->tm_hour = (uInt)((ulDosDate & 0xF800) / 0x800);
    ptm->tm_min = (uInt)((ulDosDate & 0x7E0) / 0x20);
    ptm->tm_sec = (uInt)(2 * (ulDosDate & 0x1f));
}

// Reads the current entry's central-directory header into pfile_info (and pfile_info_internal), and
// optionally copies the name, extra field, and comment into the caller's buffers.
// @ghidraAddress 0x74bd0 (unz64local_GetCurrentFileInfoInternal)
static int unzlocal_GetCurrentFileInfoInternal(unzFile file,
                                               unz_file_info64 *pfile_info,
                                               unz_file_info_internal *pfile_info_internal,
                                               char *szFileName,
                                               uLong fileNameBufferSize,
                                               void *extraField,
                                               uLong extraFieldBufferSize,
                                               char *szComment,
                                               uLong commentBufferSize) {
    unz_s *s;
    unz_file_info64 file_info;
    unz_file_info_internal file_info_internal;
    int err = UNZ_OK;
    uLong uMagic;
    long lSeek = 0;
    uLong uL;

    if (file == NULL) {
        return UNZ_PARAMERROR;
    }
    s = (unz_s *)file;
    if (ZSEEK(s->z_filefunc,
              s->filestream,
              s->pos_in_central_dir + s->byte_before_the_zipfile,
              ZLIB_FILEFUNC_SEEK_SET) != 0) {
        err = UNZ_ERRNO;
    }

    // we check the magic
    if (err == UNZ_OK) {
        if (unzlocal_getLong(&s->z_filefunc, s->filestream, &uMagic) != UNZ_OK) {
            err = UNZ_ERRNO;
        } else if (uMagic != 0x02014b50) {
            err = UNZ_BADZIPFILE;
        }
    }

    if (unzlocal_getShort(&s->z_filefunc, s->filestream, &file_info.version) != UNZ_OK) {
        err = UNZ_ERRNO;
    }

    if (unzlocal_getShort(&s->z_filefunc, s->filestream, &file_info.version_needed) != UNZ_OK) {
        err = UNZ_ERRNO;
    }

    if (unzlocal_getShort(&s->z_filefunc, s->filestream, &file_info.flag) != UNZ_OK) {
        err = UNZ_ERRNO;
    }

    if (unzlocal_getShort(&s->z_filefunc, s->filestream, &file_info.compression_method) != UNZ_OK) {
        err = UNZ_ERRNO;
    }

    if (unzlocal_getLong(&s->z_filefunc, s->filestream, &file_info.dosDate) != UNZ_OK) {
        err = UNZ_ERRNO;
    }

    unzlocal_DosDateToTmuDate(file_info.dosDate, &file_info.tmu_date);

    if (unzlocal_getLong(&s->z_filefunc, s->filestream, &file_info.crc) != UNZ_OK) {
        err = UNZ_ERRNO;
    }

    if (unzlocal_getLong(&s->z_filefunc, s->filestream, &uL) != UNZ_OK) {
        err = UNZ_ERRNO;
    }
    file_info.compressed_size = uL;

    if (unzlocal_getLong(&s->z_filefunc, s->filestream, &uL) != UNZ_OK) {
        err = UNZ_ERRNO;
    }
    file_info.uncompressed_size = uL;

    if (unzlocal_getShort(&s->z_filefunc, s->filestream, &file_info.size_filename) != UNZ_OK) {
        err = UNZ_ERRNO;
    }

    if (unzlocal_getShort(&s->z_filefunc, s->filestream, &file_info.size_file_extra) != UNZ_OK) {
        err = UNZ_ERRNO;
    }

    if (unzlocal_getShort(&s->z_filefunc, s->filestream, &file_info.size_file_comment) != UNZ_OK) {
        err = UNZ_ERRNO;
    }

    if (unzlocal_getShort(&s->z_filefunc, s->filestream, &file_info.disk_num_start) != UNZ_OK) {
        err = UNZ_ERRNO;
    }

    if (unzlocal_getShort(&s->z_filefunc, s->filestream, &file_info.internal_fa) != UNZ_OK) {
        err = UNZ_ERRNO;
    }

    if (unzlocal_getLong(&s->z_filefunc, s->filestream, &file_info.external_fa) != UNZ_OK) {
        err = UNZ_ERRNO;
    }

    if (unzlocal_getLong(&s->z_filefunc, s->filestream, &file_info_internal.offset_curfile) !=
        UNZ_OK) {
        err = UNZ_ERRNO;
    }

    lSeek += file_info.size_filename;
    if ((err == UNZ_OK) && (szFileName != NULL)) {
        uLong uSizeRead;
        if (file_info.size_filename < fileNameBufferSize) {
            *(szFileName + file_info.size_filename) = '\0';
            uSizeRead = file_info.size_filename;
        } else {
            uSizeRead = fileNameBufferSize;
        }

        if ((file_info.size_filename > 0) && (fileNameBufferSize > 0)) {
            if (ZREAD(s->z_filefunc, s->filestream, szFileName, uSizeRead) != uSizeRead) {
                err = UNZ_ERRNO;
            }
        }
        lSeek -= uSizeRead;
    }

    if ((err == UNZ_OK) && (extraField != NULL)) {
        uLong uSizeRead;
        if (file_info.size_file_extra < extraFieldBufferSize) {
            uSizeRead = file_info.size_file_extra;
        } else {
            uSizeRead = extraFieldBufferSize;
        }

        if (lSeek != 0) {
            if (ZSEEK(s->z_filefunc, s->filestream, lSeek, ZLIB_FILEFUNC_SEEK_CUR) == 0) {
                lSeek = 0;
            } else {
                err = UNZ_ERRNO;
            }
        }
        if ((file_info.size_file_extra > 0) && (extraFieldBufferSize > 0)) {
            if (ZREAD(s->z_filefunc, s->filestream, extraField, uSizeRead) != uSizeRead) {
                err = UNZ_ERRNO;
            }
        }
        lSeek += file_info.size_file_extra - uSizeRead;
    } else {
        lSeek += file_info.size_file_extra;
    }

    if ((err == UNZ_OK) && (szComment != NULL)) {
        uLong uSizeRead;
        if (file_info.size_file_comment < commentBufferSize) {
            *(szComment + file_info.size_file_comment) = '\0';
            uSizeRead = file_info.size_file_comment;
        } else {
            uSizeRead = commentBufferSize;
        }

        if (lSeek != 0) {
            if (ZSEEK(s->z_filefunc, s->filestream, lSeek, ZLIB_FILEFUNC_SEEK_CUR) == 0) {
                lSeek = 0;
            } else {
                err = UNZ_ERRNO;
            }
        }
        if ((file_info.size_file_comment > 0) && (commentBufferSize > 0)) {
            if (ZREAD(s->z_filefunc, s->filestream, szComment, uSizeRead) != uSizeRead) {
                err = UNZ_ERRNO;
            }
        }
        lSeek += file_info.size_file_comment - uSizeRead;
    } else {
        lSeek += file_info.size_file_comment;
    }
    // lSeek is maintained for the caller-buffer cases; it is otherwise unused here.
    (void)lSeek;

    if ((err == UNZ_OK) && (pfile_info != NULL)) {
        *pfile_info = file_info;
    }

    if ((err == UNZ_OK) && (pfile_info_internal != NULL)) {
        *pfile_info_internal = file_info_internal;
    }

    return err;
}

int unzGetCurrentFileInfo64(unzFile file,
                            unz_file_info64 *pfile_info,
                            char *szFileName,
                            uLong fileNameBufferSize,
                            void *extraField,
                            uLong extraFieldBufferSize,
                            char *szComment,
                            uLong commentBufferSize) {
    return unzlocal_GetCurrentFileInfoInternal(file,
                                               pfile_info,
                                               NULL,
                                               szFileName,
                                               fileNameBufferSize,
                                               extraField,
                                               extraFieldBufferSize,
                                               szComment,
                                               commentBufferSize);
}

int unzGoToFirstFile(unzFile file) {
    int err;
    unz_s *s;
    if (file == NULL) {
        return UNZ_PARAMERROR;
    }
    s = (unz_s *)file;
    s->pos_in_central_dir = s->offset_central_dir;
    s->num_file = 0;
    err = unzlocal_GetCurrentFileInfoInternal(
        file, &s->cur_file_info, &s->cur_file_info_internal, NULL, 0, NULL, 0, NULL, 0);
    s->current_file_ok = (err == UNZ_OK);
    return err;
}

int unzGoToNextFile(unzFile file) {
    unz_s *s;
    int err;

    if (file == NULL) {
        return UNZ_PARAMERROR;
    }
    s = (unz_s *)file;
    if (!s->current_file_ok) {
        return UNZ_END_OF_LIST_OF_FILE;
    }
    if (s->gi.number_entry != 0xffff) { // 2^16 files overflow hack
        if (s->num_file + 1 == s->gi.number_entry) {
            return UNZ_END_OF_LIST_OF_FILE;
        }
    }

    s->pos_in_central_dir += SIZECENTRALDIRITEM + s->cur_file_info.size_filename +
                             s->cur_file_info.size_file_extra + s->cur_file_info.size_file_comment;
    s->num_file++;
    err = unzlocal_GetCurrentFileInfoInternal(
        file, &s->cur_file_info, &s->cur_file_info_internal, NULL, 0, NULL, 0, NULL, 0);
    s->current_file_ok = (err == UNZ_OK);
    return err;
}

int unzLocateFile(unzFile file, const char *szFileName, int iCaseSensitivity) {
    unz_s *s;
    int err;

    // The current position is saved so it can be restored on failure.
    unz_file_info64 cur_file_infoSaved;
    unz_file_info_internal cur_file_info_internalSaved;
    uLong num_fileSaved;
    uLong pos_in_central_dirSaved;

    if (file == NULL) {
        return UNZ_PARAMERROR;
    }

    if (strlen(szFileName) >= UNZ_MAXFILENAMEINZIP) {
        return UNZ_PARAMERROR;
    }

    s = (unz_s *)file;
    if (!s->current_file_ok) {
        return UNZ_END_OF_LIST_OF_FILE;
    }

    // Save the current state.
    num_fileSaved = s->num_file;
    pos_in_central_dirSaved = s->pos_in_central_dir;
    cur_file_infoSaved = s->cur_file_info;
    cur_file_info_internalSaved = s->cur_file_info_internal;

    err = unzGoToFirstFile(file);

    while (err == UNZ_OK) {
        char szCurrentFileName[UNZ_MAXFILENAMEINZIP + 1];
        err = unzGetCurrentFileInfo64(
            file, NULL, szCurrentFileName, sizeof(szCurrentFileName) - 1, NULL, 0, NULL, 0);
        if (err == UNZ_OK) {
            if (unzStringFileNameCompare(szCurrentFileName, szFileName, iCaseSensitivity) == 0) {
                return UNZ_OK;
            }
            err = unzGoToNextFile(file);
        }
    }

    // We failed, so restore the state of the current entry to where we were.
    s->num_file = num_fileSaved;
    s->pos_in_central_dir = pos_in_central_dirSaved;
    s->cur_file_info = cur_file_infoSaved;
    s->cur_file_info_internal = cur_file_info_internalSaved;
    return err;
}

// Reads the current entry's local header, checks it for coherency against the central-directory
// info, and reports the size of the variable-length local fields.
static int unzlocal_CheckCurrentFileCoherencyHeader(unz_s *s,
                                                    uInt *piSizeVar,
                                                    ZPOS64_T *poffset_local_extrafield,
                                                    uInt *psize_local_extrafield) {
    uLong uMagic;
    uLong uData;
    uLong uFlags;
    uLong size_filename;
    uLong size_extra_field;
    int err = UNZ_OK;

    *piSizeVar = 0;
    *poffset_local_extrafield = 0;
    *psize_local_extrafield = 0;

    if (ZSEEK(s->z_filefunc,
              s->filestream,
              s->cur_file_info_internal.offset_curfile + s->byte_before_the_zipfile,
              ZLIB_FILEFUNC_SEEK_SET) != 0) {
        return UNZ_ERRNO;
    }

    if (err == UNZ_OK) {
        if (unzlocal_getLong(&s->z_filefunc, s->filestream, &uMagic) != UNZ_OK) {
            err = UNZ_ERRNO;
        } else if (uMagic != 0x04034b50) {
            err = UNZ_BADZIPFILE;
        }
    }

    if (unzlocal_getShort(&s->z_filefunc, s->filestream, &uData) != UNZ_OK) {
        err = UNZ_ERRNO;
    }

    if (unzlocal_getShort(&s->z_filefunc, s->filestream, &uFlags) != UNZ_OK) {
        err = UNZ_ERRNO;
    }

    if (unzlocal_getShort(&s->z_filefunc, s->filestream, &uData) != UNZ_OK) {
        err = UNZ_ERRNO;
    } else if ((err == UNZ_OK) && (uData != s->cur_file_info.compression_method)) {
        err = UNZ_BADZIPFILE;
    }

    if ((err == UNZ_OK) && (s->cur_file_info.compression_method != 0) &&
        (s->cur_file_info.compression_method != Z_DEFLATED)) {
        err = UNZ_BADZIPFILE;
    }

    if (unzlocal_getLong(&s->z_filefunc, s->filestream, &uData) != UNZ_OK) { // date/time
        err = UNZ_ERRNO;
    }

    if (unzlocal_getLong(&s->z_filefunc, s->filestream, &uData) != UNZ_OK) { // crc
        err = UNZ_ERRNO;
    } else if ((err == UNZ_OK) && (uData != s->cur_file_info.crc) && ((uFlags & 8) == 0)) {
        err = UNZ_BADZIPFILE;
    }

    if (unzlocal_getLong(&s->z_filefunc, s->filestream, &uData) != UNZ_OK) { // compressed size
        err = UNZ_ERRNO;
    } else if ((err == UNZ_OK) && (uData != s->cur_file_info.compressed_size) &&
               ((uFlags & 8) == 0)) {
        err = UNZ_BADZIPFILE;
    }

    if (unzlocal_getLong(&s->z_filefunc, s->filestream, &uData) != UNZ_OK) { // uncompressed size
        err = UNZ_ERRNO;
    } else if ((err == UNZ_OK) && (uData != s->cur_file_info.uncompressed_size) &&
               ((uFlags & 8) == 0)) {
        err = UNZ_BADZIPFILE;
    }

    if (unzlocal_getShort(&s->z_filefunc, s->filestream, &size_filename) != UNZ_OK) {
        err = UNZ_ERRNO;
    } else if ((err == UNZ_OK) && (size_filename != s->cur_file_info.size_filename)) {
        err = UNZ_BADZIPFILE;
    }

    *piSizeVar += (uInt)size_filename;

    if (unzlocal_getShort(&s->z_filefunc, s->filestream, &size_extra_field) != UNZ_OK) {
        err = UNZ_ERRNO;
    }
    *poffset_local_extrafield =
        s->cur_file_info_internal.offset_curfile + SIZEZIPLOCALHEADER + size_filename;
    *psize_local_extrafield = (uInt)size_extra_field;

    *piSizeVar += (uInt)size_extra_field;

    return err;
}

// The binary's unzOpenCurrentFile (0x75df0) is a thin wrapper over the fuller unzOpenCurrentFile3
// (0x75788); the password/raw parameters KUnzip never uses are folded away here.
int unzOpenCurrentFile(unzFile file) {
    int err = UNZ_OK;
    uInt iSizeVar;
    unz_s *s;
    file_in_zip_read_info_s *pfile_in_zip_read_info;
    ZPOS64_T offset_local_extrafield; // offset of the local extra field
    uInt size_local_extrafield;       // size of the local extra field

    if (file == NULL) {
        return UNZ_PARAMERROR;
    }
    s = (unz_s *)file;
    if (!s->current_file_ok) {
        return UNZ_PARAMERROR;
    }

    if (s->pfile_in_zip_read != NULL) {
        unzCloseCurrentFile(file);
    }

    if (unzlocal_CheckCurrentFileCoherencyHeader(
            s, &iSizeVar, &offset_local_extrafield, &size_local_extrafield) != UNZ_OK) {
        return UNZ_BADZIPFILE;
    }

    pfile_in_zip_read_info = (file_in_zip_read_info_s *)ALLOC(sizeof(file_in_zip_read_info_s));
    if (pfile_in_zip_read_info == NULL) {
        return UNZ_INTERNALERROR;
    }

    pfile_in_zip_read_info->read_buffer = (char *)ALLOC(UNZ_BUFSIZE);
    pfile_in_zip_read_info->offset_local_extrafield = offset_local_extrafield;
    pfile_in_zip_read_info->size_local_extrafield = size_local_extrafield;
    pfile_in_zip_read_info->pos_local_extrafield = 0;
    pfile_in_zip_read_info->raw = 0;

    if (pfile_in_zip_read_info->read_buffer == NULL) {
        TRYFREE(pfile_in_zip_read_info);
        return UNZ_INTERNALERROR;
    }

    pfile_in_zip_read_info->stream_initialised = 0;

    if ((s->cur_file_info.compression_method != 0) &&
        (s->cur_file_info.compression_method != Z_DEFLATED)) {
        err = UNZ_BADZIPFILE;
    }

    pfile_in_zip_read_info->crc32_wait = s->cur_file_info.crc;
    pfile_in_zip_read_info->crc32 = 0;
    pfile_in_zip_read_info->compression_method = s->cur_file_info.compression_method;
    pfile_in_zip_read_info->filestream = s->filestream;
    pfile_in_zip_read_info->z_filefunc = s->z_filefunc;
    pfile_in_zip_read_info->byte_before_the_zipfile = s->byte_before_the_zipfile;

    pfile_in_zip_read_info->stream.total_out = 0;

    if (s->cur_file_info.compression_method == Z_DEFLATED) {
        pfile_in_zip_read_info->stream.zalloc = (alloc_func)0;
        pfile_in_zip_read_info->stream.zfree = (free_func)0;
        pfile_in_zip_read_info->stream.opaque = (voidpf)0;
        pfile_in_zip_read_info->stream.next_in = (voidpf)0;
        pfile_in_zip_read_info->stream.avail_in = 0;

        err = inflateInit2(&pfile_in_zip_read_info->stream, -MAX_WBITS);
        if (err == Z_OK) {
            pfile_in_zip_read_info->stream_initialised = 1;
        } else {
            TRYFREE(pfile_in_zip_read_info->read_buffer);
            TRYFREE(pfile_in_zip_read_info);
            return err;
        }
        // windowBits is passed negative to tell inflate there is no zlib header. In unzip we do not
        // require Z_STREAM_END, because the compressed and uncompressed sizes are both known.
    }
    pfile_in_zip_read_info->rest_read_compressed = s->cur_file_info.compressed_size;
    pfile_in_zip_read_info->rest_read_uncompressed = s->cur_file_info.uncompressed_size;

    pfile_in_zip_read_info->pos_in_zipfile =
        s->cur_file_info_internal.offset_curfile + SIZEZIPLOCALHEADER + iSizeVar;

    pfile_in_zip_read_info->stream.avail_in = (uInt)0;

    s->pfile_in_zip_read = pfile_in_zip_read_info;

    return UNZ_OK;
}

int unzReadCurrentFile(unzFile file, void *buf, unsigned len) {
    int err = UNZ_OK;
    uInt iRead = 0;
    unz_s *s;
    file_in_zip_read_info_s *pfile_in_zip_read_info;
    if (file == NULL) {
        return UNZ_PARAMERROR;
    }
    s = (unz_s *)file;
    pfile_in_zip_read_info = s->pfile_in_zip_read;

    if (pfile_in_zip_read_info == NULL) {
        return UNZ_PARAMERROR;
    }

    if (pfile_in_zip_read_info->read_buffer == NULL) {
        return UNZ_END_OF_LIST_OF_FILE;
    }
    if (len == 0) {
        return 0;
    }

    pfile_in_zip_read_info->stream.next_out = (Bytef *)buf;

    pfile_in_zip_read_info->stream.avail_out = (uInt)len;

    if ((len > pfile_in_zip_read_info->rest_read_uncompressed) &&
        (!(pfile_in_zip_read_info->raw))) {
        pfile_in_zip_read_info->stream.avail_out =
            (uInt)pfile_in_zip_read_info->rest_read_uncompressed;
    }

    if ((len >
         pfile_in_zip_read_info->rest_read_compressed + pfile_in_zip_read_info->stream.avail_in) &&
        (pfile_in_zip_read_info->raw)) {
        pfile_in_zip_read_info->stream.avail_out =
            (uInt)pfile_in_zip_read_info->rest_read_compressed +
            pfile_in_zip_read_info->stream.avail_in;
    }

    while (pfile_in_zip_read_info->stream.avail_out > 0) {
        if ((pfile_in_zip_read_info->stream.avail_in == 0) &&
            (pfile_in_zip_read_info->rest_read_compressed > 0)) {
            uInt uReadThis = UNZ_BUFSIZE;
            if (pfile_in_zip_read_info->rest_read_compressed < uReadThis) {
                uReadThis = (uInt)pfile_in_zip_read_info->rest_read_compressed;
            }
            if (uReadThis == 0) {
                return UNZ_EOF;
            }
            if (ZSEEK(pfile_in_zip_read_info->z_filefunc,
                      pfile_in_zip_read_info->filestream,
                      pfile_in_zip_read_info->pos_in_zipfile +
                          pfile_in_zip_read_info->byte_before_the_zipfile,
                      ZLIB_FILEFUNC_SEEK_SET) != 0) {
                return UNZ_ERRNO;
            }
            if (ZREAD(pfile_in_zip_read_info->z_filefunc,
                      pfile_in_zip_read_info->filestream,
                      pfile_in_zip_read_info->read_buffer,
                      uReadThis) != uReadThis) {
                return UNZ_ERRNO;
            }

            pfile_in_zip_read_info->pos_in_zipfile += uReadThis;

            pfile_in_zip_read_info->rest_read_compressed -= uReadThis;

            pfile_in_zip_read_info->stream.next_in = (Bytef *)pfile_in_zip_read_info->read_buffer;
            pfile_in_zip_read_info->stream.avail_in = (uInt)uReadThis;
        }

        if ((pfile_in_zip_read_info->compression_method == 0) || (pfile_in_zip_read_info->raw)) {
            uInt uDoCopy;
            uInt i;

            if ((pfile_in_zip_read_info->stream.avail_in == 0) &&
                (pfile_in_zip_read_info->rest_read_compressed == 0)) {
                return (iRead == 0) ? UNZ_EOF : (int)iRead;
            }

            if (pfile_in_zip_read_info->stream.avail_out <
                pfile_in_zip_read_info->stream.avail_in) {
                uDoCopy = pfile_in_zip_read_info->stream.avail_out;
            } else {
                uDoCopy = pfile_in_zip_read_info->stream.avail_in;
            }

            for (i = 0; i < uDoCopy; i++) {
                *(pfile_in_zip_read_info->stream.next_out + i) =
                    *(pfile_in_zip_read_info->stream.next_in + i);
            }

            pfile_in_zip_read_info->crc32 = crc32(
                pfile_in_zip_read_info->crc32, pfile_in_zip_read_info->stream.next_out, uDoCopy);
            pfile_in_zip_read_info->rest_read_uncompressed -= uDoCopy;
            pfile_in_zip_read_info->stream.avail_in -= uDoCopy;
            pfile_in_zip_read_info->stream.avail_out -= uDoCopy;
            pfile_in_zip_read_info->stream.next_out += uDoCopy;
            pfile_in_zip_read_info->stream.next_in += uDoCopy;
            pfile_in_zip_read_info->stream.total_out += uDoCopy;
            iRead += uDoCopy;
        } else {
            uLong uTotalOutBefore;
            uLong uTotalOutAfter;
            const Bytef *bufBefore;
            uLong uOutThis;
            int flush = Z_SYNC_FLUSH;

            uTotalOutBefore = pfile_in_zip_read_info->stream.total_out;
            bufBefore = pfile_in_zip_read_info->stream.next_out;

            err = inflate(&pfile_in_zip_read_info->stream, flush);

            if ((err >= 0) && (pfile_in_zip_read_info->stream.msg != NULL)) {
                err = Z_DATA_ERROR;
            }

            uTotalOutAfter = pfile_in_zip_read_info->stream.total_out;
            uOutThis = uTotalOutAfter - uTotalOutBefore;

            pfile_in_zip_read_info->crc32 =
                crc32(pfile_in_zip_read_info->crc32, bufBefore, (uInt)(uOutThis));

            pfile_in_zip_read_info->rest_read_uncompressed -= uOutThis;

            iRead += (uInt)(uTotalOutAfter - uTotalOutBefore);

            if (err == Z_STREAM_END) {
                return (iRead == 0) ? UNZ_EOF : (int)iRead;
            }
            if (err != Z_OK) {
                break;
            }
        }
    }

    if (err == Z_OK) {
        return (int)iRead;
    }
    return err;
}

int unzCloseCurrentFile(unzFile file) {
    int err = UNZ_OK;

    unz_s *s;
    file_in_zip_read_info_s *pfile_in_zip_read_info;
    if (file == NULL) {
        return UNZ_PARAMERROR;
    }
    s = (unz_s *)file;
    pfile_in_zip_read_info = s->pfile_in_zip_read;

    if (pfile_in_zip_read_info == NULL) {
        return UNZ_PARAMERROR;
    }

    if ((pfile_in_zip_read_info->rest_read_uncompressed == 0) && (!pfile_in_zip_read_info->raw)) {
        if (pfile_in_zip_read_info->crc32 != pfile_in_zip_read_info->crc32_wait) {
            err = UNZ_CRCERROR;
        }
    }

    TRYFREE(pfile_in_zip_read_info->read_buffer);
    pfile_in_zip_read_info->read_buffer = NULL;
    if (pfile_in_zip_read_info->stream_initialised) {
        inflateEnd(&pfile_in_zip_read_info->stream);
    }

    pfile_in_zip_read_info->stream_initialised = 0;
    TRYFREE(pfile_in_zip_read_info);

    s->pfile_in_zip_read = NULL;

    return err;
}

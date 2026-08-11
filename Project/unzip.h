/** @file
 * IO for reading .zip files, the subset of minizip's @c unz* API that @c KUnzip drives.
 *
 * This is upstream third-party library code, not a routine reconstructed from the binary: it is
 * Gilles Vollant's minizip @c unzip.c/unzip.h (the version bundled with zlib's
 * @c contrib/minizip), recovered as the library the way @c NSData+Base64 and @c ioapi.c are. The
 * shipped @c KUnzip was built against a hybrid minizip variant — the classic 1.01e reader with its
 * 32-bit @c zlib_filefunc_def I/O table (see @c ioapi.h) and a two-argument internal open, but with
 * the public per-entry and archive-wide info structures widened to the Zip64 @c *64 names. Only the
 * entry points @c KUnzip references are declared. The I/O callback table, the @c voidpf opaque, and
 * @c uLong come from @c ioapi.h.
 *
 * Condition of use and distribution are the same as zlib.
 */

#ifndef UNZIP_H
#define UNZIP_H

#include "ioapi.h"

#ifdef __cplusplus
extern "C" {
#endif

/** @brief minizip's opaque unzip archive handle. */
typedef void *unzFile;

/** @brief minizip's 64-bit file-position type (zlib's @c ZPOS64_T). */
typedef unsigned long long ZPOS64_T;

/** UNZ_OK: the operation succeeded. */
#define UNZ_OK (0)
/** UNZ_END_OF_LIST_OF_FILE: the directory walk passed the last entry. */
#define UNZ_END_OF_LIST_OF_FILE (-100)
/** UNZ_ERRNO: an I/O callback failed. */
#define UNZ_ERRNO (Z_ERRNO)
/** UNZ_EOF: the end of the current entry's data was reached. */
#define UNZ_EOF (0)
/** UNZ_PARAMERROR: an argument was invalid. */
#define UNZ_PARAMERROR (-102)
/** UNZ_BADZIPFILE: the archive is not a valid .zip. */
#define UNZ_BADZIPFILE (-103)
/** UNZ_INTERNALERROR: an internal allocation or state error occurred. */
#define UNZ_INTERNALERROR (-104)
/** UNZ_CRCERROR: the decompressed data failed its CRC check. */
#define UNZ_CRCERROR (-105)

/** @brief An entry's last-modified date and time, decoded from the DOS date field. */
typedef struct tm_unz_s {
    unsigned int tm_sec;  /*!< Seconds after the minute, [0, 59]. */
    unsigned int tm_min;  /*!< Minutes after the hour, [0, 59]. */
    unsigned int tm_hour; /*!< Hours since midnight, [0, 23]. */
    unsigned int tm_mday; /*!< Day of the month, [1, 31]. */
    unsigned int tm_mon;  /*!< Months since January, [0, 11]. */
    unsigned int tm_year; /*!< Year, [1980, 2044]. */
} tm_unz;

/** @brief Archive-wide information taken from the end-of-central-directory record. */
typedef struct unz_global_info64_s {
    ZPOS64_T number_entry; /*!< The total number of entries in the central directory. */
    uLong size_comment;    /*!< The size of the archive's global comment. */
} unz_global_info64;

/** @brief Per-entry information taken from the entry's central-directory header. */
typedef struct unz_file_info64_s {
    uLong version;              /*!< The version that made the entry. */
    uLong version_needed;       /*!< The minimum version needed to extract the entry. */
    uLong flag;                 /*!< The general-purpose bit flag. */
    uLong compression_method;   /*!< The compression method. */
    uLong dosDate;              /*!< The last-modified date and time, in DOS format. */
    uLong crc;                  /*!< The CRC-32 of the uncompressed data. */
    ZPOS64_T compressed_size;   /*!< The compressed size in bytes. */
    ZPOS64_T uncompressed_size; /*!< The uncompressed size in bytes. */
    uLong size_filename;        /*!< The length of the entry's name. */
    uLong size_file_extra;      /*!< The length of the entry's extra field. */
    uLong size_file_comment;    /*!< The length of the entry's comment. */
    uLong disk_num_start;       /*!< The number of the disk the entry starts on. */
    uLong internal_fa;          /*!< The internal file attributes. */
    uLong external_fa;          /*!< The external file attributes. */
    tm_unz tmu_date;            /*!< The decoded last-modified date and time. */
} unz_file_info64;

/**
 * @brief Opens a .zip archive at a path using the default stdio I/O callbacks.
 *
 * @param path The archive's path.
 * @return The opened archive handle, or @c nullptr when the file does not exist or is not a valid
 *         archive.
 * @ghidraAddress 0x74a48
 */
unzFile unzOpen(const char *path);

/**
 * @brief Opens a .zip archive using a caller-supplied I/O callback table.
 *
 * @param file The value passed through to the table's @c zopen_file callback as its @c filename.
 * @param pzlib_filefunc_def The I/O callback table, or @c nullptr to use the default stdio table.
 * @return The opened archive handle, or @c nullptr when the archive cannot be opened.
 * @ghidraAddress 0x74228
 */
unzFile unzOpenInternal(voidpf file, zlib_filefunc_def *pzlib_filefunc_def);

/**
 * @brief Closes an archive opened with @c unzOpen or @c unzOpenInternal.
 *
 * @param file The archive handle.
 * @return @c UNZ_OK on success, or @c UNZ_PARAMERROR when @p file is @c nullptr.
 * @ghidraAddress 0x74a50
 */
int unzClose(unzFile file);

/**
 * @brief Writes the archive-wide information into @p pglobal_info.
 *
 * @param file The archive handle.
 * @param pglobal_info The structure to fill; needs no preparation.
 * @return @c UNZ_OK on success, or @c UNZ_PARAMERROR when @p file is @c nullptr.
 * @ghidraAddress 0x74b64
 */
int unzGetGlobalInfo64(unzFile file, unz_global_info64 *pglobal_info);

/**
 * @brief Makes the first entry the current entry.
 *
 * @param file The archive handle.
 * @return @c UNZ_OK on success.
 * @ghidraAddress 0x749dc
 */
int unzGoToFirstFile(unzFile file);

/**
 * @brief Makes the next entry the current entry.
 *
 * @param file The archive handle.
 * @return @c UNZ_OK on success, or @c UNZ_END_OF_LIST_OF_FILE past the last entry.
 * @ghidraAddress 0x753c8
 */
int unzGoToNextFile(unzFile file);

/**
 * @brief Locates an entry by name and makes it the current entry.
 *
 * @param file The archive handle.
 * @param szFileName The entry name to find.
 * @param iCaseSensitivity 1 for a case-sensitive match, 2 for case-insensitive, 0 for the operating
 *        system default.
 * @return @c UNZ_OK when the entry is found, or @c UNZ_END_OF_LIST_OF_FILE when it is not.
 * @ghidraAddress 0x75478
 */
int unzLocateFile(unzFile file, const char *szFileName, int iCaseSensitivity);

/**
 * @brief Reads the current entry's information and, optionally, its name, extra field, and comment.
 *
 * @param file The archive handle.
 * @param pfile_info The structure to fill, or @c nullptr.
 * @param szFileName A buffer for the entry name, or @c nullptr.
 * @param fileNameBufferSize The size of @p szFileName.
 * @param extraField A buffer for the central-header extra field, or @c nullptr.
 * @param extraFieldBufferSize The size of @p extraField.
 * @param szComment A buffer for the entry comment, or @c nullptr.
 * @param commentBufferSize The size of @p szComment.
 * @return @c UNZ_OK on success.
 * @ghidraAddress 0x74b84
 */
int unzGetCurrentFileInfo64(unzFile file,
                            unz_file_info64 *pfile_info,
                            char *szFileName,
                            uLong fileNameBufferSize,
                            void *extraField,
                            uLong extraFieldBufferSize,
                            char *szComment,
                            uLong commentBufferSize);

/**
 * @brief Opens the current entry for reading its decompressed data.
 *
 * @param file The archive handle.
 * @return @c UNZ_OK on success.
 * @ghidraAddress 0x75df0
 */
int unzOpenCurrentFile(unzFile file);

/**
 * @brief Reads decompressed bytes from the current entry.
 *
 * @param file The archive handle.
 * @param buf The destination buffer.
 * @param len The size of @p buf.
 * @return The number of bytes copied, 0 at the end of the entry, or a negative error code.
 * @ghidraAddress 0x75e04
 */
int unzReadCurrentFile(unzFile file, void *buf, unsigned len);

/**
 * @brief Closes the current entry opened with @c unzOpenCurrentFile.
 *
 * @param file The archive handle.
 * @return @c UNZ_OK on success, or @c UNZ_CRCERROR when the whole entry was read and its CRC did
 * not match.
 * @ghidraAddress 0x74ac8
 */
int unzCloseCurrentFile(unzFile file);

#ifdef __cplusplus
}
#endif

#endif

// code: language=C
// kate: hl C;
// vim: set ft=c :

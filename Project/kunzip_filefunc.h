/** @file
 * KUnzip's own minizip I/O callback sets.
 *
 * Reconstructed from Ghidra program Jubeat (image base 0x100000000). All @ghidraAddress values are
 * offsets relative to that image base.
 *
 * Two @c zlib_filefunc_def implementations back @c KUnzip's archive reading. Both take the @c
 * KUnzip itself as the @c opaque cookie and ignore the @c stream argument: the file-handle set
 * reads through the object's @c fileHandle (installed by @c -initWithPath:tail:), and the memory
 * set reads out of its @c data over @c dataRange with a @c dataCurrentPos cursor (installed by
 * @c -initWithData:range:). They are declared @c extern @c "C" so @c KUnzip can install them into a
 * @c zlib_filefunc_def table, and implemented in @c kunzip_filefunc.mm because they message
 * Objective-C objects.
 */

#ifndef KUNZIP_FILEFUNC_H
#define KUNZIP_FILEFUNC_H

#include "ioapi.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Opens the file-handle-backed archive for reading.
 *
 * Wraps @p filename in an @c NSString, opens it with @c +[NSFileHandle
 * fileHandleForReadingAtPath:], stores the handle on the @c KUnzip via @c -setFileHandle: when
 * non-nil, and returns it. @p mode is ignored, so this backend can never satisfy a write-mode open.
 *
 * @param opaque The @c KUnzip that receives the handle.
 * @param filename The UTF-8 path to open.
 * @param mode A ZLIB_FILEFUNC_MODE_* bitmask; ignored.
 * @return The opened @c NSFileHandle as a @c voidpf, or @c nullptr when the file cannot be opened.
 * @ghidraAddress 0x76338
 */
voidpf KUnzip_fopen_filehandle_func(voidpf opaque, const char *filename, int mode);

/**
 * @brief Reads @p size bytes from the file-handle-backed archive into @p buf.
 *
 * Reads at the handle's current @c offsetInFile through @c -readDataOfLength:, clamped so a read
 * can never cross @c dataRange.length, which this backend treats as an absolute end offset.
 *
 * @param opaque The @c KUnzip that owns the handle and the range.
 * @param stream The minizip stream cookie; ignored.
 * @param buf The destination buffer.
 * @param size The requested byte count; may be clamped down.
 * @return The number of bytes copied; 0 at or past the end offset, or on a nil read.
 * @ghidraAddress 0x763d8
 */
uLong KUnzip_fread_filehandle_func(voidpf opaque, voidpf stream, void *buf, uLong size);

/**
 * @brief Write stub for the file-handle-backed archive; always fails.
 *
 * @param opaque The @c KUnzip; ignored.
 * @param stream The minizip stream cookie; ignored.
 * @param buf The source buffer; ignored.
 * @param size The requested byte count; ignored.
 * @return Always 0.
 * @ghidraAddress 0x76528
 */
uLong KUnzip_fwrite_filehandle_func(voidpf opaque, voidpf stream, const void *buf, uLong size);

/**
 * @brief Reports the file-handle-backed archive's current position.
 *
 * @param opaque The @c KUnzip that owns the handle.
 * @param stream The minizip stream cookie; ignored.
 * @return The handle's @c offsetInFile.
 * @ghidraAddress 0x76530
 */
long KUnzip_ftell_filehandle_func(voidpf opaque, voidpf stream);

/**
 * @brief Seeks the file-handle-backed archive.
 *
 * The base is 0 for @c ZLIB_FILEFUNC_SEEK_SET, the handle's @c offsetInFile for
 * @c ZLIB_FILEFUNC_SEEK_CUR, and @c dataRange.length (an absolute end offset) for
 * @c ZLIB_FILEFUNC_SEEK_END. The target is rejected when it passes @c dataRange.length.
 *
 * @param opaque The @c KUnzip that owns the handle and the range.
 * @param stream The minizip stream cookie; ignored.
 * @param offset The displacement from the origin.
 * @param origin A ZLIB_FILEFUNC_SEEK_* value.
 * @return 0 on success, -1 on a bad origin or an out-of-range target.
 * @ghidraAddress 0x7657c
 */
long KUnzip_fseek_filehandle_func(voidpf opaque, voidpf stream, uLong offset, int origin);

/**
 * @brief Closes the file-handle-backed archive.
 *
 * @param opaque The @c KUnzip that owns the handle.
 * @param stream The minizip stream cookie; ignored.
 * @return Always 0.
 * @ghidraAddress 0x7667c
 */
int KUnzip_fclose_filehandle_func(voidpf opaque, voidpf stream);

/**
 * @brief Reports the error state of the file-handle-backed archive.
 *
 * @param opaque The @c KUnzip; ignored.
 * @param stream The minizip stream cookie; ignored.
 * @return Always 0.
 * @ghidraAddress 0x766c4
 */
int KUnzip_ferror_filehandle_func(voidpf opaque, voidpf stream);

/**
 * @brief Opens the memory-backed archive by rewinding the cursor.
 *
 * Sends @c -setDataCurrentPos: with @c dataRange.location and returns the @c KUnzip itself as the
 * stream cookie. @p filename and @p mode are ignored.
 *
 * @param opaque The @c KUnzip that holds the data, range, and cursor.
 * @param filename The path; ignored.
 * @param mode A ZLIB_FILEFUNC_MODE_* bitmask; ignored.
 * @return @p opaque, or @c nullptr when @p opaque is @c nullptr.
 * @ghidraAddress 0x76828
 */
voidpf KUnzip_fopen_mem_func(voidpf opaque, const char *filename, int mode);

/**
 * @brief Reads @p size bytes from the memory-backed archive into @p buf.
 *
 * Copies out of @c data starting at the absolute cursor @c dataCurrentPos through
 * @c -getBytes:range:, clamped to @c dataRange.location + @c dataRange.length, then advances the
 * cursor.
 *
 * @param opaque The @c KUnzip that owns the data, cursor, and range.
 * @param stream The minizip stream cookie; ignored.
 * @param buf The destination buffer.
 * @param size The requested byte count; may be clamped down.
 * @return The number of bytes copied; 0 at or past the end of the range.
 * @ghidraAddress 0x7688c
 */
uLong KUnzip_fread_mem_func(voidpf opaque, voidpf stream, void *buf, uLong size);

/**
 * @brief Write stub for the memory-backed archive; always fails.
 *
 * @param opaque The @c KUnzip; ignored.
 * @param stream The minizip stream cookie; ignored.
 * @param buf The source buffer; ignored.
 * @param size The requested byte count; ignored.
 * @return Always 0.
 * @ghidraAddress 0x769d0
 */
uLong KUnzip_fwrite_mem_func(voidpf opaque, voidpf stream, const void *buf, uLong size);

/**
 * @brief Reports the memory-backed archive's current position, relative to the range start.
 *
 * @param opaque The @c KUnzip that owns the cursor and range.
 * @param stream The minizip stream cookie; ignored.
 * @return @c dataCurrentPos - @c dataRange.location.
 * @ghidraAddress 0x769d8
 */
long KUnzip_ftell_mem_func(voidpf opaque, voidpf stream);

/**
 * @brief Seeks the memory-backed archive.
 *
 * The base is @c dataRange.location for @c ZLIB_FILEFUNC_SEEK_SET, @c dataCurrentPos for
 * @c ZLIB_FILEFUNC_SEEK_CUR, and @c dataRange.location + @c dataRange.length for
 * @c ZLIB_FILEFUNC_SEEK_END. The target is rejected when it passes the end of the range.
 *
 * @param opaque The @c KUnzip that owns the cursor and range.
 * @param stream The minizip stream cookie; ignored.
 * @param offset The displacement from the origin.
 * @param origin A ZLIB_FILEFUNC_SEEK_* value.
 * @return 0 on success, -1 on a bad origin or an out-of-range target.
 * @ghidraAddress 0x76a34
 */
long KUnzip_fseek_mem_func(voidpf opaque, voidpf stream, uLong offset, int origin);

/**
 * @brief Closes the memory-backed archive.
 *
 * @param opaque The @c KUnzip; ignored.
 * @param stream The minizip stream cookie; ignored.
 * @return Always 0.
 * @ghidraAddress 0x76b2c
 */
int KUnzip_fclose_mem_func(voidpf opaque, voidpf stream);

/**
 * @brief Reports the error state of the memory-backed archive.
 *
 * @param opaque The @c KUnzip; ignored.
 * @param stream The minizip stream cookie; ignored.
 * @return Always 0.
 * @ghidraAddress 0x76b34
 */
int KUnzip_ferror_mem_func(voidpf opaque, voidpf stream);

#ifdef __cplusplus
}
#endif

#endif

// code: language=C
// kate: hl C;
// vim: set ft=c :

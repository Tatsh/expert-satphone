/**
 * @file
 * The stdio I/O callbacks the game hands to minizip's unzip API.
 *
 * Reconstructed from Ghidra program Jubeat (image base 0x100000000). All @ghidraAddress values are
 * offsets relative to that image base. This is the stock zlib @c contrib/minizip/ioapi.c file
 * function set: a @c zlib_filefunc_def table whose seven members forward to the C stdio routines,
 * filled by @c fill_fopen_filefunc.
 */

#ifndef IOAPI_H
#define IOAPI_H

#ifdef __cplusplus
extern "C" {
#endif

/** minizip's opaque pointer type. */
typedef void *voidpf;

/** minizip's wide unsigned integer type (zlib's @c uLong). */
typedef unsigned long uLong;

/** Open for reading. */
#define ZLIB_FILEFUNC_MODE_READ 1
/** Open for writing. */
#define ZLIB_FILEFUNC_MODE_WRITE 2
/** The mask used to isolate the read/write mode bits. */
#define ZLIB_FILEFUNC_MODE_READWRITEFILTER 3
/** Open an existing file for update. */
#define ZLIB_FILEFUNC_MODE_EXISTING 4
/** Create (truncate) the file. */
#define ZLIB_FILEFUNC_MODE_CREATE 8

/** Seek relative to the start of the stream. */
#define ZLIB_FILEFUNC_SEEK_SET 0
/** Seek relative to the current position. */
#define ZLIB_FILEFUNC_SEEK_CUR 1
/** Seek relative to the end of the stream. */
#define ZLIB_FILEFUNC_SEEK_END 2

/** Callback that opens a file and returns its stream. */
typedef voidpf (*open_file_func)(voidpf opaque, const char *filename, int mode);
/** Callback that reads bytes from a stream. */
typedef uLong (*read_file_func)(voidpf opaque, voidpf stream, void *buf, uLong size);
/** Callback that writes bytes to a stream. */
typedef uLong (*write_file_func)(voidpf opaque, voidpf stream, const void *buf, uLong size);
/** Callback that reports the current position of a stream. */
typedef long (*tell_file_func)(voidpf opaque, voidpf stream);
/** Callback that seeks a stream. */
typedef long (*seek_file_func)(voidpf opaque, voidpf stream, uLong offset, int origin);
/** Callback that closes a stream. */
typedef int (*close_file_func)(voidpf opaque, voidpf stream);
/** Callback that reports the error state of a stream. */
typedef int (*testerror_file_func)(voidpf opaque, voidpf stream);

/**
 * The table of I/O callbacks minizip drives an archive through.
 *
 * The layout matches the stores in @c fill_fopen_filefunc: eight pointer-sized fields, the seven
 * callbacks followed by the opaque cookie, totalling 0x40 bytes.
 */
typedef struct zlib_filefunc_def_s {
    open_file_func zopen_file; /*!< Opens the archive. */                       // +0x00
    read_file_func zread_file; /*!< Reads bytes from the archive. */            // +0x08
    write_file_func zwrite_file; /*!< Writes bytes to the archive. */           // +0x10
    tell_file_func ztell_file; /*!< Reports the current offset. */              // +0x18
    seek_file_func zseek_file; /*!< Moves the current offset. */                // +0x20
    close_file_func zclose_file; /*!< Closes the archive. */                    // +0x28
    testerror_file_func zerror_file; /*!< Reports the pending error, if any. */ // +0x30
    voidpf opaque; /*!< The cookie handed back to every callback above. */      // +0x38
} zlib_filefunc_def;

/**
 * Maps a ZLIB_FILEFUNC_MODE_* bitmask to an @c fopen mode string and opens the file.
 *
 * The mode is selected by priority: read (@c mode & 3 == 1) becomes @c "rb", otherwise an existing
 * file (@c mode & 4) becomes @c "r+b", otherwise create (@c mode & 8) becomes @c "wb"; any other
 * bitmask selects no string. @p opaque is unused.
 *
 * @param opaque The @c zlib_filefunc_def opaque cookie; unused.
 * @param filename The path to open.
 * @param mode A ZLIB_FILEFUNC_MODE_* bitmask.
 * @return The opened @c FILE * as a @c voidpf, or @c nullptr when @p filename is @c nullptr or the
 * bits select no mode string.
 * @ghidraAddress 0x72a64
 */
voidpf fopen_file_func(voidpf opaque, const char *filename, int mode);

/**
 * Reads @p size bytes from @p stream into @p buf.
 *
 * @param opaque The opaque cookie; unused.
 * @param stream The @c FILE * to read from.
 * @param buf The destination buffer.
 * @param size The number of bytes to read.
 * @return The number of bytes actually read.
 * @ghidraAddress 0x72ac0
 */
uLong fread_file_func(voidpf opaque, voidpf stream, void *buf, uLong size);

/**
 * Writes @p size bytes from @p buf to @p stream.
 *
 * @param opaque The opaque cookie; unused.
 * @param stream The @c FILE * to write to.
 * @param buf The source buffer.
 * @param size The number of bytes to write.
 * @return The number of bytes actually written.
 * @ghidraAddress 0x72ad8
 */
uLong fwrite_file_func(voidpf opaque, voidpf stream, const void *buf, uLong size);

/**
 * Reports the current position of @p stream.
 *
 * @param opaque The opaque cookie; unused.
 * @param stream The @c FILE * to query.
 * @return The current byte offset within the stream.
 * @ghidraAddress 0x72af0
 */
long ftell_file_func(voidpf opaque, voidpf stream);

/**
 * Seeks @p stream, translating success to 0 and failure to -1.
 *
 * @param opaque The opaque cookie; unused.
 * @param stream The @c FILE * to seek.
 * @param offset The byte offset.
 * @param origin A ZLIB_FILEFUNC_SEEK_* value.
 * @return 0 on success, -1 on failure or an out-of-range origin.
 * @ghidraAddress 0x72af8
 */
long fseek_file_func(voidpf opaque, voidpf stream, uLong offset, int origin);

/**
 * Closes @p stream.
 *
 * @param opaque The opaque cookie; unused.
 * @param stream The @c FILE * to close.
 * @return The result of @c fclose.
 * @ghidraAddress 0x72b30
 */
int fclose_file_func(voidpf opaque, voidpf stream);

/**
 * Reports the error state of @p stream.
 *
 * @param opaque The opaque cookie; unused.
 * @param stream The @c FILE * to query.
 * @return The result of @c ferror.
 * @ghidraAddress 0x72b38
 */
int ferror_file_func(voidpf opaque, voidpf stream);

/**
 * Fills @p pzlib_filefunc_def with the stdio implementations and a @c nullptr opaque cookie.
 *
 * @param pzlib_filefunc_def The table to populate; written unconditionally with no @c nullptr
 * check.
 * @ghidraAddress 0x72b40
 */
void fill_fopen_filefunc(zlib_filefunc_def *pzlib_filefunc_def);

#ifdef __cplusplus
}
#endif

#endif

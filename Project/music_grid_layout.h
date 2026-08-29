/**
 * @file
 * The music-selection grid layout maths: how many cells fit on a page, how they split into
 * columns and rows, and the per-column-type cell scale.
 *
 * Reconstructed from Ghidra program Jubeat (image base 0x100000000); all @ghidraAddress values are
 * offsets relative to that image base. These are free functions: none takes an object receiver,
 * and the binary carries no RTTI, embedded source path, or owning class for them. Each queries the
 * device idiom through @c JubeatAppDelegate and derives its grid dimensions from it. The basename
 * is inferred because the shipped binary embeds no @c __FILE__ path.
 *
 * @c nColumnType is a small integer selector, not an enumerated set: three of these four functions
 * add it arithmetically to the column and row counts, so it is kept as a plain @c int rather than
 * modelled as an enumeration.
 */

#pragma once

#ifdef __cplusplus
extern "C" {
#endif

/**
 * Returns the number of music cells shown on one page of the music-selection grid.
 *
 * The result is the product of the column count and the row count, so its minimum is nine
 * (three by three). The binary inlines both helpers here rather than calling them.
 * @param nColumnType The column-type selector; larger values pack more columns and rows.
 * @return The number of cells on one page.
 * @ghidraAddress 0xfd4f0
 */
int GetMusicGridCellsPerPage(int nColumnType);

/**
 * Returns how many music cells fit across one row of the grid.
 *
 * The base is three columns; the HD phone idiom (@c JubeatDeviceTypePhoneRetinaHD) with a positive
 * column type widens it to four. The column type is then added on top.
 * @param nColumnType The column-type selector.
 * @return The number of cells per row; minimum three.
 * @ghidraAddress 0xfd654
 */
int GetMusicGridColumnCount(int nColumnType);

/**
 * Returns how many music-cell rows fit on one page of the grid.
 *
 * On top of the same base as @c GetMusicGridColumnCount, the taller phones and the iPad each add a
 * row: one for device types three to five, and one more for device types two to five or any iPad.
 * @param nColumnType The column-type selector.
 * @return The number of rows per page; minimum three.
 * @ghidraAddress 0xfd6c4
 */
int GetMusicGridRowCount(int nColumnType);

/**
 * Returns the scale factor applied to a music cell for a given column type.
 *
 * Column type one scales to 0.75, column type two to 0.6, and every other value to 1.0. The 0.6
 * value is stored as the float literal 0.6f widened to double.
 * @param nColumnType The column-type selector.
 * @return The cell scale factor; never zero.
 * @ghidraAddress 0xfd7cc
 */
double GetMusicCellScaleForColumnType(int nColumnType);

#ifdef __cplusplus
}
#endif

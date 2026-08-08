#import "music_grid_layout.h"

#import "JubeatAppDelegate.h"

namespace {

// The music grid is three columns by three rows on the smallest idiom and grows from there.
constexpr int kMusicGridBaseColumns = 3;
constexpr int kMusicGridWideColumns = 4;
constexpr int kMusicGridBaseRows = 3;
constexpr int kMusicGridWideRows = 4;

// The column-type selector doubles as "columns beyond the base three": type 0 is the three-column
// layout, type 1 the four-column layout, and type 2 the five-column layout. The scale narrows as
// the column count grows. The four- and five-column names are inferred from that relationship, not
// from binary metadata.
constexpr int kMusicColumnTypeFourColumn = 1;
constexpr int kMusicColumnTypeFiveColumn = 2;

// Cell scales keyed by column type.
constexpr double kMusicCellScaleThreeColumn = 1.0;
constexpr double kMusicCellScaleFourColumn = 0.75;
// The 0.6 factor is stored in __const as the float literal 0.6f widened to double
// (0x3FE3333340000000, not the double 0.6 which would be 0x3FE3333333333333). The mantissa tail
// proves the source constant was written as a float, so it is reproduced with a float-to-double
// widen rather than the double literal 0.6.
// @ghidraAddress 0x28f230
constexpr double kMusicCellScaleFiveColumn = static_cast<double>(0.6f);

} // namespace

int GetMusicGridColumnCount(int nColumnType) {
    JubeatDeviceType deviceType = JubeatAppDelegate.appDelegate.deviceType;
    int nColumns = kMusicGridBaseColumns;
    // The HD phone widens to four columns, but only once a column type is selected.
    if (deviceType == JubeatDeviceTypePhoneRetinaHD && nColumnType > 0) {
        nColumns = kMusicGridWideColumns;
    }
    return nColumns + nColumnType;
}

int GetMusicGridRowCount(int nColumnType) {
    JubeatAppDelegate *app = JubeatAppDelegate.appDelegate;
    // The binary reads the device type again separately for each decision below; the value is
    // constant across the call, so a single query reproduces the behaviour.
    JubeatDeviceType deviceType = app.deviceType;
    BOOL fPad = app.isPad;

    int nRows = nColumnType;
    // +1 for the taller retina phones, device types 3 to 5: the binary computes the unsigned test
    // (deviceType - 3) < 3.
    if (deviceType >= JubeatDeviceTypePhoneRetina47Inch &&
        deviceType <= JubeatDeviceTypePhoneRetinaHD) {
        nRows += 1;
    }
    // +1 for the four-inch-and-taller phones, device types 2 to 5 (the unsigned test
    // (deviceType - 2) < 4, which is the delegate's own is4inchAspect rule), or for any iPad.
    if ((deviceType >= JubeatDeviceTypePhoneRetina4Inch &&
         deviceType <= JubeatDeviceTypePhoneRetinaHD) ||
        fPad) {
        nRows += 1;
    }
    // The base is three rows, widened to four on the HD phone when a column type is selected.
    int nBaseRows = kMusicGridBaseRows;
    if (deviceType == JubeatDeviceTypePhoneRetinaHD && nColumnType > 0) {
        nBaseRows = kMusicGridWideRows;
    }
    return nRows + nBaseRows;
}

int GetMusicGridCellsPerPage(int nColumnType) {
    // The binary inlines both helpers here rather than calling them, and so queries the device
    // type four times over. The product is identical to calling the two helpers, so it is
    // reconstructed as that product.
    return GetMusicGridColumnCount(nColumnType) * GetMusicGridRowCount(nColumnType);
}

double GetMusicCellScaleForColumnType(int nColumnType) {
    // The binary fetches the device type here and discards the result; the query is dead code left
    // from an earlier device-dependent formula, kept only for its (now automatic) memory-management
    // effect.
    (void)JubeatAppDelegate.appDelegate.deviceType;

    double flScale = kMusicCellScaleThreeColumn;
    // The fcsel chain selects the five-column scale first and lets the four-column scale override
    // it, so the order of these two tests matches the binary.
    if (nColumnType == kMusicColumnTypeFiveColumn) {
        flScale = kMusicCellScaleFiveColumn;
    }
    if (nColumnType == kMusicColumnTypeFourColumn) {
        flScale = kMusicCellScaleFourColumn;
    }
    return flScale;
}

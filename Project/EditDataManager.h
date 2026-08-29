/**
 * @file
 * The chart-editor data model and file manager.
 *
 * Reconstructed from Ghidra program Jubeat (class EditDataManager, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c NSObject , taken from the @c [NSObject init] chain-up in @c -init at
 * 0x1c5a5c. @c EditDataManager is the shared model behind the chart editor: it owns the custom
 * sequence directory tree under the app documents folder, loads and saves each chart as an
 * encrypted @c .jcf file, Blowfish-encodes/decodes the save blob, and (de)serialises the packed
 * binary edit-data format into an editor-info dictionary, a score dictionary, a simple-data
 * dictionary, and a 2000-entry sequence table. It also manages the editable slot limit, the
 * last-edited file marker, and per-tune score hashing and update.
 *
 * The class carries no embedded @c __FILE__ path and no C++ RTTI, so the file basename is the
 * runtime class name and this file lives at the @c Project/ root, beside the other @c Edit* files.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * The shared chart-editor data model.
 */
@interface EditDataManager : NSObject

/**
 * Returns the process-wide shared manager, creating it once.
 * @return The shared manager.
 * @ghidraAddress 0x1c59d4
 */
+ (instancetype)sharedManager;

/**
 * Initialises an empty manager with copying enabled and no loaded data.
 * @return The initialised manager.
 * @ghidraAddress 0x1c5a5c
 */
- (instancetype)init;

#pragma mark - Custom sequence directory tree

/**
 * Returns the names of the per-music custom-sequence directories, or @c nil if none exist.
 * @return The directory entry names under the @c edit folder, or @c nil .
 * @ghidraAddress 0x1c5b2c
 */
- (nullable NSArray<NSString *> *)getCustomSequenceDirectoryList;

/**
 * Deletes the custom-sequence directory for a boxed music identifier.
 * @param musicID The music identifier, boxed as an @c NSNumber .
 * @ghidraAddress 0x1c5c08
 */
- (void)deleteCustomSequenceDirectory:(nullable NSNumber *)musicID;

/**
 * Marks a path so it is excluded from iCloud/iTunes backup. The binary body only returns
 *        @c YES ; the attribute call was compiled out.
 * @param path The file-system path.
 * @return @c YES always.
 * @ghidraAddress 0x1c5c98
 */
- (BOOL)addIgnoreBackUpAttribute:(nullable NSString *)path;

/**
 * Returns the per-music custom-sequence directory path, creating the tree if needed.
 *
 * The path is @c \<documents\>/edit/\<%09d\> where the last component is the zero-padded nine-digit
 * music identifier. Both the @c edit folder and the music subfolder are created on demand, and the
 * @c edit folder is flagged no-backup on creation.
 *
 * @param musicID The music identifier.
 * @return The directory path.
 * @ghidraAddress 0x1c5ca0
 */
- (nullable NSString *)getDirectoryPath:(int)musicID;

/**
 * Builds a fresh @c .jcf file name from the current date and time.
 * @return A name of the form @c \<yyyyMMddHHmmssSSS\>.jcf .
 * @ghidraAddress 0x1c5e6c
 */
- (nullable NSString *)createJCFName;

/**
 * Deletes a @c .jcf file at a path if it exists.
 * @param path The file path, or @c nil .
 * @return @c NO if @p path is @c nil , @c YES otherwise.
 * @ghidraAddress 0x1c5f54
 */
- (BOOL)deleteJCF:(nullable NSString *)path;

/**
 * Loads and decodes a @c .jcf file into the model.
 * @param path The file path.
 * @return @c YES if the file was read and decoded successfully.
 * @ghidraAddress 0x1c5ff4
 */
- (BOOL)loadJCF:(nullable NSString *)path;

/**
 * Encodes the model and writes it to a @c .jcf file.
 * @param path The file path.
 * @return @c NO if @p path is @c nil , @c YES otherwise.
 * @ghidraAddress 0x1c6194
 */
- (BOOL)saveJCF:(nullable NSString *)path;

#pragma mark - Blowfish encode/decode

/**
 * Stores raw data as the current custom data and decodes it.
 * @param data The raw edit-data blob.
 * @return @c YES always.
 * @ghidraAddress 0x1c6300
 */
- (BOOL)createEditDataWithNSData:(nullable NSData *)data;

/**
 * Blowfish-encrypts a copy of a buffer with the save-data key.
 * @param data The plaintext buffer.
 * @return A new encrypted buffer.
 * @ghidraAddress 0x1c635c
 */
- (nullable NSMutableData *)exeSaveBFEnc:(nullable NSData *)data;

/**
 * Blowfish-decrypts a copy of a buffer with the save-data key.
 * @param data The ciphertext buffer.
 * @return A new decrypted buffer.
 * @ghidraAddress 0x1c640c
 */
- (nullable NSMutableData *)exeLoadBFDec:(nullable NSData *)data;

/**
 * The second-layer encrypt hook for downloaded charts. The binary returns its argument
 *        unchanged.
 * @param data The buffer.
 * @return @p data unchanged.
 * @ghidraAddress 0x1c64bc
 */
- (nullable NSData *)exeBFEnc:(nullable NSData *)data;

/**
 * The second-layer decrypt hook for downloaded charts. The binary returns its argument
 *        unchanged.
 * @param data The buffer.
 * @return @p data unchanged.
 * @ghidraAddress 0x1c64d4
 */
- (nullable NSData *)exeBFDec:(nullable NSData *)data;

#pragma mark - Download tagging

/**
 * Fills an eight-character random tag whose sixth character's low bit records the DL flag.
 * @param buffer The eight-byte destination.
 * @param isDL @c YES to mark the tag as downloaded (low bit clear).
 * @return The tag as an @c NSString .
 * @ghidraAddress 0x1c64ec
 */
- (nullable NSString *)createDLString:(char *)buffer isDL:(BOOL)isDL;

/**
 * Tests whether a tag buffer's DL bit marks a downloaded chart.
 * @param buffer The tag buffer (the sixth byte's low bit is tested), or @c nullptr .
 * @return @c YES if the low bit of @c buffer[5] is clear.
 * @ghidraAddress 0x1c6644
 */
- (BOOL)checkDownLoad:(nullable const char *)buffer;

/**
 * Tests whether a decrypted blob's DL tag marks a downloaded chart.
 * @param data The decrypted blob.
 * @return @c YES if the blob is a downloaded chart.
 * @ghidraAddress 0x1c6660
 */
- (BOOL)checkDownloadFile:(nullable NSData *)data;

/**
 * Saves a downloaded chart locally, either loading an existing copy or installing a new one.
 * @param data The downloaded, still-encoded chart blob.
 * @param serial The download sequence identifier string.
 * @param usrTag The user tag to record.
 * @return @c YES on success.
 * @ghidraAddress 0x1c6718
 */
- (BOOL)localSaveDLFile:(nullable NSData *)data
                 serial:(nullable NSString *)serial
                 usrTag:(int)usrTag;

#pragma mark - Packed binary format helpers

/**
 * Reads a fixed-size blob into a scratch buffer and picks up its editor info.
 * @param data The raw edit-data blob.
 * @return The editor-info dictionary.
 * @ghidraAddress 0x1c6b58
 */
- (nullable NSMutableDictionary *)pickUpEditorInfoFromData:(nullable NSData *)data;

/**
 * Writes an unsigned value into a buffer as @p byte little-endian bytes.
 * @param buffer The destination buffer.
 * @param data The value to store.
 * @param byte The number of bytes to write.
 * @ghidraAddress 0x1c6bf4
 */
- (void)setCharArray:(char *)buffer setData:(unsigned int)data byte:(int)byte;

/**
 * Reads @p byte little-endian bytes from a buffer into an unsigned value.
 * @param buffer The source buffer.
 * @param byte The number of bytes to read.
 * @return The decoded value.
 * @ghidraAddress 0x1c6cd8
 */
- (unsigned int)getCharArrayValue:(const char *)buffer byte:(int)byte;

/**
 * Recomputes the current custom data's integrity hash and compares it to the stored value.
 * @param data Unused; the check reads the current @c writeData buffer.
 * @return @c YES if the hashes match.
 * @ghidraAddress 0x1c6d7c
 */
- (BOOL)validateHash:(nullable NSData *)data;

#pragma mark - Score data

/**
 * Resets the score dictionary to its default (no best score, no full combo, zero hashes).
 * @ghidraAddress 0x1c6e48
 */
- (void)scoreDataReset;

/**
 * Parses the score fields of a packed blob into a new dictionary, resetting on hash failure.
 * @param buffer The packed edit-data buffer.
 * @return The score dictionary, or @c nil for a @c nullptr buffer.
 * @ghidraAddress 0x1c6fb8
 */
- (nullable NSMutableDictionary *)pickUpScoreData:(nullable const char *)buffer;

/**
 * Parses the editor-info fields of a packed blob into a new dictionary.
 * @param buffer The packed edit-data buffer.
 * @return The editor-info dictionary, or @c nil for a @c nullptr buffer.
 * @ghidraAddress 0x1c74bc
 */
- (nullable NSMutableDictionary *)pickUpEditorInfo:(nullable const char *)buffer;

/**
 * Parses the simple-data fields (counts, sectors, music bar, notes hash) of a packed blob.
 * @param buffer The packed edit-data buffer.
 * @return The simple-data dictionary.
 * @ghidraAddress 0x1c7990
 */
- (nullable NSMutableDictionary *)pickUpEditSimpleData:(nullable const char *)buffer;

/**
 * Parses the 2000-entry note-word table of a packed blob into a boxed array.
 * @param buffer The packed edit-data buffer.
 * @return The sequence table of boxed packed note words.
 * @ghidraAddress 0x1c7cb4
 */
- (nullable NSMutableArray<NSNumber *> *)pickUpSequenceTable:(nullable const char *)buffer;

/**
 * Decodes the current custom data into the editor-info, score, simple-data, and sequence
 *        table models.
 * @return @c YES if the blob's integrity hash matched and it was decoded.
 * @ghidraAddress 0x1c7d9c
 */
- (BOOL)decodeBinary;

/**
 * Encodes the editor-info, score, simple-data, and sequence table models into a packed blob
 *        stored as the current custom data.
 * @return @c YES always.
 * @ghidraAddress 0x1c81a4
 */
- (BOOL)encodeBinary;

/**
 * Returns the editor-info dictionaries for every @c .jcf file in a music's directory.
 * @param musicID The music identifier.
 * @return An array of editor-info dictionaries, each tagged with its @c fileName .
 * @ghidraAddress 0x1c8c7c
 */
- (nullable NSMutableArray<NSMutableDictionary *> *)getFileInfoList:(unsigned int)musicID;

#pragma mark - Edit state

/**
 * Whether editing is currently enabled (the copy-lock flag is clear).
 * @return @c YES if editing is enabled.
 * @ghidraAddress 0x1c9014
 */
- (BOOL)isEnableEdit;

/**
 * Disables editing by setting the copy-lock flag.
 * @ghidraAddress 0x1c902c
 */
- (void)disableEdit;

/**
 * Returns the score dictionary.
 * @return The score dictionary.
 * @ghidraAddress 0x1c9040
 */
- (nullable NSMutableDictionary *)getScoreData;

/**
 * Replaces the score dictionary with a mutable copy of the given dictionary.
 * @param scoreData The source dictionary.
 * @ghidraAddress 0x1c9050
 */
- (void)setScoreData:(nullable NSDictionary *)scoreData;

/**
 * Returns the editor-info dictionary.
 * @return The editor-info dictionary.
 * @ghidraAddress 0x1c90d0
 */
- (nullable NSMutableDictionary *)getEditorInfo;

/**
 * Replaces the editor-info dictionary with a mutable copy of the given dictionary.
 * @param editorInfo The source dictionary.
 * @ghidraAddress 0x1c90e0
 */
- (void)setEditorInfo:(nullable NSDictionary *)editorInfo;

/**
 * Returns the simple-data dictionary.
 * @return The simple-data dictionary.
 * @ghidraAddress 0x1c9160
 */
- (nullable NSMutableDictionary *)getEditSimpleData;

/**
 * Replaces the simple-data dictionary with a mutable copy of the given dictionary.
 * @param editSimpleData The source dictionary.
 * @ghidraAddress 0x1c9170
 */
- (void)setEditSimpleData:(nullable NSDictionary *)editSimpleData;

/**
 * Clears every loaded model reference.
 * @ghidraAddress 0x1c91f0
 */
- (void)clearEditData;

/**
 * Rebuilds the editor-info and score dictionaries from application defaults.
 * @ghidraAddress 0x1c926c
 */
- (void)resetEditorInfo;

/**
 * Returns the sequence table.
 * @return The sequence table.
 * @ghidraAddress 0x1c95a0
 */
- (nullable NSMutableArray<NSNumber *> *)getSequenceTable;

/**
 * Sets the sequence table.
 * @param sequenceTable The sequence table.
 * @ghidraAddress 0x1c95b0
 */
- (void)setSequenceTable:(nullable NSMutableArray<NSNumber *> *)sequenceTable;

#pragma mark - Last-edited file

/**
 * Returns the recorded last-edited file name for a music, if it still exists.
 * @param musicID The music identifier.
 * @return The last-edited file name, or @c nil .
 * @ghidraAddress 0x1c95c4
 */
- (nullable NSString *)getLastEditFileName:(int)musicID;

/**
 * Returns the full path of the recorded last-edited file for a music.
 * @param musicID The music identifier.
 * @return The last-edited file path, or @c nil .
 * @ghidraAddress 0x1c976c
 */
- (nullable NSString *)getLastEditFilePath:(int)musicID;

/**
 * Records a file name as the last-edited file for a music.
 * @param musicID The music identifier.
 * @param fileName The file name to record.
 * @ghidraAddress 0x1c9808
 */
- (void)setLastEditFileName:(int)musicID fileName:(nullable NSString *)fileName;

/**
 * Returns whether a last-edited marker file exists for a music.
 * @param musicID The music identifier.
 * @return @c YES if the marker file exists.
 * @ghidraAddress 0x1c9960
 */
- (BOOL)IsExistEditFile:(int)musicID;

#pragma mark - Score hashing and update

/**
 * Returns the MD5 hash of a score packed as four little-endian bytes.
 * @param score The score value.
 * @return The 32-character hexadecimal hash.
 * @ghidraAddress 0x1c9a40
 */
- (nullable NSString *)getScoreHash:(int)score;

/**
 * Returns whether the stored score hash matches the stored best score.
 * @return @c YES if the score dictionary is self-consistent.
 * @ghidraAddress 0x1c9a80
 */
- (BOOL)checkScoreHash;

/**
 * Updates the best score and full-combo flag for a tune and saves the chart.
 * @param score The new score.
 * @param fullCombo Whether the play was a full combo.
 * @param tuneID The music identifier whose last-edited chart is updated.
 * @ghidraAddress 0x1c9b58
 */
- (void)scoreUpdate:(int)score fullCombo:(BOOL)fullCombo tuneID:(int)tuneID;

#pragma mark - Music catalogue

/**
 * Returns the identifiers of every built-in and purchased music, as strings.
 * @return The music identifier list.
 * @ghidraAddress 0x1c9e70
 */
- (nullable NSMutableArray<NSString *> *)getMusicIDList;

/**
 * Returns the count of built-in and purchased music.
 * @return The music count.
 * @ghidraAddress 0x1ca224
 */
- (int)getMusicNum;

/**
 * Returns the number of editable slots: four plus one per forty music.
 * @return The editable slot limit.
 * @ghidraAddress 0x1ca380
 */
- (int)getEditSlotLimit;

/**
 * Returns the current encoded custom-data buffer.
 * @return The encoded custom-data buffer.
 * @ghidraAddress 0x1ca3b8
 */
- (nullable NSMutableData *)getCurrentCustomData;

#pragma mark - Flags

/**
 * Whether copying the current chart is allowed.
 * @ghidraAddress 0x1ca3c8
 */
@property(nonatomic, readonly) BOOL bEnableCopy;

/**
 * Whether the current chart is a downloaded chart.
 *
 * The getter is at 0x1ca3d8 and the setter at 0x1ca3e8.
 */
@property(nonatomic, assign) BOOL bIsDownload;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :

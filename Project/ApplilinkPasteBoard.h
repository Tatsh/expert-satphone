/** @file
 * The KONAMI Applilink SDK's pasteboard-backed UDID store.
 *
 * @c ApplilinkPasteBoard mirrors the advertising UDID records into named, persistent
 * @c UIPasteboard slots so they survive an app reinstall. Each slot stores an @c NSKeyedArchiver
 * archive of a small record dictionary (an encrypted @c Value , an @c EntryDate , a @c LastAccess
 * date, and a schema @c Version ), whose payload is additionally enciphered through the @c Crypto
 * helper.
 * Reconstructed from Ghidra program Jubeat (image base 0x100000000). All @ghidraAddress values are
 * offsets relative to that image base. The class object is at 0x352758.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Pasteboard-backed UDID store for the Applilink SDK.
 */
@interface ApplilinkPasteBoard : NSObject

/**
 * @brief Whether the current UDID was resolved from the old-service pasteboard rather than the
 *        current one. Set when @c storageData exhausts every current-service slot and falls back to
 *        @c storageDataOld , and cleared once a current-service slot answers.
 * @ghidraAddress 0x2688b0 (getter), 0x2688c0 (setter)
 */
@property(nonatomic) BOOL nonPasteBoardUdidFlag;

/**
 * @brief Validates a decoded pasteboard record dictionary.
 * @param dict The un-archived record.
 * @param error Set to a localised error describing the first invalid field.
 * @return @c YES when the record has a value, entry date, last-access date, and a positive version.
 * @ghidraAddress 0x267ff4
 */
+ (BOOL)validate:(nullable NSDictionary *)dict error:(NSError *_Nullable *_Nullable)error;

/**
 * @brief The stored current-UDID pasteboard record.
 * @return The stored record, or nil.
 * @ghidraAddress 0x26700c
 */
- (nullable NSDictionary *)storageData;

/**
 * @brief The stored old-service UDID pasteboard record.
 * @return The stored record, or nil.
 * @ghidraAddress 0x267208
 */
- (nullable NSDictionary *)storageDataOld;

/**
 * @brief The pasteboard record for a service name and storage index.
 * @param serviceName The pasteboard service name.
 * @param storageIndex The storage slot index.
 * @param error Set to a localised error when the slot is empty or invalid.
 * @return The stored record, or nil.
 * @ghidraAddress 0x2673a4
 */
- (nullable NSDictionary *)storageDataWithServiceName:(nullable NSString *)serviceName
                                         storageIndex:(int)storageIndex
                                                error:(NSError *_Nullable *_Nullable)error;

/**
 * @brief Writes a UDID into the first empty current-service pasteboard slot.
 * @param udid The UDID to store.
 * @param error Set to a localised error on failure.
 * @return The stored record, or nil on failure.
 * @ghidraAddress 0x2677d0
 */
- (nullable NSDictionary *)writeStorageData:(nullable NSString *)udid
                                      error:(NSError *_Nullable *_Nullable)error;

/**
 * @brief Writes a UDID into a current-service pasteboard slot at a storage index.
 * @param udid The UDID to store.
 * @param storageIndex The storage slot index.
 * @param error Set to a localised error on failure.
 * @return The stored record, or nil on failure.
 * @ghidraAddress 0x267a20
 */
- (nullable NSDictionary *)writeStorageData:(nullable NSString *)udid
                               storageIndex:(int)storageIndex
                                      error:(NSError *_Nullable *_Nullable)error;

/**
 * @brief Deletes the current-service pasteboard slot at a storage index.
 * @param storageIndex The storage slot index.
 * @param error Set to a localised error on failure.
 * @return @c YES on success.
 * @ghidraAddress 0x267dec
 */
- (BOOL)deleteWithStorageIndex:(int)storageIndex error:(NSError *_Nullable *_Nullable)error;

/**
 * @brief Builds the caller-facing record dictionary from a decoded record.
 * @param record The decoded record dictionary.
 * @param serviceName The pasteboard service name whose hash keys the value cipher.
 * @param storageIndex The storage slot index recorded in the result.
 * @return A mutable record carrying the decrypted value and the storage index.
 * @ghidraAddress 0x2682e0
 */
- (nullable NSDictionary *)convertToData:(nullable NSDictionary *)record
                             serviceName:(nullable NSString *)serviceName
                            storageIndex:(int)storageIndex;

/**
 * @brief The pasteboard service name for advertising UDIDs.
 * @return The advertising service name.
 * @ghidraAddress 0x268524
 */
- (NSString *)getServiceName;

/**
 * @brief The pasteboard service name for old-server UDIDs.
 * @return The old service name.
 * @ghidraAddress 0x2685e4
 */
- (NSString *)getServiceNameOld;

/**
 * @brief Logs the stored pasteboard UDID values across every current-service slot.
 * @ghidraAddress 0x2686a4
 */
- (void)debugLog;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :

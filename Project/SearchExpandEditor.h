/**
 * @file
 * @brief The search-term expansion dictionary editor.
 *
 * Reconstructed from Ghidra program Jubeat (class SearchExpandEditor, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base. The class object is at 0x34fa58.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Maintains a persistent map of search keys to their expanded word lists, merging new
 * entries into the existing set and saving the result as JSON in the documents directory.
 */
@interface SearchExpandEditor : NSObject

/**
 * @brief Copies the bundled seed dictionary into the documents directory, replacing any existing
 * copy.
 * @ghidraAddress 0x15f4bc
 */
+ (void)copyDictionary;

/**
 * @brief Loads the persisted dictionary (or an empty one when none exists).
 * @return The initialised editor.
 * @ghidraAddress 0x15ee9c
 */
- (instancetype)init;

/**
 * @brief A snapshot copy of the current expansion dictionary.
 * @return An immutable copy of the dictionary.
 * @ghidraAddress 0x15eef8
 */
- (nullable NSDictionary *)getDictionary;

/**
 * @brief Merges a word list into the entry for a key, de-duplicating the union.
 * @param searchInfo The key.
 * @param words The words to add.
 * @return Always @c NO .
 * @ghidraAddress 0x15ef18
 */
- (BOOL)addSearchInfo:(nullable NSString *)searchInfo addWords:(nullable NSArray *)words;

/**
 * @brief Merges every key/word-list pair of another dictionary into this one.
 * @param dictionary The dictionary to merge in.
 * @return Always @c NO .
 * @ghidraAddress 0x15f070
 */
- (BOOL)addDictionary:(nullable NSDictionary *)dictionary;

/**
 * @brief Loads the persisted dictionary from the documents directory.
 * @ghidraAddress 0x15f1ec
 */
- (void)loadDictionary;

/**
 * @brief Saves the current dictionary as JSON to the documents directory.
 * @ghidraAddress 0x15f384
 */
- (void)saveDictionary;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :

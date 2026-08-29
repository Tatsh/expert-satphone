/**
 * @file
 * @brief One purchasable track, as the store server describes it.
 *
 * Reconstructed from Ghidra program Jubeat (class StoreMusicInfo, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * RECONSTRUCTION STATE: complete. The runtime metadata declares two methods beyond the property
 * accessors and both are implemented.
 *
 * The superclass binds to @c _OBJC_CLASS_$_NSObject at load time; it is not stored in the file.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A store track, including the extended chart it may carry.
 */
@interface StoreMusicInfo : NSObject

/** @brief The track's identifier. Wire key @c "ID"; a value below 1 rejects the whole record. */
@property(nonatomic, readonly) int musicID;
/** @brief The track's title. Wire key @c "Name". */
@property(nonatomic, strong, nullable) NSString *name;
/** @brief The performing artist. Wire key @c "Artist". */
@property(nonatomic, strong, nullable) NSString *artist;
/** @brief Where to buy the track. Wire key @c "ItemURL". */
@property(nonatomic, strong, nullable) NSString *itemURL;
/** @brief The artwork, or nil when the server's value did not pass @c +[StoreUtil isValidURL:]. */
@property(nonatomic, strong, nullable) NSString *artworkURL;
/** @brief The preview clip, subject to the same validity test. Wire key @c "SampleURL". */
@property(nonatomic, strong, nullable) NSString *sampleURL;
/** @brief The iTunes listing, subject to the same validity test. Wire key @c "iTunesURL". */
@property(nonatomic, strong, nullable) NSString *itunesURL;

/** @brief The basic chart's level, 1 to 10. Wire key @c "Level", element 0. */
@property(nonatomic, readonly) int lvBas;
/** @brief The advanced chart's level, 1 to 10. Wire key @c "Level", element 1. */
@property(nonatomic, readonly) int lvAdv;
/** @brief The extreme chart's level, 1 to 10. Wire key @c "Level", element 2. */
@property(nonatomic, readonly) int lvExt;

/** @brief Whether the track is held back from sale. Wire key @c "holdFlag". */
@property(nonatomic, readonly) unsigned int holdFlag;
/** @brief What the extended chart may be played with. Wire key @c "extendFlag". */
@property(nonatomic, readonly) unsigned int extendFlag;
/** @brief The extended chart's own track identifier. Wire key @c "extID". */
@property(nonatomic, readonly) unsigned int extendMusicID;
/** @brief Where to buy the extended chart. Wire key @c "extURL". */
@property(nonatomic, readonly, nullable) NSString *extendItemURL;
/**
 * @brief The extended chart as a track in its own right.
 *
 * Built recursively: when @c extendMusicID is non-zero the initialiser rewrites its own input
 * dictionary and feeds it back through @c -initWithDictionary:. The nesting stops after one level
 * because the rewritten dictionary has its @c "extID" removed.
 */
@property(nonatomic, strong, nullable) StoreMusicInfo *extendInfo;

/**
 * @brief Builds a track from a server dictionary, or returns nil.
 *
 * A genuine initialiser, unlike the identically named methods on the challenge-mission classes: it
 * calls @c -init and returns @c instancetype. It answers nil before doing anything when @c "ID" is
 * missing or reads below 1.
 *
 * @param dictionary The server's track record.
 * @ghidraAddress 0xceeb0
 */
- (instancetype)initWithDictionary:(NSDictionary *)dictionary;
/**
 * @brief The extended chart, if any.
 *
 * A one-instruction tail call to the @c extendInfo getter, so it is an alias rather than a
 * computation. Kept because the binary ships it as a separate selector.
 * @ghidraAddress 0xcf650
 */
- (nullable StoreMusicInfo *)getExtendInfo;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :

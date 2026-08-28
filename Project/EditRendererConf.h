/**
 * @file EditRendererConf.h
 * @brief Chart-editor render configuration passed to the edit-mode note renderers.
 *
 * Reconstructed from Ghidra program Jubeat (image base 0x100000000). All @ghidraAddress values are
 * offsets relative to that image base.
 *
 * A plain value object the chart editor hands to @c EditNoteRenderer (and its phone/pad
 * subclasses): the tune and marker identifiers and the difficulty and level the board is being
 * drawn for. It declares no initialiser of its own, so it is a direct @c NSObject subclass built
 * with @c +alloc / @c -init.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The marker, sound, and display settings the chart editor's renderer draws with.
 */
@interface EditRendererConf : NSObject

/**
 * @brief The marker resource identifier for the chart being edited.
 * @ghidraAddress 0x20ad50
 */
@property(nonatomic, assign, nullable) NSString *markerID;

/**
 * @brief The difficulty index the board is drawn for. Encodes as @c I .
 * @ghidraAddress 0x20ad70
 */
@property(nonatomic, assign) unsigned int diff;

/**
 * @brief The chart level. Encodes as @c I .
 * @ghidraAddress 0x20ad90
 */
@property(nonatomic, assign) unsigned int level;

/**
 * @brief The tune identifier. Encodes as @c I .
 * @ghidraAddress 0x20adb0
 */
@property(nonatomic, assign) unsigned int tuneID;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :

#import "StorePromotion.h"

#include <stdlib.h>

// The keys each entry of the sample list carries.
static NSString *const kSampleURLKey = @"URL";
static NSString *const kSampleMusicNameKey = @"MusicName";

@implementation StorePromotion {
    // Which entry of sampleList the two getters read. Not a property, and 32-bit where the array
    // index it feeds is 64-bit.
    int playSlot;
}

/** @ghidraAddress 0x1bd754 */
- (instancetype)initWithPackInfo:(StorePackInfo *)packInfo
                        imageURL:(NSString *)imageURL
                       sampleURL:(NSArray *)sampleURL {
    self = [super init];
    if (self) {
        _genreIndex = 0;
        _packInfo = packInfo;
        _imageURL = imageURL;
        _sampleList = sampleURL;

        // The count is narrowed to a 32-bit int before the modulo — the divide is sdiv on w
        // registers, not udiv on x. rand() is non-negative, so the remainder is too.
        int sampleCount = (int)sampleURL.count;
        if (sampleCount != 0) {
            playSlot = rand() % sampleCount;
        } else {
            playSlot = 0;
        }
    }
    return self;
}

/** @ghidraAddress 0x1bd88c */
- (instancetype)initWithGenreIndex:(NSUInteger)genreIndex imageURL:(NSString *)imageURL {
    self = [super init];
    if (self) {
        _genreIndex = genreIndex;
        // Cleared rather than left alone: a genre promotion has no pack and no samples.
        _packInfo = nil;
        _imageURL = imageURL;
        _sampleList = nil;
        playSlot = 0;
    }
    return self;
}

/** @ghidraAddress 0x1bd954 */
- (NSString *)getSampleURL {
    if (!_sampleList) {
        return nil;
    }
    return [_sampleList[playSlot] objectForKey:kSampleURLKey];
}

/** @ghidraAddress 0x1bd9d8 */
- (NSString *)getSampleName {
    // No nil guard here, unlike -getSampleURL above. Messaging nil twice yields nil, so this is
    // harmless rather than a crash — but the two getters are not the same shape.
    return [_sampleList[playSlot] objectForKey:kSampleMusicNameKey];
}

@end

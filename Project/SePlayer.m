#import "SePlayer.h"

#include <stdlib.h>

#include <OpenAL/al.h>
#include <OpenAL/alc.h>

// One buffer and one source per instance.
static const ALsizei kHandleCount = 1;

// alBufferDataStatic is an Apple extension with no header prototype, so it is reached through
// alcGetProcAddress. This is the typedef from Apple's own oalTouch sample, which this class
// otherwise follows closely.
typedef ALvoid (*alBufferDataStaticProcPtr)(
    const ALint bid, ALenum format, ALvoid *data, ALsizei size, ALsizei freq);

// A plain C string in the binary, at 0x285bba, not a CFString.
static const char *const kBufferDataStaticName = "alBufferDataStatic";

// Resolved once on first use and cached. The binary keeps this at 0x3541a8.
static alBufferDataStaticProcPtr gBufferDataStatic = NULL;

/**
 * @brief Decodes an audio file into raw samples for OpenAL.
 *
 * DECLARED ONLY — the body has not been reconstructed yet. See TYPES_PENDING.md. Ghidra already
 * carries the name and signature, which match Apple's oalTouch sample verbatim.
 *
 * @param inFileURL The file to decode.
 * @param outDataSize Receives the sample data's length in bytes.
 * @param outDataFormat Receives the OpenAL format enumerator.
 * @param outSampleRate Receives the sample rate.
 * @return The sample data, which the caller owns and must free.
 * @ghidraAddress 0x153cd4
 */
extern void *MyGetOpenALAudioData(NSURL *inFileURL,
                                  ALsizei *outDataSize,
                                  ALenum *outDataFormat,
                                  ALsizei *outSampleRate);

@implementation SePlayer {
    ALuint soundBuffer;
    ALuint soundSource;
    ALCdevice *soundDevice;
    void *soundData;
    ALCcontext *soundContext;
}

/** @ghidraAddress 0x153b34 */
- (instancetype)initWithPath:(NSString *)path {
    self = [super init];
    if (self) {
        soundDevice = alcOpenDevice(NULL);
        if (soundDevice != NULL) {
            soundContext = alcCreateContext(soundDevice, NULL);
            alcMakeContextCurrent(soundContext);
            alGenBuffers(kHandleCount, &soundBuffer);
            alGenSources(kHandleCount, &soundSource);
        }

        // Yes, no early return when the device failed to open. The decode below still runs and the
        // buffer call still fires, against a buffer handle that was never generated.
        ALsizei dataSize = 0;
        ALenum dataFormat = 0;
        ALsizei sampleRate = 0;
        soundData =
            MyGetOpenALAudioData([NSURL fileURLWithPath:path], &dataSize, &dataFormat, &sampleRate);

        if (gBufferDataStatic == NULL) {
            gBufferDataStatic =
                (alBufferDataStaticProcPtr)alcGetProcAddress(NULL, kBufferDataStaticName);
        }
        if (gBufferDataStatic != NULL) {
            gBufferDataStatic(soundBuffer, dataFormat, soundData, dataSize, sampleRate);
        }

        alSourcei(soundSource, AL_LOOPING, AL_FALSE);
        alSourcei(soundSource, AL_BUFFER, soundBuffer);
    }
    return self;
}

/** @ghidraAddress 0x153ed0 */
- (void)sePlay {
    alSourcePlay(soundSource);
}

/** @ghidraAddress 0x153ee0 */
- (void)terminate {
    alSourceStop(soundSource);
    alDeleteBuffers(kHandleCount, &soundBuffer);
    alDeleteSources(kHandleCount, &soundSource);
    alcDestroyContext(soundContext);
    alcCloseDevice(soundDevice);
    free(soundData);

    soundBuffer = 0;
    soundSource = 0;
    soundContext = NULL;
    soundDevice = NULL;
    soundData = NULL;
}

@end

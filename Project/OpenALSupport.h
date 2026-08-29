/**
 * @file
 * The audio-file decoder that feeds raw PCM samples to OpenAL.
 */

#ifndef OPENALSUPPORT_H
#define OPENALSUPPORT_H

#import <Foundation/Foundation.h>
#import <OpenAL/al.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * Decodes an audio file into raw 16-bit linear PCM samples for OpenAL.
 *
 * Opens @p inFileURL with the ExtAudioFile API, converts the file to an
 * interleaved signed 16-bit linear-PCM client format, allocates the sample
 * buffer with @c malloc, reads every frame into it, and returns the buffer.
 * The caller takes ownership of the returned buffer and must @c free it.
 *
 * On any failure the routine prints a diagnostic to standard output and
 * returns @c nullptr. More than two channels is rejected as unsupported.
 *
 * @param inFileURL The audio file to decode.
 * @param outDataSize Receives the sample data's length in bytes.
 * @param outDataFormat Receives the OpenAL format enumerator
 *   (@c AL_FORMAT_MONO16 or @c AL_FORMAT_STEREO16), chosen by channel count.
 * @param outSampleRate Receives the sample rate, truncated from the file's.
 * @return The sample data, which the caller owns and must free, or
 *   @c nullptr on any failure.
 * @ghidraAddress 0x153cd4
 */
void *MyGetOpenALAudioData(NSURL *inFileURL,
                           ALsizei *outDataSize,
                           ALenum *outDataFormat,
                           ALsizei *outSampleRate);

#ifdef __cplusplus
}
#endif

#endif

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :

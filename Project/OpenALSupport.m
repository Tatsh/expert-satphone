#import "OpenALSupport.h"

#include <stdio.h>
#include <stdlib.h>

#include <AudioToolbox/AudioToolbox.h>

// The maximum channel count this loader accepts. Anything of three channels or
// more is rejected as unsupported.
static const UInt32 kMaxSupportedChannels = 2;

// Signed 16-bit linear PCM: two bytes per sample per channel, sixteen bits per
// channel, packed signed integer.
static const UInt32 kBytesPerChannel = 2;
static const UInt32 kBitsPerChannel = 16;
static const UInt32 kFramesPerPacket = 1;

/** @ghidraAddress 0x153cd4 */
void *MyGetOpenALAudioData(NSURL *inFileURL,
                           ALsizei *outDataSize,
                           ALenum *outDataFormat,
                           ALsizei *outSampleRate) {
    SInt64 theFileLengthInFrames = 0;
    AudioStreamBasicDescription theFileFormat;
    UInt32 thePropertySize = sizeof(theFileFormat);
    ExtAudioFileRef extRef = nullptr;
    void *theData = nullptr;

    OSStatus status = ExtAudioFileOpenURL((__bridge CFURLRef)inFileURL, &extRef);
    if (status != noErr) {
        printf("MyGetOpenALAudioData: ExtAudioFileOpenURL FAILED, Error = %ld\n", (long)status);
        goto Exit;
    }

    // Get the audio data format.
    status = ExtAudioFileGetProperty(
        extRef, kExtAudioFileProperty_FileDataFormat, &thePropertySize, &theFileFormat);
    if (status != noErr) {
        printf("MyGetOpenALAudioData: "
               "ExtAudioFileGetProperty(kExtAudioFileProperty_FileDataFormat) FAILED, "
               "Error = %ld\n",
               (long)status);
        goto Exit;
    }

    if (theFileFormat.mChannelsPerFrame > kMaxSupportedChannels) {
        puts("MyGetOpenALAudioData - Unsupported Format, channel count is greater than stereo");
        goto Exit;
    }

    {
        // Set the client format to 16-bit signed integer (linear PCM) data.
        AudioStreamBasicDescription theOutputFormat;
        theOutputFormat.mSampleRate = theFileFormat.mSampleRate;
        theOutputFormat.mChannelsPerFrame = theFileFormat.mChannelsPerFrame;
        theOutputFormat.mFormatID = kAudioFormatLinearPCM;
        theOutputFormat.mBytesPerPacket = kBytesPerChannel * theFileFormat.mChannelsPerFrame;
        theOutputFormat.mFramesPerPacket = kFramesPerPacket;
        theOutputFormat.mBytesPerFrame = kBytesPerChannel * theFileFormat.mChannelsPerFrame;
        theOutputFormat.mBitsPerChannel = kBitsPerChannel;
        theOutputFormat.mFormatFlags = kAudioFormatFlagsNativeEndian |
                                       kLinearPCMFormatFlagIsPacked |
                                       kLinearPCMFormatFlagIsSignedInteger;

        // Set the desired client (output) data format.
        status = ExtAudioFileSetProperty(extRef,
                                         kExtAudioFileProperty_ClientDataFormat,
                                         sizeof(theOutputFormat),
                                         &theOutputFormat);
        if (status != noErr) {
            printf("MyGetOpenALAudioData: "
                   "ExtAudioFileSetProperty(kExtAudioFileProperty_ClientDataFormat) FAILED, "
                   "Error = %ld\n",
                   (long)status);
            goto Exit;
        }

        // Get the total frame count.
        thePropertySize = sizeof(theFileLengthInFrames);
        status = ExtAudioFileGetProperty(extRef,
                                         kExtAudioFileProperty_FileLengthFrames,
                                         &thePropertySize,
                                         &theFileLengthInFrames);
        if (status != noErr) {
            printf("MyGetOpenALAudioData: "
                   "ExtAudioFileGetProperty(kExtAudioFileProperty_FileLengthFrames) FAILED, "
                   "Error = %ld\n",
                   (long)status);
            goto Exit;
        }

        // Read all the data into memory.
        UInt32 dataSize = (UInt32)(theOutputFormat.mBytesPerFrame * theFileLengthInFrames);
        theData = malloc(dataSize);
        if (theData != nullptr) {
            AudioBufferList theDataBuffer;
            theDataBuffer.mNumberBuffers = 1;
            theDataBuffer.mBuffers[0].mDataByteSize = dataSize;
            theDataBuffer.mBuffers[0].mNumberChannels = theOutputFormat.mChannelsPerFrame;
            theDataBuffer.mBuffers[0].mData = theData;

            // Read the data into an AudioBufferList. The binary reuses the low 32 bits of the
            // 8-byte frame-count slot as the in/out frame count rather than a fresh local.
            status = ExtAudioFileRead(extRef, (UInt32 *)&theFileLengthInFrames, &theDataBuffer);
            if (status == noErr) {
                // Success.
                *outDataSize = (ALsizei)dataSize;
                *outDataFormat =
                    (theOutputFormat.mChannelsPerFrame > 1) ? AL_FORMAT_STEREO16 : AL_FORMAT_MONO16;
                *outSampleRate = (ALsizei)theOutputFormat.mSampleRate;
            } else {
                // Failure.
                free(theData);
                theData = nullptr;
                printf("MyGetOpenALAudioData: ExtAudioFileRead FAILED, Error = %ld\n",
                       (long)status);
            }
        }
    }

Exit:
    // Dispose the ExtAudioFileRef, it is no longer needed.
    if (extRef != nullptr) {
        ExtAudioFileDispose(extRef);
    }
    return theData;
}

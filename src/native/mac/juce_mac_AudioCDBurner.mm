/*
  ==============================================================================

   This file is part of the JUCE library - "Jules' Utility Class Extensions"
   Copyright 2004-10 by Raw Material Software Ltd.

  ------------------------------------------------------------------------------

   JUCE can be redistributed and/or modified under the terms of the GNU General
   Public License (Version 2), as published by the Free Software Foundation.
   A copy of the license is included in the JUCE distribution, or can be found
   online at www.gnu.org/licenses.

   JUCE is distributed in the hope that it will be useful, but WITHOUT ANY
   WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
   A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

  ------------------------------------------------------------------------------

   To release a closed-source product which uses JUCE, commercial licenses are
   available: visit www.rawmaterialsoftware.com/juce for more information.

  ==============================================================================
*/

// (This file gets included by juce_mac_NativeCode.mm, rather than being
// compiled on its own).
#if JUCE_INCLUDED_FILE && JUCE_USE_CDBURNER

//==============================================================================
const int kilobytesPerSecond1x = 176;

END_JUCE_NAMESPACE

#define OpenDiskDevice MakeObjCClassName(OpenDiskDevice)

@interface OpenDiskDevice   : NSObject
{
@public
    DRDevice* device;
    NSMutableArray* tracks;
    bool underrunProtection;
}

- (OpenDiskDevice*) initWithDRDevice: (DRDevice*) device;
- (void) dealloc;
- (void) addSourceTrack: (JUCE_NAMESPACE::AudioSource*) source numSamples: (int) numSamples_;
- (void) burn: (JUCE_NAMESPACE::AudioCDBurner::BurnProgressListener*) listener  errorString: (JUCE_NAMESPACE::String*) error
         ejectAfterwards: (bool) shouldEject isFake: (bool) peformFakeBurnForTesting speed: (int) burnSpeed;
@end

//==============================================================================
#define AudioTrackProducer MakeObjCClassName(AudioTrackProducer)

@interface AudioTrackProducer   : NSObject
{
    JUCE_NAMESPACE::AudioSource* source;
    int readPosition, lengthInFrames;
}

- (AudioTrackProducer*) init: (int) lengthInFrames;
- (AudioTrackProducer*) initWithAudioSource: (JUCE_NAMESPACE::AudioSource*) source numSamples: (int) lengthInSamples;
- (void) dealloc;
- (void) setupTrackProperties: (DRTrack*) track;

- (void) cleanupTrackAfterBurn: (DRTrack*) track;
- (BOOL) cleanupTrackAfterVerification:(DRTrack*)track;
- (uint64_t) estimateLengthOfTrack:(DRTrack*)track;
- (BOOL) prepareTrack:(DRTrack*)track forBurn:(DRBurn*)burn
         toMedia:(NSDictionary*)mediaInfo;
- (BOOL) prepareTrackForVerification:(DRTrack*)track;
- (uint32_t) produceDataForTrack:(DRTrack*)track intoBuffer:(char*)buffer
        length:(uint32_t)bufferLength atAddress:(uint64_t)address
        blockSize:(uint32_t)blockSize ioFlags:(uint32_t*)flags;
- (uint32_t) producePreGapForTrack:(DRTrack*)track
             intoBuffer:(char*)buffer length:(uint32_t)bufferLength
             atAddress:(uint64_t)address blockSize:(uint32_t)blockSize
             ioFlags:(uint32_t*)flags;
- (BOOL) verifyDataForTrack:(DRTrack*)track inBuffer:(const char*)buffer
         length:(uint32_t)bufferLength atAddress:(uint64_t)address
         blockSize:(uint32_t)blockSize ioFlags:(uint32_t*)flags;
- (uint32_t) producePreGapForTrack:(DRTrack*)track
        intoBuffer:(char*)buffer length:(uint32_t)bufferLength
        atAddress:(uint64_t)address blockSize:(uint32_t)blockSize
        ioFlags:(uint32_t*)flags;
@end

//==============================================================================
@implementation OpenDiskDevice

- (OpenDiskDevice*) initWithDRDevice: (DRDevice*) device_
{
    [super init];

    device = device_;
    tracks = [[NSMutableArray alloc] init];
    underrunProtection = true;
    return self;
}

- (void) dealloc
{
    [tracks release];
    [super dealloc];
}

- (void) addSourceTrack: (JUCE_NAMESPACE::AudioSource*) source_ numSamples: (int) numSamples_
{
    AudioTrackProducer* p = [[AudioTrackProducer alloc] initWithAudioSource: source_ numSamples: numSamples_];
    DRTrack* t = [[DRTrack alloc] initWithProducer: p];
    [p setupTrackProperties: t];

    [tracks addObject: t];

    [t release];
    [p release];
}

- (void) burn: (JUCE_NAMESPACE::AudioCDBurner::BurnProgressListener*) listener errorString: (JUCE_NAMESPACE::String*) error
         ejectAfterwards: (bool) shouldEject isFake: (bool) peformFakeBurnForTesting speed: (int) burnSpeed
{
    DRBurn* burn = [DRBurn burnForDevice: device];

    if (! [device acquireExclusiveAccess])
    {
        *error = "Couldn't open or write to the CD device";
        return;
    }

    [device acquireMediaReservation];

    NSMutableDictionary* d = [[burn properties] mutableCopy];
    [d autorelease];
    [d setObject: [NSNumber numberWithBool: peformFakeBurnForTesting] forKey: DRBurnTestingKey];
    [d setObject: [NSNumber numberWithBool: false] forKey: DRBurnVerifyDiscKey];
    [d setObject: (shouldEject ? DRBurnCompletionActionEject : DRBurnCompletionActionMount) forKey: DRBurnCompletionActionKey];

    if (burnSpeed > 0)
        [d setObject: [NSNumber numberWithFloat: burnSpeed * JUCE_NAMESPACE::kilobytesPerSecond1x] forKey: DRBurnRequestedSpeedKey];

    if (! underrunProtection)
        [d setObject: [NSNumber numberWithBool: false] forKey: DRBurnUnderrunProtectionKey];

    [burn setProperties: d];

    [burn writeLayout: tracks];

    for (;;)
    {
        JUCE_NAMESPACE::Thread::sleep (300);
        float progress = [[[burn status] objectForKey: DRStatusPercentCompleteKey] floatValue];

        if (listener != 0 && listener->audioCDBurnProgress (progress))
        {
            [burn abort];
            *error = "User cancelled the write operation";
            break;
        }

        if ([[[burn status] objectForKey: DRStatusStateKey] isEqualTo: DRStatusStateFailed])
        {
            *error = "Write operation failed";
            break;
        }
        else if ([[[burn status] objectForKey: DRStatusStateKey] isEqualTo: DRStatusStateDone])
        {
            break;
        }

        NSString* err = (NSString*) [[[burn status] objectForKey: DRErrorStatusKey]
                                                    objectForKey: DRErrorStatusErrorStringKey];

        if ([err length] > 0)
        {
            *error = JUCE_NAMESPACE::String::fromUTF8 ([err UTF8String]);
            break;
        }
    }

    [device releaseMediaReservation];
    [device releaseExclusiveAccess];
}
@end

//==============================================================================
@implementation AudioTrackProducer

- (AudioTrackProducer*) init: (int) lengthInFrames_
{
    lengthInFrames = lengthInFrames_;
    readPosition = 0;
    return self;
}

- (void) setupTrackProperties: (DRTrack*) track
{
    NSMutableDictionary*  p = [[track properties] mutableCopy];
    [p setObject:[DRMSF msfWithFrames: lengthInFrames] forKey: DRTrackLengthKey];
    [p setObject:[NSNumber numberWithUnsignedShort:2352] forKey: DRBlockSizeKey];
    [p setObject:[NSNumber numberWithInt:0] forKey: DRDataFormKey];
    [p setObject:[NSNumber numberWithInt:0] forKey: DRBlockTypeKey];
    [p setObject:[NSNumber numberWithInt:0] forKey: DRTrackModeKey];
    [p setObject:[NSNumber numberWithInt:0] forKey: DRSessionFormatKey];


    [track setProperties: p];
    [p release];
}

- (AudioTrackProducer*) initWithAudioSource: (JUCE_NAMESPACE::AudioSource*) source_ numSamples: (int) lengthInSamples
{
    AudioTrackProducer* s = [self init: (lengthInSamples + 587) / 588];

    if (s != nil)
        s->source = source_;

    return s;
}

- (void) dealloc
{
    if (source != 0)
    {
        source->releaseResources();
        delete source;
    }

    [super dealloc];
}

- (void) cleanupTrackAfterBurn: (DRTrack*) track
{
    (void) track;
}

- (BOOL) cleanupTrackAfterVerification: (DRTrack*) track
{
    (void) track;
    return true;
}

- (uint64_t) estimateLengthOfTrack: (DRTrack*) track
{
    (void) track;
    return lengthInFrames;
}

- (BOOL) prepareTrack: (DRTrack*) track forBurn: (DRBurn*) burn
         toMedia: (NSDictionary*) mediaInfo
{
    (void) track; (void) burn; (void) mediaInfo;

    if (source != 0)
        source->prepareToPlay (44100 / 75, 44100);

    readPosition = 0;
    return true;
}

- (BOOL) prepareTrackForVerification: (DRTrack*) track
{
    (void) track;
    if (source != 0)
        source->prepareToPlay (44100 / 75, 44100);

    return true;
}

- (uint32_t) produceDataForTrack: (DRTrack*) track intoBuffer: (char*) buffer
        length: (uint32_t) bufferLength atAddress: (uint64_t) address
        blockSize: (uint32_t) blockSize ioFlags: (uint32_t*) flags
{
    (void) track; (void) address; (void) blockSize; (void) flags;

    if (source != 0)
    {
        const int numSamples = JUCE_NAMESPACE::jmin ((int) bufferLength / 4, (lengthInFrames * (44100 / 75)) - readPosition);

        if (numSamples > 0)
        {
            JUCE_NAMESPACE::AudioSampleBuffer tempBuffer (2, numSamples);

            JUCE_NAMESPACE::AudioSourceChannelInfo info;
            info.buffer = &tempBuffer;
            info.startSample = 0;
            info.numSamples = numSamples;

            source->getNextAudioBlock (info);

            typedef JUCE_NAMESPACE::AudioData::Pointer <JUCE_NAMESPACE::AudioData::Int16,
                                                        JUCE_NAMESPACE::AudioData::LittleEndian,
                                                        JUCE_NAMESPACE::AudioData::Interleaved,
                                                        JUCE_NAMESPACE::AudioData::NonConst> CDSampleFormat;

            typedef JUCE_NAMESPACE::AudioData::Pointer <JUCE_NAMESPACE::AudioData::Float32,
                                                        JUCE_NAMESPACE::AudioData::NativeEndian,
                                                        JUCE_NAMESPACE::AudioData::NonInterleaved,
                                                        JUCE_NAMESPACE::AudioData::Const> SourceSampleFormat;
            CDSampleFormat left (buffer, 2);
            left.convertSamples (SourceSampleFormat (tempBuffer.getSampleData (0)), numSamples);
            CDSampleFormat right (buffer + 2, 2);
            right.convertSamples (SourceSampleFormat (tempBuffer.getSampleData (1)), numSamples);

            readPosition += numSamples;
        }

        return numSamples * 4;
    }

    return 0;
}

- (uint32_t) producePreGapForTrack: (DRTrack*) track
        intoBuffer: (char*) buffer length: (uint32_t) bufferLength
        atAddress: (uint64_t) address blockSize: (uint32_t) blockSize
        ioFlags: (uint32_t*) flags
{
    (void) track; (void) address; (void) blockSize; (void) flags;
    zeromem (buffer, bufferLength);
    return bufferLength;
}

- (BOOL) verifyDataForTrack: (DRTrack*) track inBuffer: (const char*) buffer
         length: (uint32_t) bufferLength atAddress: (uint64_t) address
         blockSize: (uint32_t) blockSize ioFlags: (uint32_t*) flags
{
    (void) track; (void) buffer; (void) bufferLength; (void) address; (void) blockSize; (void) flags;
    return true;
}

@end


BEGIN_JUCE_NAMESPACE

//==============================================================================
class AudioCDBurner::Pimpl  : public Timer
{
public:
    Pimpl (AudioCDBurner& owner_, const int deviceIndex)
        : device (0), owner (owner_)
    {
        DRDevice* dev = [[DRDevice devices] objectAtIndex: deviceIndex];
        if (dev != 0)
        {
            device = [[OpenDiskDevice alloc] initWithDRDevice: dev];
            lastState = getDiskState();
            startTimer (1000);
        }
    }

    ~Pimpl()
    {
        stopTimer();
        [device release];
    }

    void timerCallback()
    {
        const DiskState state = getDiskState();

        if (state != lastState)
        {
            lastState = state;
            owner.sendChangeMessage();
        }
    }

    DiskState getDiskState() const
    {
        if ([device->device isValid])
        {
            NSDictionary* status = [device->device status];

            NSString* state = [status objectForKey: DRDeviceMediaStateKey];

            if ([state isEqualTo: DRDeviceMediaStateNone])
            {
                if ([[status objectForKey: DRDeviceIsTrayOpenKey] boolValue])
                    return trayOpen;

                return noDisc;
            }

            if ([state isEqualTo: DRDeviceMediaStateMediaPresent])
            {
                if ([[[status objectForKey: DRDeviceMediaInfoKey] objectForKey: DRDeviceMediaBlocksFreeKey] intValue] > 0)
                    return writableDiskPresent;
                else
                    return readOnlyDiskPresent;
            }
        }

        return unknown;
    }

    bool openTray() { return [device->device isValid] && [device->device ejectMedia]; }

    const Array<int> getAvailableWriteSpeeds() const
    {
        Array<int> results;

        if ([device->device isValid])
        {
            NSArray* speeds = [[[device->device status] objectForKey: DRDeviceMediaInfoKey] objectForKey: DRDeviceBurnSpeedsKey];
            for (unsigned int i = 0; i < [speeds count]; ++i)
            {
                const int kbPerSec = [[speeds objectAtIndex: i] intValue];
                results.add (kbPerSec / kilobytesPerSecond1x);
            }
        }

        return results;
    }

    bool setBufferUnderrunProtection (const bool shouldBeEnabled)
    {
        if ([device->device isValid])
        {
            device->underrunProtection = shouldBeEnabled;
            return shouldBeEnabled && [[[device->device status] objectForKey: DRDeviceCanUnderrunProtectCDKey] boolValue];
        }

        return false;
    }

    int getNumAvailableAudioBlocks() const
    {
        return [[[[device->device status] objectForKey: DRDeviceMediaInfoKey]
                                          objectForKey: DRDeviceMediaBlocksFreeKey] intValue];
    }

    OpenDiskDevice* device;

private:
    DiskState lastState;
    AudioCDBurner& owner;
};

//==============================================================================
AudioCDBurner::AudioCDBurner (const int deviceIndex)
{
    pimpl = new Pimpl (*this, deviceIndex);
}

AudioCDBurner::~AudioCDBurner()
{
}

AudioCDBurner* AudioCDBurner::openDevice (const int deviceIndex)
{
    ScopedPointer <AudioCDBurner> b (new AudioCDBurner (deviceIndex));

    if (b->pimpl->device == 0)
        b = 0;

    return b.release();
}

namespace
{
    NSArray* findDiskBurnerDevices()
    {
        NSMutableArray* results = [NSMutableArray array];
        NSArray* devs = [DRDevice devices];

        for (int i = 0; i < [devs count]; ++i)
        {
            NSDictionary* dic = [[devs objectAtIndex: i] info];
            NSString* name = [dic valueForKey: DRDeviceProductNameKey];
            if (name != nil)
                [results addObject: name];
        }

        return results;
    }
}

const StringArray AudioCDBurner::findAvailableDevices()
{
    NSArray* names = findDiskBurnerDevices();
    StringArray s;

    for (unsigned int i = 0; i < [names count]; ++i)
        s.add (String::fromUTF8 ([[names objectAtIndex: i] UTF8String]));

    return s;
}

AudioCDBurner::DiskState AudioCDBurner::getDiskState() const
{
    return pimpl->getDiskState();
}

bool AudioCDBurner::isDiskPresent() const
{
    return getDiskState() == writableDiskPresent;
}

bool AudioCDBurner::openTray()
{
    return pimpl->openTray();
}

AudioCDBurner::DiskState AudioCDBurner::waitUntilStateChange (int timeOutMilliseconds)
{
    const int64 timeout = Time::currentTimeMillis() + timeOutMilliseconds;
    DiskState oldState = getDiskState();
    DiskState newState = oldState;

    while (newState == oldState && Time::currentTimeMillis() < timeout)
    {
        newState = getDiskState();
        Thread::sleep (100);
    }

    return newState;
}

const Array<int> AudioCDBurner::getAvailableWriteSpeeds() const
{
    return pimpl->getAvailableWriteSpeeds();
}

bool AudioCDBurner::setBufferUnderrunProtection (const bool shouldBeEnabled)
{
    return pimpl->setBufferUnderrunProtection (shouldBeEnabled);
}

int AudioCDBurner::getNumAvailableAudioBlocks() const
{
    return pimpl->getNumAvailableAudioBlocks();
}

bool AudioCDBurner::addAudioTrack (AudioSource* source, int numSamps)
{
    if ([pimpl->device->device isValid])
    {
        [pimpl->device addSourceTrack: source numSamples: numSamps];
        return true;
    }

    return false;
}

const String AudioCDBurner::burn (JUCE_NAMESPACE::AudioCDBurner::BurnProgressListener* listener,
                                  bool ejectDiscAfterwards,
                                  bool performFakeBurnForTesting,
                                  int writeSpeed)
{
    String error ("Couldn't open or write to the CD device");

    if ([pimpl->device->device isValid])
    {
        error = String::empty;

        [pimpl->device  burn: listener
                 errorString: &error
             ejectAfterwards: ejectDiscAfterwards
                      isFake: performFakeBurnForTesting
                       speed: writeSpeed];
    }

    return error;
}

#endif

//==============================================================================
#if JUCE_INCLUDED_FILE && JUCE_USE_CDREADER

void AudioCDReader::ejectDisk()
{
    const ScopedAutoReleasePool p;
    [[NSWorkspace sharedWorkspace] unmountAndEjectDeviceAtPath: juceStringToNS (volumeDir.getFullPathName())];
}

#endif

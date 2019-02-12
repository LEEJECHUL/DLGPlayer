//
//  DLGPlayer.m
//  DLGPlayer
//
//  Created by Liu Junqi on 09/12/2016.
//  Copyright © 2016 Liu Junqi. All rights reserved.
//

#import "DLGPlayer.h"
#import "DLGPlayerView.h"
#import "DLGPlayerDecoder.h"
#import "DLGPlayerDef.h"
#import "DLGPlayerAudioManager.h"
#import "DLGPlayerFrame.h"
#import "DLGPlayerVideoFrame.h"
#import "DLGPlayerAudioFrame.h"

@interface DLGPlayer ()

@property (nonatomic, strong) DLGPlayerView *view;
@property (nonatomic, strong) DLGPlayerDecoder *decoder;
@property (nonatomic, strong) DLGPlayerAudioManager *audio;

@property (nonatomic, strong) NSMutableArray *vframes;
@property (nonatomic, strong) NSMutableArray *aframes;
@property (nonatomic, strong) DLGPlayerAudioFrame *playingAudioFrame;
@property (nonatomic) NSUInteger playingAudioFrameDataPosition;
@property (atomic) double bufferedDuration;
@property (atomic) double mediaPosition;
@property (atomic) double mediaSyncTime;
@property (atomic) double mediaSyncPosition;

@property (nonatomic) BOOL notifiedBufferStart;
@property (nonatomic) BOOL requestSeek;
@property (nonatomic) double requestSeekPosition;
@property (atomic) BOOL closing;
@property (atomic) BOOL opening;
@property (nonatomic) BOOL renderBegan;

@property (nonatomic, strong) dispatch_semaphore_t vFramesLock;
@property (nonatomic, strong) dispatch_semaphore_t aFramesLock;
@property (nonatomic, strong) dispatch_queue_t processingQueue;
@end

@implementation DLGPlayer

- (id)init {
    self = [super init];
    if (self) {
        [self initAll];
    }
    return self;
}

- (void)dealloc {
    NSLog(@"DLGPlayer dealloc");
}

- (void)initAll {
    [self initVars];
    [self initAudio];
    [self initDecoder];
    [self initView];
}

- (void)initVars {
    _minBufferDuration = DLGPlayerMinBufferDuration;
    _maxBufferDuration = DLGPlayerMaxBufferDuration;
    _bufferedDuration = 0;
    _mediaPosition = 0;
    _mediaSyncTime = 0;
    _brightness = 1;
    _vframes = [NSMutableArray arrayWithCapacity:128];
    _aframes = [NSMutableArray arrayWithCapacity:128];
    _playingAudioFrame = nil;
    _playingAudioFrameDataPosition = 0;
    _closing = NO;
    _opening = NO;
    _buffering = NO;
    _playing = NO;
    _opened = NO;
    _requestSeek = NO;
    _renderBegan = NO;
    _requestSeekPosition = 0;
    _aFramesLock = dispatch_semaphore_create(1);
    _vFramesLock = dispatch_semaphore_create(1);
    _renderingQueue = dispatch_queue_create("DLGPlayer.renderingQueue", DISPATCH_QUEUE_SERIAL);
    _processingQueue = dispatch_queue_create("DLGPlayer.processingQueue", DISPATCH_QUEUE_SERIAL);
}

- (void)initView {
    DLGPlayerView *v = [[DLGPlayerView alloc] init];
    self.view = v;
}

- (void)initDecoder {
    self.decoder = [[DLGPlayerDecoder alloc] init];
}

- (void)initAudio {
    self.audio = [[DLGPlayerAudioManager alloc] init];
}

- (void)clearVars {
    [self.vframes removeAllObjects];
    [self.aframes removeAllObjects];
    self.playingAudioFrame = nil;
    self.playingAudioFrameDataPosition = 0;
    self.buffering = NO;
    self.playing = NO;
    self.opened = NO;
    self.renderBegan = NO;
    
    __weak typeof(self)weakSelf = self;
    
    dispatch_async(_processingQueue, ^{
        weakSelf.mediaPosition = 0;
        weakSelf.bufferedDuration = 0;
        weakSelf.mediaSyncTime = 0;
        weakSelf.closing = NO;
        weakSelf.opening = NO;
    });
    
    dispatch_async(_renderingQueue, ^{
        [weakSelf.view clear];
    });
}

- (void)open:(NSString *)url {
    __weak typeof(self)weakSelf = self;

    dispatch_async(_processingQueue, ^{
        if (weakSelf.opening) {
            return;
        }

        weakSelf.opening = YES;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            NSError *error = nil;
            if ([weakSelf.audio open:&error]) {
                weakSelf.decoder.audioChannels = [weakSelf.audio channels];
                weakSelf.decoder.audioSampleRate = [weakSelf.audio sampleRate];
            } else {
                [weakSelf handleError:error];
            }
        });
        
        NSError *error = nil;
        if (![weakSelf.decoder open:url error:&error]) {
            weakSelf.opening = NO;
            [weakSelf handleError:error];
            return;
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf.view setCurrentEAGLContext];
            
            weakSelf.view.isYUV = [weakSelf.decoder isYUV];
            weakSelf.view.keepLastFrame = [weakSelf.decoder hasPicture] && ![weakSelf.decoder hasVideo];
            weakSelf.view.rotation = weakSelf.decoder.rotation;
            weakSelf.view.contentSize = CGSizeMake([weakSelf.decoder videoWidth], [weakSelf.decoder videoHeight]);
            weakSelf.view.contentMode = UIViewContentModeScaleAspectFit;
            
            weakSelf.duration = weakSelf.decoder.duration;
            weakSelf.metadata = weakSelf.decoder.metadata;
            weakSelf.opening = NO;
            weakSelf.buffering = NO;
            weakSelf.playing = NO;
            weakSelf.bufferedDuration = 0;
            weakSelf.mediaPosition = 0;
            weakSelf.mediaSyncTime = 0;

            weakSelf.audio.frameReaderBlock = ^(float *data, UInt32 frames, UInt32 channels) {
                [weakSelf readAudioFrame:data frames:frames channels:channels];
            };
            
            weakSelf.opened = YES;
            [[NSNotificationCenter defaultCenter] postNotificationName:DLGPlayerNotificationOpened object:weakSelf];
        });
    });
}

- (void)close {
    [self pause];
    
    __strong typeof(self)strongSelf = self;
    
    dispatch_async(_processingQueue, ^{
        if (strongSelf.closing) {
            return;
        }
        
        strongSelf.closing = YES;
        [strongSelf.decoder prepareClose];
        [strongSelf.decoder close];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            NSArray<NSError *> *errors = nil;
            if ([strongSelf.audio close:&errors]) {
                [strongSelf clearVars];
                [[NSNotificationCenter defaultCenter] postNotificationName:DLGPlayerNotificationClosed object:strongSelf];
            } else {
                for (NSError *error in errors) {
                    [strongSelf handleError:error];
                }
            }
        });
    });
}

- (void)play {
    if (!self.opened || self.playing) return;
    
    self.playing = YES;
    
    [self render];
    
    __weak typeof(self)weakSelf = self;
    
    dispatch_async(_processingQueue, ^{
        [weakSelf runFrameReader];
    });
    
    NSError *error = nil;
    if (![self.audio play:&error]) {
        [self handleError:error];
    }
}

- (void)pause {
    self.playing = NO;
    
    NSError *error = nil;
    if (![self.audio pause:&error]) {
        [self handleError:error];
    }
}

- (UIImage *)snapshot {
    return [_view snapshot];
}

- (void)runFrameReader {
    @autoreleasepool {
        while (self.playing && !self.closing) {
            [self readFrame];
            if (self.requestSeek) {
                [self seekPositionInFrameReader];
            } else {
                [NSThread sleepForTimeInterval:1.5];
            }
        }
    }
}

- (void)readFrame {
    self.buffering = YES;
    
    NSMutableArray *tempVFrames = [NSMutableArray arrayWithCapacity:8];
    NSMutableArray *tempAFrames = [NSMutableArray arrayWithCapacity:8];
    double tempDuration = 0;
    dispatch_time_t t = dispatch_time(DISPATCH_TIME_NOW, 0.02 * NSEC_PER_SEC);
    
    while (self.playing && !self.closing && !self.decoder.isEOF && !self.requestSeek
           && (self.bufferedDuration + tempDuration) < self.maxBufferDuration) {
        @autoreleasepool {
            NSArray *fs = [self.decoder readFrames];
            if (fs == nil) { break; }
            if (fs.count == 0) { continue; }
            
            {
                for (DLGPlayerFrame *f in fs) {
                    if (f.type == kDLGPlayerFrameTypeVideo) {
                        [tempVFrames addObject:f];
                        tempDuration += f.duration;
                    }
                }
                
                long timeout = dispatch_semaphore_wait(self.vFramesLock, t);
                if (timeout == 0) {
                    if (tempVFrames.count > 0) {
                        self.bufferedDuration += tempDuration;
                        tempDuration = 0;
                        [self.vframes addObjectsFromArray:tempVFrames];
                        [tempVFrames removeAllObjects];
                    }
                    dispatch_semaphore_signal(self.vFramesLock);
                }
            }
            {
                for (DLGPlayerFrame *f in fs) {
                    if (f.type == kDLGPlayerFrameTypeAudio) {
                        [tempAFrames addObject:f];
                        if (!self.decoder.hasVideo) tempDuration += f.duration;
                    }
                }
                
                long timeout = dispatch_semaphore_wait(self.aFramesLock, t);
                if (timeout == 0) {
                    if (tempAFrames.count > 0) {
                        if (!self.decoder.hasVideo) {
                            self.bufferedDuration += tempDuration;
                            tempDuration = 0;
                        }
                        [self.aframes addObjectsFromArray:tempAFrames];
                        [tempAFrames removeAllObjects];
                    }
                    dispatch_semaphore_signal(self.aFramesLock);
                }
            }
        }
    }
    
    {
        // add the rest video frames
        while (tempVFrames.count > 0 || tempAFrames.count > 0) {
            if (tempVFrames.count > 0) {
                long timeout = dispatch_semaphore_wait(self.vFramesLock, t);
                if (timeout == 0) {
                    self.bufferedDuration += tempDuration;
                    tempDuration = 0;
                    [self.vframes addObjectsFromArray:tempVFrames];
                    [tempVFrames removeAllObjects];
                    dispatch_semaphore_signal(self.vFramesLock);
                }
            }
            if (tempAFrames.count > 0) {
                long timeout = dispatch_semaphore_wait(self.aFramesLock, t);
                if (timeout == 0) {
                    if (!self.decoder.hasVideo) {
                        self.bufferedDuration += tempDuration;
                        tempDuration = 0;
                    }
                    [self.aframes addObjectsFromArray:tempAFrames];
                    [tempAFrames removeAllObjects];
                    dispatch_semaphore_signal(self.aFramesLock);
                }
            }
        }
    }
    
    self.buffering = NO;
}

- (void)seekPositionInFrameReader {
    [self.decoder seek:self.requestSeekPosition];

    {
        dispatch_semaphore_wait(self.vFramesLock, DISPATCH_TIME_FOREVER);
        [self.vframes removeAllObjects];
        dispatch_semaphore_signal(self.vFramesLock);
    }
    {
        dispatch_semaphore_wait(self.aFramesLock, DISPATCH_TIME_FOREVER);
        [self.aframes removeAllObjects];
        dispatch_semaphore_signal(self.aFramesLock);
    }

    self.bufferedDuration = 0;
    self.requestSeek = NO;
    self.mediaSyncTime = 0;
    self.mediaPosition = self.requestSeekPosition;
}

- (void)render {
    if (!self.playing) return;

    BOOL eof = self.decoder.isEOF;
    BOOL noframes = ((self.decoder.hasVideo && self.vframes.count <= 0) ||
                     (self.decoder.hasAudio && self.aframes.count <= 0));
    
    // Check if reach the end and play all frames.
    if (noframes && eof) {
        [self pause];
        [[NSNotificationCenter defaultCenter] postNotificationName:DLGPlayerNotificationEOF object:self];
        return;
    }
    
    if (noframes && !self.notifiedBufferStart) {
        self.notifiedBufferStart = YES;
        NSDictionary *userInfo = @{ DLGPlayerNotificationBufferStateKey : @(self.notifiedBufferStart) };
        [[NSNotificationCenter defaultCenter] postNotificationName:DLGPlayerNotificationBufferStateChanged object:self userInfo:userInfo];
    } else if (!noframes && self.notifiedBufferStart && self.bufferedDuration >= self.minBufferDuration) {
        self.notifiedBufferStart = NO;
        NSDictionary *userInfo = @{ DLGPlayerNotificationBufferStateKey : @(self.notifiedBufferStart) };
        [[NSNotificationCenter defaultCenter] postNotificationName:DLGPlayerNotificationBufferStateChanged object:self userInfo:userInfo];
    }
    
    // Render if has picture
    if (self.decoder.hasPicture && self.vframes.count > 0) {
        DLGPlayerVideoFrame *frame = self.vframes[0];
        frame.brightness = _brightness;
        self.view.contentSize = CGSizeMake(frame.width, frame.height);
        [self.vframes removeObjectAtIndex:0];
        [self renderView:frame];
    }
    
    // Check whether render is neccessary
    if (self.vframes.count <= 0 || !self.decoder.hasVideo || self.notifiedBufferStart) {
        __weak typeof(self)weakSelf = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [weakSelf render];
        });
        return;
    }
    
    // Render video
    DLGPlayerVideoFrame *frame = nil;
    {
        long timeout = dispatch_semaphore_wait(self.vFramesLock, DISPATCH_TIME_NOW);
        if (timeout == 0) {
            frame = self.vframes[0];
            frame.brightness = _brightness;
            self.mediaPosition = frame.position;
            self.bufferedDuration -= frame.duration;
            [self.vframes removeObjectAtIndex:0];
            dispatch_semaphore_signal(self.vFramesLock);
        }
    }
    
    [self renderView:frame];
    
    // Sync audio with video
    double syncTime = [self syncTime];
    NSTimeInterval t = MAX(frame.duration + syncTime, 0.01);

    __weak typeof(self)weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(t * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [weakSelf render];
    });
}

- (void)renderView:(DLGPlayerVideoFrame *)frame {
    __weak typeof(self)weakSelf = self;
    
    dispatch_sync(_renderingQueue, ^{
        [weakSelf.view render:frame];
        
        if (!weakSelf.renderBegan && frame.width > 0 && frame.height > 0) {
            weakSelf.renderBegan = YES;
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:DLGPlayerNotificationRenderBegan object:weakSelf];
            });
        }
    });
}

- (double)syncTime {
    const double now = [NSDate timeIntervalSinceReferenceDate];
    
    if (self.mediaSyncTime == 0) {
        self.mediaSyncTime = now;
        self.mediaSyncPosition = self.mediaPosition;
        return 0;
    }
    
    double dp = self.mediaPosition - self.mediaSyncPosition;
    double dt = now - self.mediaSyncTime;
    double sync = dp - dt;
    
    if (sync > 1 || sync < -1) {
        sync = 0;
        self.mediaSyncTime = 0;
    }
    
    return sync;
}

/*
 * For audioUnitRenderCallback, (DLGPlayerAudioManagerFrameReaderBlock)readFrameBlock
 */
- (void)readAudioFrame:(float *)data frames:(UInt32)frames channels:(UInt32)channels {
    if (!self.playing) return;

    while(frames > 0) {
        @autoreleasepool {
            if (self.playingAudioFrame == nil) {
                {
                    if (self.aframes.count <= 0) {
                        memset(data, 0, frames * channels * sizeof(float));
                        return;
                    }
                    
                    long timeout = dispatch_semaphore_wait(self.aFramesLock, DISPATCH_TIME_NOW);
                    if (timeout == 0) {
                        DLGPlayerAudioFrame *frame = self.aframes[0];
                        if (self.decoder.hasVideo) {
                            const double dt = self.mediaPosition - frame.position;
                            if (dt < -0.1) { // audio is faster than video, silence
                                memset(data, 0, frames * channels * sizeof(float));
                                dispatch_semaphore_signal(self.aFramesLock);
                                break;
                            } else if (dt > 0.1) { // audio is slower than video, skip
                                [self.aframes removeObjectAtIndex:0];
                                dispatch_semaphore_signal(self.aFramesLock);
                                continue;
                            } else {
                                self.playingAudioFrameDataPosition = 0;
                                self.playingAudioFrame = frame;
                                [self.aframes removeObjectAtIndex:0];
                            }
                        } else {
                            self.playingAudioFrameDataPosition = 0;
                            self.playingAudioFrame = frame;
                            [self.aframes removeObjectAtIndex:0];
                            self.mediaPosition = frame.position;
                            self.bufferedDuration -= frame.duration;
                        }
                        dispatch_semaphore_signal(self.aFramesLock);
                    } else return;
                }
            }
            
            NSData *frameData = self.playingAudioFrame.data;
            NSUInteger pos = self.playingAudioFrameDataPosition;
            if (frameData == nil) {
                memset(data, 0, frames * channels * sizeof(float));
                return;
            }
            
            const void *bytes = (Byte *)frameData.bytes + pos;
            const NSUInteger remainingBytes = frameData.length - pos;
            const NSUInteger channelSize = channels * sizeof(float);
            const NSUInteger bytesToCopy = MIN(frames * channelSize, remainingBytes);
            const NSUInteger framesToCopy = bytesToCopy / channelSize;
            
            memcpy(data, bytes, bytesToCopy);
            frames -= framesToCopy;
            data += framesToCopy * channels;
            
            if (bytesToCopy < remainingBytes) {
                self.playingAudioFrameDataPosition += bytesToCopy;
            } else {
                self.playingAudioFrame = nil;
            }
        }
    }
}

- (UIView *)playerView {
    return self.view;
}

- (void)setPosition:(double)position {
    self.requestSeekPosition = position;
    self.requestSeek = YES;
}

- (double)position {
    return self.mediaPosition;
}

#pragma mark - Handle Error
- (void)handleError:(NSError *)error {
    if (error == nil) return;
    NSDictionary *userInfo = @{ DLGPlayerNotificationErrorKey : error };
    __weak typeof(self)weakSelf = self;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:DLGPlayerNotificationError object:weakSelf userInfo:userInfo];
    });
}

@end

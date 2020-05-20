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
#import "DLGPlayerVideoFrameView.h"
#import "MetalPlayerView.h"

@interface DLGPlayer ()
@property (nonatomic) BOOL closing;
@property (nonatomic) BOOL opening;
@property (nonatomic) BOOL frameDropped;
@property (nonatomic) BOOL notifiedBufferStart;
@property (nonatomic) BOOL renderBegan;
@property (nonatomic) BOOL requestSeek;
@property (nonatomic) double bufferedDuration;
@property (nonatomic) double mediaPosition;
@property (nonatomic) double mediaSyncPosition;
@property (nonatomic) double mediaSyncTime;
@property (nonatomic) double requestSeekPosition;
@property (nonatomic) NSUInteger playingAudioFrameDataPosition;
@property (nonatomic, strong) NSMutableArray *vframes;
@property (nonatomic, strong) NSMutableArray *aframes;
@property (nonatomic, strong) dispatch_queue_t frameReaderQueue;
@property (nonatomic, strong) dispatch_queue_t processingQueue;
@property (nonatomic, strong) dispatch_queue_t renderingQueue;
@property (nonatomic, strong) dispatch_semaphore_t vFramesLock;
@property (nonatomic, strong) dispatch_semaphore_t aFramesLock;
@property (nonatomic, strong) DLGPlayerAudioFrame *playingAudioFrame;
@property (nonatomic, strong) DLGPlayerDecoder *decoder;
@property (nonatomic, strong) DLGPlayerAudioManager *audio;
@property (nonatomic, strong) id<DLGPlayerVideoFrameView> view;
@end

@implementation DLGPlayer

#pragma mark - Public Properties

- (UIView *)playerView {
    return (UIView *) _view;
}

- (void)setPosition:(double)position {
    self.requestSeekPosition = position;
    self.requestSeek = YES;
}

- (double)position {
    return self.mediaPosition;
}

- (void)setSpeed:(double)speed {
    _speed = speed;
    self.decoder.speed = speed;
}

- (void)setMute:(BOOL)mute {
    _mute = mute;
    self.audio.mute = mute;
}

#pragma mark - Con(De)structors

- (id)init {
    self = [super init];
    if (self) {
        [self initAll];
    }
    return self;
}

- (void)dealloc {
    if (DLGPlayerUtils.debugEnabled) {
        NSLog(@"DLGPlayer dealloc");
    }
}

#pragma mark - Public Methods

- (void)open:(NSString *)url {
    __weak typeof(self)weakSelf = self;
    
    dispatch_async(self.processingQueue, ^{
        __strong typeof(weakSelf)strongSelf = weakSelf;
        
        if (!strongSelf || strongSelf.opening || strongSelf.closing) {
            return;
        }
        
        strongSelf.opening = YES;
        
        if (!strongSelf.audio.opened && [strongSelf.audio open:nil]) {
            strongSelf.decoder.audioChannels = [strongSelf.audio channels];
            strongSelf.decoder.audioSampleRate = [strongSelf.audio sampleRate];
            
            [[NSNotificationCenter defaultCenter] postNotificationName:DLGPlayerNotificationAudioOpened object:self];
        }

        NSError *error = nil;
        if (![strongSelf.decoder open:url error:&error]) {
            strongSelf.opening = NO;
            [strongSelf handleError:error];
            return;
        }
        
        strongSelf.duration = strongSelf.decoder.duration;
        strongSelf.metadata = strongSelf.decoder.metadata;
        strongSelf.opening = NO;
        strongSelf.buffering = NO;
        strongSelf.playing = NO;
        strongSelf.bufferedDuration = 0;
        strongSelf.mediaPosition = 0;
        strongSelf.mediaSyncTime = 0;
        strongSelf.view.isYUV = [strongSelf.decoder isYUV];
        strongSelf.view.keepLastFrame = [strongSelf.decoder hasPicture] && ![strongSelf.decoder hasVideo];
        strongSelf.view.rotation = strongSelf.decoder.rotation;
        strongSelf.view.contentSize = CGSizeMake([strongSelf.decoder videoWidth], [strongSelf.decoder videoHeight]);

        __weak typeof(strongSelf)ws = strongSelf;
        strongSelf.audio.frameReaderBlock = ^(float *data, UInt32 frames, UInt32 channels) {
            [ws readAudioFrame:data frames:frames channels:channels];
        };
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([strongSelf.view isKindOfClass:[DLGPlayerView class]]) {
                DLGPlayerView *view = (DLGPlayerView *) strongSelf.view;
                [view setCurrentEAGLContext];
            }
            
            strongSelf.opened = YES;

            [[NSNotificationCenter defaultCenter] postNotificationName:DLGPlayerNotificationOpened object:strongSelf];
        });
    });
}

- (void)close {
    [self close:NO];
}

- (void)closeAudio {
    __weak typeof(self)weakSelf = self;
    
    dispatch_async(self.processingQueue, ^{
        __strong typeof(weakSelf)strongSelf = weakSelf;
        
        if (strongSelf && [strongSelf.audio close:nil]) {
            [[NSNotificationCenter defaultCenter] postNotificationName:DLGPlayerNotificationAudioClosed object:strongSelf];
        }
    });
}

- (void)closeCompletely {
    [self close:YES];
}

- (void)play {
    __weak typeof(self)weakSelf = self;
    
    NSDate *now = [NSDate date];
    
    dispatch_async(self.processingQueue, ^{
        __strong typeof(weakSelf)strongSelf = weakSelf;
        
        if (!strongSelf || !strongSelf.opened || strongSelf.playing || strongSelf.closing) {
            return;
        }
        
        strongSelf.playing = YES;

        [strongSelf.audio play];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [strongSelf render];
        });
        
        dispatch_async(strongSelf.frameReaderQueue, ^{
            [strongSelf runFrameReader];
        });
    });
}

- (void)pause {
    __weak typeof(self)weakSelf = self;
    
    dispatch_async(self.processingQueue, ^{
        __strong typeof(weakSelf)strongSelf = weakSelf;
        
        if (strongSelf.playing) {
            strongSelf.playing = NO;
            
            [strongSelf.audio pause];
        }
    });
}

- (UIImage *)snapshot {
    return [_view snapshot];
}

#pragma mark - Private Methods

- (void)initAll {
    [self initVars];
    [self initAudio];
    [self initDecoder];
    [self initView];
}

- (void)initVars {
    _allowsFrameDrop = NO;
    _requestSeek = NO;
    _renderBegan = NO;
    _frameDropDuration = DLGPlayerFrameDropDuration;
    _minBufferDuration = DLGPlayerMinBufferDuration;
    _maxBufferDuration = DLGPlayerMaxBufferDuration;
    _mediaSyncTime = 0;
    _brightness = 1;
    _requestSeekPosition = 0;
    _speed = 1.0;
    
    self.buffering = NO;
    self.closing = NO;
    self.opening = NO;
    self.playing = NO;
    self.opened = NO;
    self.frameDropped = NO;
    self.bufferedDuration = 0;
    self.mediaPosition = 0;
    self.playingAudioFrameDataPosition = 0;
    self.playingAudioFrame = nil;
    
    _aFramesLock = dispatch_semaphore_create(1);
    _vFramesLock = dispatch_semaphore_create(1);
    _vframes = [NSMutableArray arrayWithCapacity:128];
    _aframes = [NSMutableArray arrayWithCapacity:128];
    
    @autoreleasepool {
        NSString *frameReaderQueueName = [NSString stringWithFormat:@"DLGPlayer.frameReaderQueue::%zd", self.hash];
        NSString *processingQueueName = [NSString stringWithFormat:@"DLGPlayer.processingQueue::%zd", self.hash];
        NSString *renderingQueueName = [NSString stringWithFormat:@"DLGPlayer.renderingQueue::%zd", self.hash];
        _frameReaderQueue = dispatch_queue_create(frameReaderQueueName.UTF8String, DISPATCH_QUEUE_SERIAL);
        _processingQueue = dispatch_queue_create(processingQueueName.UTF8String, DISPATCH_QUEUE_SERIAL);
        _renderingQueue = dispatch_queue_create(renderingQueueName.UTF8String, DISPATCH_QUEUE_SERIAL);
    }
}

- (void)initView {
    if (@available(iOS 9.0, *)) {
        _view = [DLGPlayerUtils isMetalSupport] ? [[MetalPlayerView alloc] init] : [[DLGPlayerView alloc] init];
    } else {
        _view = [[DLGPlayerView alloc] init];
    }
    ((UIView *) _view).contentMode = UIViewContentModeScaleToFill;
}

- (void)initDecoder {
    self.decoder = [[DLGPlayerDecoder alloc] init];
    self.decoder.speed = self.speed;
}

- (void)initAudio {
    self.audio = [[DLGPlayerAudioManager alloc] init];
}

- (void)clearVars {
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
    
    self.buffering = NO;
    self.closing = NO;
    self.frameDropped = NO;
    self.opened = NO;
    self.opening = NO;
    self.playing = NO;
    self.renderBegan = NO;
    self.bufferedDuration = 0;
    self.mediaPosition = 0;
    self.mediaSyncTime = 0;
    self.playingAudioFrameDataPosition = 0;
    self.playingAudioFrame = nil;
}

- (void)close:(BOOL)completely {
    __weak typeof(self)weakSelf = self;
    
    dispatch_async(self.processingQueue, ^{
        __strong typeof(weakSelf)strongSelf = weakSelf;
        
        if (!strongSelf || strongSelf.closing || !strongSelf.opened) {
            return;
        }
        
        strongSelf.closing = YES;
        strongSelf.playing = NO;
        
        if (completely) {
            [strongSelf.audio close:nil];
        } else {
            [strongSelf.audio pause];
        }
        
        dispatch_async(strongSelf.frameReaderQueue, ^{
            [strongSelf.decoder prepareClose];
            [strongSelf.decoder close];
        });
        
        [strongSelf.view clear];
        [strongSelf clearVars];
        [[NSNotificationCenter defaultCenter] postNotificationName:DLGPlayerNotificationClosed object:strongSelf];
    });
}

- (void)runFrameReader {
    while (self.playing && !self.closing) {
        [self readFrame];
        
        if (self.requestSeek) {
            [self seekPositionInFrameReader];
        } else {
            [NSThread sleepForTimeInterval:1.5];
        }
    }
}

- (void)readFrame {
    self.buffering = YES;

    double tempDuration = 0;
    NSMutableArray *tempVFrames = [NSMutableArray arrayWithCapacity:8];
    NSMutableArray *tempAFrames = [NSMutableArray arrayWithCapacity:8];
    dispatch_time_t t = dispatch_time(DISPATCH_TIME_NOW, 0.02 * NSEC_PER_SEC);
    
    while (self.playing && !self.closing && !self.decoder.isEOF && !self.requestSeek) {
        // Drop frames
        if (self.allowsFrameDrop && !self.frameDropped) {
            if (self.bufferedDuration > self.frameDropDuration / self.speed) {
                if (dispatch_semaphore_wait(self.vFramesLock, t) == 0) {
                    for (DLGPlayerFrame *f in self.vframes) {
                        f.dropFrame = YES;
                    }
                    dispatch_semaphore_signal(self.vFramesLock);
                }
                
                if (dispatch_semaphore_wait(self.aFramesLock, t) == 0) {
                    for (DLGPlayerFrame *f in self.aframes) {
                        f.dropFrame = YES;
                    }
                    dispatch_semaphore_signal(self.aFramesLock);
                }
                
                self.frameDropped = YES;
                
                if (DLGPlayerUtils.debugEnabled) {
                    NSLog(@"DLGPlayer occurred drop frames beacuse buffer duration is over than frame drop duration.");
                }
                continue;
            }
        } else if (self.bufferedDuration > self.maxBufferDuration / self.speed) {
            continue;
        }

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
                if (self.mute) {
                    if (DLGPlayerUtils.debugEnabled) {
                        NSLog(@"DLGPlayer skip audio frames cause mute is enabled.");
                    }
                } else {
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
    BOOL noframes = ((self.decoder.hasVideo && self.vframes.count <= 0) &&
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
    } else if (!noframes && self.notifiedBufferStart && self.bufferedDuration >= self.minBufferDuration / self.speed) {
        self.notifiedBufferStart = NO;
        NSDictionary *userInfo = @{ DLGPlayerNotificationBufferStateKey : @(self.notifiedBufferStart) };
        [[NSNotificationCenter defaultCenter] postNotificationName:DLGPlayerNotificationBufferStateChanged object:self userInfo:userInfo];
    }
    
    // Render if has picture
    if (self.decoder.hasPicture && self.vframes.count > 0) {
        DLGPlayerVideoFrame *frame = self.vframes[0];
        frame.brightness = _brightness;
        _view.contentSize = CGSizeMake(frame.width, frame.height);
        
        if (dispatch_semaphore_wait(self.vFramesLock, DISPATCH_TIME_NOW) == 0) {
            [self.vframes removeObjectAtIndex:0];
            dispatch_semaphore_signal(self.vFramesLock);
            [self renderView:frame];
        }
    }
    
    // Check whether render is neccessary
    if (self.vframes.count <= 0 || !self.decoder.hasVideo || self.notifiedBufferStart) {
        __weak typeof(self)weakSelf = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t) (0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf)strongSelf = weakSelf;
            
            if (strongSelf) {
                [strongSelf render];
            }
        });
        return;
    }
    
    // Render video
    DLGPlayerVideoFrame *frame = nil;
    {
        if (dispatch_semaphore_wait(self.vFramesLock, DISPATCH_TIME_NOW) == 0) {
            frame = self.vframes[0];
            [self.vframes removeObjectAtIndex:0];
            frame.brightness = _brightness;
            self.mediaPosition = frame.position;
            self.bufferedDuration -= frame.duration;
            dispatch_semaphore_signal(self.vFramesLock);
        }
    }
    
    [self renderView:frame];
    
    NSTimeInterval t;
    if (self.speed > 1) {
        t = frame.duration;
    } else {
        t = frame.dropFrame ? 0.01 : MAX(frame.duration + [self syncTime], 0.01);
    }
    
    __weak typeof(self)weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t) (t * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf)strongSelf = weakSelf;
        
        if (strongSelf) {
            [strongSelf render];
        }
    });
}

- (void)renderView:(DLGPlayerVideoFrame *)frame {
    __weak typeof(self)weakSelf = self;
    
    dispatch_sync(self.renderingQueue, ^{
        __strong typeof(weakSelf)strongSelf = weakSelf;
        
        if (!strongSelf) {
            return;
        }
        
        [strongSelf.view render:frame];
        
        if (!strongSelf.renderBegan && frame.width > 0 && frame.height > 0) {
            strongSelf.renderBegan = YES;
            [[NSNotificationCenter defaultCenter] postNotificationName:DLGPlayerNotificationRenderBegan object:strongSelf];
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
    if (!self.playing) {
        return;
    }
    
    while(frames > 0) {
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
                        
                        if (dt < -0.1 && self.vframes.count > 0) { // audio is faster than video, silence
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

- (void)handleError:(NSError *)error {
    if (error == nil) {
        return;
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:DLGPlayerNotificationError object:self userInfo:@{DLGPlayerNotificationErrorKey: error}];
}

@end

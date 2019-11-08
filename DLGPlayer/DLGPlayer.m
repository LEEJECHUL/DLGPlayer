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
@property (nonatomic, readonly) BOOL isAvilableMetal;
@property (nonatomic, readonly) BOOL isDeviceSupportMetal;
@property (nonatomic) BOOL notifiedBufferStart;
@property (nonatomic) BOOL requestSeek;
@property (nonatomic) double requestSeekPosition;
@property (nonatomic, strong) dispatch_queue_t processingQueue;
@property (nonatomic, strong) dispatch_queue_t renderingQueue;
@property (nonatomic, strong) DLGPlayerDecoder *decoder;
@property (nonatomic, strong) DLGPlayerAudioManager *audio;
@property (nonatomic, strong) id<DLGPlayerVideoFrameView> view;

@property (atomic) BOOL closing;
@property (atomic) BOOL opening;
@property (atomic) BOOL renderBegan;
@property (atomic) double bufferedDuration;
@property (atomic) double mediaPosition;
@property (atomic) double mediaSyncTime;
@property (atomic) double mediaSyncPosition;
@property (atomic) NSUInteger playingAudioFrameDataPosition;
@property (atomic, strong) DLGPlayerAudioFrame *playingAudioFrame;
@property (atomic, strong) NSMutableArray *vframes;
@property (atomic, strong) NSMutableArray *aframes;
@end

static dispatch_queue_t processingQueueStatic;

@implementation DLGPlayer

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

- (void)initAll {
    _isDeviceSupportMetal = MTLCreateSystemDefaultDevice() != nil;
    
    [self initVars];
    [self initAudio];
    [self initDecoder];
    [self initView];
}

- (void)initVars {
    _minBufferDuration = DLGPlayerMinBufferDuration;
    _maxBufferDuration = DLGPlayerMaxBufferDuration;
    _mediaSyncTime = 0;
    _brightness = 1;
    _allowsFrameDrop = NO;
    _requestSeek = NO;
    _renderBegan = NO;
    _requestSeekPosition = 0;
    _speed = 1.0;
    _renderingQueue = dispatch_queue_create([[NSString stringWithFormat:@"DLGPlayer.renderingQueue::%zd", self.hash] UTF8String], DISPATCH_QUEUE_SERIAL);
    
    self.buffering = NO;
    self.closing = NO;
    self.opening = NO;
    self.playing = NO;
    self.opened = NO;
    self.bufferedDuration = 0;
    self.mediaPosition = 0;
    self.playingAudioFrameDataPosition = 0;
    self.playingAudioFrame = nil;
    self.vframes = [NSMutableArray arrayWithCapacity:128];
    self.aframes = [NSMutableArray arrayWithCapacity:128];
    
    if (self.isAvilableMetal) {
        _processingQueue = dispatch_queue_create([[NSString stringWithFormat:@"DLGPlayer.processingQueue::%zd", self.hash] UTF8String], DISPATCH_QUEUE_SERIAL);
    } else if (!processingQueueStatic) {
        processingQueueStatic = dispatch_queue_create("DLGPlayer.processingQueue", DISPATCH_QUEUE_SERIAL);
    }
}

- (void)initView {
    if (self.isAvilableMetal) {
        if (@available(iOS 9.0, *)) {
            _view = [MetalPlayerView new];
        }
    } else {
        _view = [DLGPlayerView new];
    }
}

- (void)initDecoder {
    self.decoder = [[DLGPlayerDecoder alloc] init];
    self.decoder.speed = self.speed;
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
    self.mediaPosition = 0;
    self.bufferedDuration = 0;
    self.mediaSyncTime = 0;
    self.closing = NO;
    self.opening = NO;
}

- (dispatch_queue_t)processingQueue {
    if (self.isAvilableMetal) {
        return _processingQueue;
    } else {
        return processingQueueStatic;
    }
}

- (void)open:(NSString *)url {
    __weak typeof(self)weakSelf = self;
    
    dispatch_async(self.processingQueue, ^{
        __strong typeof(self)strongSelf = weakSelf;
        
        if (!strongSelf || strongSelf.opening || strongSelf.closing) {
            return;
        }
        
        strongSelf.opening = YES;
        
        @autoreleasepool {
            NSError *error = nil;
            if ([strongSelf.audio open:&error]) {
                strongSelf.decoder.audioChannels = [strongSelf.audio channels];
                strongSelf.decoder.audioSampleRate = [strongSelf.audio sampleRate];
            } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [strongSelf handleError:error];
                });
            }
            
            if (![strongSelf.decoder open:url error:&error]) {
                strongSelf.opening = NO;
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    [strongSelf handleError:error];
                });
                return;
            }
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!strongSelf.opening || strongSelf.closing) {
                return;
            }
            
            if ([strongSelf.view isKindOfClass:[DLGPlayerView class]]) {
                DLGPlayerView *view = (DLGPlayerView *) strongSelf.view;
                [view setCurrentEAGLContext];
            }
            
            strongSelf.view.isYUV = [strongSelf.decoder isYUV];
            strongSelf.view.keepLastFrame = [strongSelf.decoder hasPicture] && ![strongSelf.decoder hasVideo];
            strongSelf.view.rotation = strongSelf.decoder.rotation;
            strongSelf.view.contentSize = CGSizeMake([strongSelf.decoder videoWidth], [strongSelf.decoder videoHeight]);
            
            if ([strongSelf.view isKindOfClass:[UIView class]]) {
                ((UIView *) strongSelf.view).contentMode = UIViewContentModeScaleToFill;
            }
            
            strongSelf.duration = self.decoder.duration;
            strongSelf.metadata = self.decoder.metadata;
            strongSelf.opening = NO;
            strongSelf.buffering = NO;
            strongSelf.playing = NO;
            strongSelf.bufferedDuration = 0;
            strongSelf.mediaPosition = 0;
            strongSelf.mediaSyncTime = 0;
            
            __weak typeof(strongSelf)ws = strongSelf;
            strongSelf.audio.frameReaderBlock = ^(float *data, UInt32 frames, UInt32 channels) {
                [ws readAudioFrame:data frames:frames channels:channels];
            };
            
            strongSelf.opened = YES;
            
            [[NSNotificationCenter defaultCenter] postNotificationName:DLGPlayerNotificationOpened object:strongSelf];
        });
    });
}

- (void)close {
    [self pause];
    
    dispatch_async(self.processingQueue, ^{
        if (self.closing) {
            return;
        }
        
        self.closing = YES;
        
        [self.decoder prepareClose];
        [self.decoder close];
        [self.view clear];
        
        @autoreleasepool {
            NSArray<NSError *> *errors = nil;
            
            if ([self.audio close:&errors]) {
                [self clearVars];
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[NSNotificationCenter defaultCenter] postNotificationName:DLGPlayerNotificationClosed object:self];
                });
            } else {
                [self clearVars];
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    for (NSError *error in errors) {
                        [self handleError:error];
                    }
                });
            }
        }
    });
}

- (void)play {
    dispatch_async(self.processingQueue, ^{
        if (!self.opened || self.playing || self.closing) {
            return;
        }
        
        self.playing = YES;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self render];
            
            @autoreleasepool {
                NSError *error = nil;
                
                if (![self.audio play:&error]) {
                    [self handleError:error];
                }
            }
        });
        
        [self runFrameReader];
    });
}

- (void)pause {
    self.playing = NO;
    
    @autoreleasepool {
        NSError *error = nil;
        if (![self.audio pause:&error]) {
            [self handleError:error];
        }
    }
}

- (UIImage *)snapshot {
    return [_view snapshot];
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
    
    @autoreleasepool {
        NSMutableArray *tempVFrames = [NSMutableArray arrayWithCapacity:8];
        NSMutableArray *tempAFrames = [NSMutableArray arrayWithCapacity:8];
        double tempDuration = 0;
        
        while (self.playing && !self.closing && !self.decoder.isEOF && !self.requestSeek) {
            if (self.bufferedDuration + tempDuration > self.maxBufferDuration / self.speed) {
                if (self.allowsFrameDrop) {
                    [self.vframes removeAllObjects];
                    [self.aframes removeAllObjects];
                    
                    self.bufferedDuration = 0;
                    
                    if (DLGPlayerUtils.debugEnabled) {
                        NSLog(@"DLGPlayer drop frames beacuse buffer duration is over than max duration.");
                    }
                } else {
                    continue;
                }
            }
            
            NSArray *fs = [self.decoder readFrames];
            
            if (DLGPlayerUtils.debugEnabled) {
                NSLog(@"DLGPlayer readFrames -> readed: %zd, vframes: %zd", fs.count, self.vframes.count);
            }
            
            if (fs == nil) { break; }
            if (fs.count == 0) { continue; }
            
            {
                for (DLGPlayerFrame *f in fs) {
                    if (f.type == kDLGPlayerFrameTypeVideo) {
                        [tempVFrames addObject:f];
                        tempDuration += f.duration;
                    }
                }
                
                if (tempVFrames.count > 0) {
                    self.bufferedDuration += tempDuration;
                    tempDuration = 0;
                    
                    [self.vframes addObjectsFromArray:tempVFrames];
                    [tempVFrames removeAllObjects];
                }
            }
            {
                for (DLGPlayerFrame *f in fs) {
                    if (f.type == kDLGPlayerFrameTypeAudio) {
                        [tempAFrames addObject:f];
                        if (!self.decoder.hasVideo) tempDuration += f.duration;
                    }
                }
                
                if (tempAFrames.count > 0) {
                    if (!self.decoder.hasVideo) {
                        self.bufferedDuration += tempDuration;
                        tempDuration = 0;
                    }
                    [self.aframes addObjectsFromArray:tempAFrames];
                    [tempAFrames removeAllObjects];
                }
            }
        }
        
        {
            // add the rest video frames
            while (tempVFrames.count > 0 || tempAFrames.count > 0) {
                if (tempVFrames.count > 0) {
                    self.bufferedDuration += tempDuration;
                    tempDuration = 0;
                    [self.vframes addObjectsFromArray:tempVFrames];
                    [tempVFrames removeAllObjects];
                }
                if (tempAFrames.count > 0) {
                    if (!self.decoder.hasVideo) {
                        self.bufferedDuration += tempDuration;
                        tempDuration = 0;
                    }
                    [self.aframes addObjectsFromArray:tempAFrames];
                    [tempAFrames removeAllObjects];
                }
            }
        }
    }
    
    self.buffering = NO;
}

- (void)seekPositionInFrameReader {
    [self.decoder seek:self.requestSeekPosition];
    [self.vframes removeAllObjects];
    [self.aframes removeAllObjects];
    
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
        [self.vframes removeObjectAtIndex:0];
        [self renderView:frame];
    }
    
    // Check whether render is neccessary
    if (self.vframes.count <= 0 || !self.decoder.hasVideo || self.notifiedBufferStart) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t) (0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self render];
        });
        return;
    }
    
    // Render video
    DLGPlayerVideoFrame *frame = nil;
    {
        frame = self.vframes[0];
        frame.brightness = _brightness;
        self.mediaPosition = frame.position;
        self.bufferedDuration -= frame.duration;
        [self.vframes removeObjectAtIndex:0];
    }
    
    [self renderView:frame];
    
    // Sync audio with video
//    double syncTime = [self syncTime];
    NSTimeInterval t = frame.duration;
    
    if (DLGPlayerUtils.debugEnabled) {
        NSLog(@"DLGPlayer render -> speed: %f, frames: %zd, bufferedDuration: %f, delay: %f", self.speed, self.vframes.count, self.bufferedDuration, t);
    }
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t) (t * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self render];
    });
}

- (void)renderView:(DLGPlayerVideoFrame *)frame {
    dispatch_sync(self.renderingQueue, ^{
        [self.view render:frame];
        
        if (!self.renderBegan && frame.width > 0 && frame.height > 0) {
            self.renderBegan = YES;
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:DLGPlayerNotificationRenderBegan object:self];
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
                    
                    DLGPlayerAudioFrame *frame = self.aframes[0];
                    if (self.decoder.hasVideo) {
                        const double dt = self.mediaPosition - frame.position;
                        if (dt < -0.1) { // audio is faster than video, silence
                            memset(data, 0, frames * channels * sizeof(float));
                            break;
                        } else if (dt > 0.1) { // audio is slower than video, skip
                            [self.aframes removeObjectAtIndex:0];
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
    return (UIView *) _view;
}

- (void)setPosition:(double)position {
    self.requestSeekPosition = position;
    self.requestSeek = YES;
}

- (double)position {
    return self.mediaPosition;
}

- (void)setSpeed:(CGFloat)speed {
    _speed = speed;
    self.decoder.speed = speed;
}

- (BOOL)isAvilableMetal {
#if TARGET_IPHONE_SIMULATOR
    return NO;
#else
    if (@available(iOS 9.0, *)) {
        return _isDeviceSupportMetal;
    }
    return NO;
#endif
}

- (void)setMute:(BOOL)mute {
    dispatch_async(self.processingQueue, ^{
        self.audio.mute = mute;
    });
}

#pragma mark - Handle Error
- (void)handleError:(NSError *)error {
    if (error == nil) {
        return;
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:DLGPlayerNotificationError object:self userInfo:@{DLGPlayerNotificationErrorKey: error}];
}

@end

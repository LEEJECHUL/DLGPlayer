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

#define DLGPlayerFrameDropLimit  0.4

@interface DLGPlayer ()
@property (atomic) BOOL closing;
@property (atomic) BOOL opening;
@property (atomic) BOOL frameDropEnabled;
@property (nonatomic) BOOL notifiedBufferStart;
@property (nonatomic) BOOL renderBegan;
@property (nonatomic) BOOL requestSeek;
@property (atomic) double bufferedDuration;
@property (nonatomic) double mediaPosition;
@property (nonatomic) double mediaSyncPosition;
@property (nonatomic) double mediaSyncTime;
@property (nonatomic) double requestSeekPosition;
@property (nonatomic) NSUInteger playingAudioFrameDataPosition;
@property (nonatomic, strong) dispatch_queue_t frameReaderQueue;
@property (nonatomic, strong) dispatch_queue_t processingQueue;
@property (nonatomic, strong) dispatch_queue_t renderingQueue;
@property (nonatomic, strong) dispatch_semaphore_t vFramesLock;
@property (nonatomic, strong) dispatch_semaphore_t aFramesLock;
@property (nonatomic, strong) NSMutableArray *vframes;
@property (nonatomic, strong) NSMutableArray *aframes;
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
    _requestSeekPosition = position;
    _requestSeek = YES;
}

- (double)position {
    return _mediaPosition;
}

- (void)setSpeed:(double)speed {
    _speed = speed;
    _decoder.speed = speed;
}

- (void)setMute:(BOOL)mute {
    if (mute == _mute) {
        return;
    }
    
    _mute = mute;
    _audio.mute = mute;
    
    __weak typeof(self)weakSelf = self;
    
    dispatch_async(_processingQueue, ^{
        __strong typeof(weakSelf)strongSelf = weakSelf;
        
        if (!strongSelf) {
            return;
        }
        
        if (mute) {
            if ([strongSelf.audio close]) {
                [[NSNotificationCenter defaultCenter] postNotificationName:DLGPlayerNotificationAudioClosed object:strongSelf];
            }
        } else if (strongSelf.playing) {
            if (!strongSelf.audio.opened && [strongSelf.audio open]) {
                strongSelf.decoder.audioChannels = [strongSelf.audio channels];
                strongSelf.decoder.audioSampleRate = [strongSelf.audio sampleRate];
                [[NSNotificationCenter defaultCenter] postNotificationName:DLGPlayerNotificationAudioOpened object:strongSelf];
            }
            [strongSelf.audio play];
        }

        strongSelf.decoder.mute = mute;
    });
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
    
    dispatch_async(_processingQueue, ^{
        __strong typeof(weakSelf)strongSelf = weakSelf;
        
        if (!strongSelf || strongSelf.opening || strongSelf.closing) {
            return;
        }
        
        strongSelf.opening = YES;
        
        if (!strongSelf.audio.opened && [strongSelf.audio open]) {
            strongSelf.decoder.audioChannels = [strongSelf.audio channels];
            strongSelf.decoder.audioSampleRate = [strongSelf.audio sampleRate];
            [[NSNotificationCenter defaultCenter] postNotificationName:DLGPlayerNotificationAudioOpened object:strongSelf];
        }

        NSError *error = nil;
        if (![strongSelf.decoder open:url error:&error]) {
            strongSelf.opening = NO;
            [strongSelf handleError:error];
            return;
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([strongSelf.view isKindOfClass:[DLGPlayerView class]]) {
                DLGPlayerView *view = (DLGPlayerView *) strongSelf.view;
                [view setCurrentEAGLContext];
            }

            strongSelf.view.isYUV = strongSelf.decoder.isYUV;
            strongSelf.view.keepLastFrame = strongSelf.keepLastFrame && strongSelf.decoder.hasPicture && !strongSelf.decoder.hasVideo;
            strongSelf.view.rotation = strongSelf.decoder.rotation;
            strongSelf.view.contentSize = CGSizeMake(strongSelf.decoder.videoWidth, strongSelf.decoder.videoHeight);

            if ([strongSelf.view isKindOfClass:[UIView class]]) {
                ((UIView *) strongSelf.view).contentMode = UIViewContentModeScaleToFill;
            }
            
            strongSelf.duration = strongSelf.decoder.duration;
            strongSelf.metadata = strongSelf.decoder.metadata;
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
            
            if (strongSelf.allowsFrameDrop) {
                strongSelf.frameDropEnabled = YES;
            }
            
            [[NSNotificationCenter defaultCenter] postNotificationName:DLGPlayerNotificationOpened object:strongSelf];
        });
    });
}

- (void)close {
    [self close:NO];
}

- (void)closeAudio {
    __weak typeof(self)weakSelf = self;
    
    dispatch_async(_processingQueue, ^{
        __strong typeof(weakSelf)strongSelf = weakSelf;
        
        if (strongSelf && [strongSelf.audio close]) {
            [[NSNotificationCenter defaultCenter] postNotificationName:DLGPlayerNotificationAudioClosed object:strongSelf];
        }
    });
}

- (void)closeCompletely {
    [self close:YES];
}

- (void)play {
    __weak typeof(self)weakSelf = self;
    
    dispatch_async(_processingQueue, ^{
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
    
    dispatch_async(_processingQueue, ^{
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
    _frameDropEnabled = NO;
    _keepLastFrame = YES;
    _requestSeek = NO;
    _renderBegan = NO;
    _buffering = NO;
    _closing = NO;
    _opening = NO;
    _playing = NO;
    _opened = NO;
    _frameDropDuration = DLGPlayerFrameDropDuration;
    _minBufferDuration = DLGPlayerMinBufferDuration;
    _maxBufferDuration = DLGPlayerMaxBufferDuration;
    _mediaSyncTime = 0;
    _brightness = 1;
    _requestSeekPosition = 0;
    _speed = 1.0;
    _bufferedDuration = 0;
    _mediaPosition = 0;
    _playingAudioFrameDataPosition = 0;
    _playingAudioFrame = nil;
    
    _aFramesLock = dispatch_semaphore_create(1);
    _vFramesLock = dispatch_semaphore_create(1);
    _vframes = [NSMutableArray arrayWithCapacity:128];
    _aframes = [NSMutableArray arrayWithCapacity:128];
    
    const char *frameReaderQueueName = [NSString stringWithFormat:@"DLGPlayer.frameReaderQueue::%zd", self.hash].UTF8String;
    const char *processingQueueName = [NSString stringWithFormat:@"DLGPlayer.processingQueue::%zd", self.hash].UTF8String;
    const char *renderingQueueName = [NSString stringWithFormat:@"DLGPlayer.renderingQueue::%zd", self.hash].UTF8String;
    
    if (@available(iOS 10.0, *)) {
        _frameReaderQueue = dispatch_queue_create(frameReaderQueueName, DISPATCH_QUEUE_SERIAL_WITH_AUTORELEASE_POOL);
        _processingQueue = dispatch_queue_create(processingQueueName, DISPATCH_QUEUE_SERIAL_WITH_AUTORELEASE_POOL);
        _renderingQueue = dispatch_queue_create(renderingQueueName, DISPATCH_QUEUE_SERIAL_WITH_AUTORELEASE_POOL);
    } else {
        _frameReaderQueue = dispatch_queue_create(frameReaderQueueName, DISPATCH_QUEUE_SERIAL);
        _processingQueue = dispatch_queue_create(processingQueueName, DISPATCH_QUEUE_SERIAL);
        _renderingQueue = dispatch_queue_create(renderingQueueName, DISPATCH_QUEUE_SERIAL);
    }
}

- (void)initView {
    if (@available(iOS 9.0, *)) {
        _view = [DLGPlayerUtils isMetalSupport] ? [MetalPlayerView new] : [DLGPlayerView new];
    } else {
        _view = [DLGPlayerView new];
    }
}

- (void)initDecoder {
    _decoder = [[DLGPlayerDecoder alloc] init];
    _decoder.speed = _speed;
}

- (void)initAudio {
    _audio = [[DLGPlayerAudioManager alloc] init];
}

- (void)clearVars {
    {
        dispatch_semaphore_wait(_vFramesLock, DISPATCH_TIME_FOREVER);
        [_vframes removeAllObjects];
        dispatch_semaphore_signal(_vFramesLock);
    }
    {
        dispatch_semaphore_wait(_aFramesLock, DISPATCH_TIME_FOREVER);
        [_aframes removeAllObjects];
        dispatch_semaphore_signal(_aFramesLock);
    }
    
    _buffering = NO;
    _closing = NO;
    _frameDropEnabled = NO;
    _opened = NO;
    _opening = NO;
    _playing = NO;
    _renderBegan = NO;
    _bufferedDuration = 0;
    _mediaPosition = 0;
    _mediaSyncTime = 0;
    _playingAudioFrameDataPosition = 0;
    _playingAudioFrame = nil;
}

- (void)close:(BOOL)completely {
    __weak typeof(self)weakSelf = self;
    
    dispatch_async(_processingQueue, ^{
        __strong typeof(weakSelf)strongSelf = weakSelf;
        
        if (!strongSelf || strongSelf.closing || !strongSelf.opened) {
            return;
        }
        
        strongSelf.closing = YES;
        strongSelf.playing = NO;
        
        if (completely) {
            if ([strongSelf.audio close]) {
                [[NSNotificationCenter defaultCenter] postNotificationName:DLGPlayerNotificationAudioClosed object:strongSelf];
            }
        } else {
            [strongSelf.audio pause];
        }

        dispatch_async(strongSelf.frameReaderQueue, ^{
            [strongSelf.decoder prepareClose];
            [strongSelf.decoder close];
        });
        
        [strongSelf clearVars];
        [strongSelf.view clear];
        [[NSNotificationCenter defaultCenter] postNotificationName:DLGPlayerNotificationClosed object:strongSelf];
    });
}

- (void)runFrameReader {
    while (_playing && !_closing) {
        [self readFrame];
        
        if (_requestSeek) {
            [self seekPositionInFrameReader];
        } else {
            [NSThread sleepForTimeInterval:1.5];
        }
    }
}

- (void)readFrame {
    _buffering = YES;
    
    double tempDuration = 0;
    double droppedDuration = 0;
    NSMutableArray *tempVFrames = [NSMutableArray arrayWithCapacity:15];
    NSMutableArray *tempAFrames = [NSMutableArray arrayWithCapacity:15];
    dispatch_time_t t = dispatch_time(DISPATCH_TIME_NOW, 0.02 * NSEC_PER_SEC);
    
    if (DLGPlayerUtils.debugEnabled && _frameDropEnabled) {
        NSLog(@"DLGPlayer fram drop began!");
    }
    
    while (_playing && !_closing && !_decoder.isEOF && !_requestSeek
           && (_frameDropEnabled || (_bufferedDuration + tempDuration) < _maxBufferDuration)) {
        @autoreleasepool {
            NSArray *fs = [_decoder readFrames];
            
            if (fs == nil) { break; }
            if (fs.count == 0) { continue; }
            
            for (DLGPlayerFrame *f in fs) {
                if (f.type == kDLGPlayerFrameTypeVideo) {
                    if (_frameDropEnabled) {
                        f.dropFrame = YES;
                        droppedDuration += f.duration;
                    }
                    
                    [tempVFrames addObject:f];
                    tempDuration += f.duration;
                }

                if (!_mute && f.type == kDLGPlayerFrameTypeAudio) {
                    if (!_decoder.hasVideo) {
                        if (_frameDropEnabled) {
                            f.dropFrame = YES;
                            droppedDuration += f.duration;
                        }
                        tempDuration += f.duration;
                    }
                    [tempAFrames addObject:f];
                }
            }

            long timeout = dispatch_semaphore_wait(_vFramesLock, t);
            if (timeout == 0) {
                if (tempVFrames.count > 0) {
                    _bufferedDuration += tempDuration;
                    tempDuration = 0;
                    
                    [_vframes addObjectsFromArray:tempVFrames];
                    [tempVFrames removeAllObjects];
                }
                dispatch_semaphore_signal(_vFramesLock);
            }
            
            if (!_mute) {
                long timeout = dispatch_semaphore_wait(_aFramesLock, t);
                if (timeout == 0) {
                    if (tempAFrames.count > 0) {
                        if (!_decoder.hasVideo) {
                            _bufferedDuration += tempDuration;
                            tempDuration = 0;
                        }
                        [_aframes addObjectsFromArray:tempAFrames];
                        [tempAFrames removeAllObjects];
                    }
                    dispatch_semaphore_signal(_aFramesLock);
                }
            }
        }

        if (DLGPlayerUtils.debugEnabled && _frameDropEnabled) {
            NSLog(@"_bufferedDuration -> %f", _bufferedDuration);
        }
        
        if (_frameDropEnabled && droppedDuration > _frameDropDuration) {
            _frameDropEnabled = NO;
            droppedDuration = 0;

            if (DLGPlayerUtils.debugEnabled) {
                NSLog(@"DLGPlayer fram drop ended!");
            }
        }
    }
    
    {
        // add the rest video frames
        while (tempVFrames.count > 0 || tempAFrames.count > 0) {
            if (tempVFrames.count > 0) {
                long timeout = dispatch_semaphore_wait(_vFramesLock, t);
                if (timeout == 0) {
                    _bufferedDuration += tempDuration;
                    tempDuration = 0;
                    [_vframes addObjectsFromArray:tempVFrames];
                    [tempVFrames removeAllObjects];
                    dispatch_semaphore_signal(_vFramesLock);
                }
            }
            if (tempAFrames.count > 0) {
                long timeout = dispatch_semaphore_wait(_aFramesLock, t);
                if (timeout == 0) {
                    if (!_decoder.hasVideo) {
                        _bufferedDuration += tempDuration;
                        tempDuration = 0;
                    }
                    [_aframes addObjectsFromArray:tempAFrames];
                    [tempAFrames removeAllObjects];
                    dispatch_semaphore_signal(_aFramesLock);
                }
            }
        }
    }
    
    _buffering = NO;
}

- (void)seekPositionInFrameReader {
    [_decoder seek:_requestSeekPosition];
    
    {
        dispatch_semaphore_wait(_vFramesLock, DISPATCH_TIME_FOREVER);
        [_vframes removeAllObjects];
        dispatch_semaphore_signal(_vFramesLock);
    }
    {
        dispatch_semaphore_wait(_aFramesLock, DISPATCH_TIME_FOREVER);
        [_aframes removeAllObjects];
        dispatch_semaphore_signal(_aFramesLock);
    }
    
    _bufferedDuration = 0;
    _requestSeek = NO;
    _mediaSyncTime = 0;
    _mediaPosition = _requestSeekPosition;
}

- (void)render {
    if (!_playing)
        return;
    
    BOOL eof = _decoder.isEOF;
    BOOL noframes = ((_decoder.hasVideo && _vframes.count <= 0) &&
                     (_decoder.hasAudio && _aframes.count <= 0));
    
    // Check if reach the end and play all frames.
    if (noframes && eof) {
        [self pause];
        [[NSNotificationCenter defaultCenter] postNotificationName:DLGPlayerNotificationEOF object:self];
        return;
    }
    
    if (noframes && !_notifiedBufferStart) {
        _notifiedBufferStart = YES;
        NSDictionary *userInfo = @{DLGPlayerNotificationBufferStateKey: @(_notifiedBufferStart)};
        [[NSNotificationCenter defaultCenter] postNotificationName:DLGPlayerNotificationBufferStateChanged object:self userInfo:userInfo];
    } else if (!noframes && _notifiedBufferStart && _bufferedDuration >= _minBufferDuration / _speed) {
        _notifiedBufferStart = NO;
        NSDictionary *userInfo = @{DLGPlayerNotificationBufferStateKey: @(_notifiedBufferStart)};
        [[NSNotificationCenter defaultCenter] postNotificationName:DLGPlayerNotificationBufferStateChanged object:self userInfo:userInfo];
    }
    
    // Render if has picture
    if (_decoder.hasPicture && _vframes.count > 0) {
        DLGPlayerVideoFrame *frame = _vframes[0];
        frame.brightness = _brightness;
        _view.contentSize = CGSizeMake(frame.width, frame.height);
        
        if (dispatch_semaphore_wait(_vFramesLock, DISPATCH_TIME_NOW) == 0) {
            [_vframes removeObjectAtIndex:0];
            dispatch_semaphore_signal(_vFramesLock);
            [self renderView:frame];
        }
    }
    
    // Check whether render is neccessary
    if (_vframes.count <= 0 || !_decoder.hasVideo || _notifiedBufferStart) {
        __weak typeof(self)weakSelf = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t) (0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [weakSelf render];
        });
        return;
    }
    
    // Render video
    DLGPlayerVideoFrame *frame = nil;
    {
        if (dispatch_semaphore_wait(_vFramesLock, DISPATCH_TIME_NOW) == 0) {
            frame = _vframes[0];
            frame.brightness = _brightness;
            _mediaPosition = frame.position;
            _bufferedDuration -= frame.duration;
            [_vframes removeObjectAtIndex:0];
            dispatch_semaphore_signal(_vFramesLock);
        }
    }

    [self renderView:frame];
    
    double syncTime = [self syncTime];
    NSTimeInterval t;
    if (_speed > 1) {
        t = frame.duration;
    } else {
        t = frame.dropFrame ? 0.01 : MIN(frame.duration, MAX(frame.duration + syncTime, 0.01));
    }
    
    __weak typeof(self)weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t) (t * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [weakSelf render];
    });
}

- (void)renderView:(DLGPlayerVideoFrame *)frame {
    __weak typeof(self)weakSelf = self;
    
    dispatch_sync(_renderingQueue, ^{
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
    
    if (_mediaSyncTime == 0) {
        _mediaSyncTime = now;
        _mediaSyncPosition = _mediaPosition;
        return 0;
    }
    
    double dp = _mediaPosition - _mediaSyncPosition;
    double dt = now - _mediaSyncTime;
    double sync = dp - dt;
    
    if (sync > 1 || sync < -1) {
        sync = 0;
        _mediaSyncTime = 0;
    }
    
    return sync;
}

/*
 * For audioUnitRenderCallback, (DLGPlayerAudioManagerFrameReaderBlock)readFrameBlock
 */
- (void)readAudioFrame:(float *)data frames:(UInt32)frames channels:(UInt32)channels {
    if (!_playing) {
        return;
    }
    
    while(frames > 0) {
        @autoreleasepool {
            if (_playingAudioFrame == nil) {
                {
                    if (_aframes.count <= 0) {
                        memset(data, 0, frames * channels * sizeof(float));
                        return;
                    }
                    
                    long timeout = dispatch_semaphore_wait(_aFramesLock, DISPATCH_TIME_NOW);
                    if (timeout == 0) {
                        @autoreleasepool {
                            DLGPlayerAudioFrame *frame = _aframes[0];

                            if (frame.dropFrame) {
                                [_aframes removeObjectAtIndex:0];
                                dispatch_semaphore_signal(_aFramesLock);
                                continue;
                            }
                            
                            if (_decoder.hasVideo) {
                                const double dt = _mediaPosition - frame.position;
                                
                                if (dt < -0.1) { // audio is faster than video, silence
                                    memset(data, 0, frames * channels * sizeof(float));
                                    dispatch_semaphore_signal(_aFramesLock);
                                    break;
                                } else if (dt > 0.1) { // audio is slower than video, skip
                                    [_aframes removeObjectAtIndex:0];
                                    dispatch_semaphore_signal(_aFramesLock);
                                    continue;
                                } else {
                                    _playingAudioFrameDataPosition = 0;
                                    _playingAudioFrame = frame;
                                    [_aframes removeObjectAtIndex:0];
                                }
                            } else {
                                _playingAudioFrameDataPosition = 0;
                                _playingAudioFrame = frame;
                                [_aframes removeObjectAtIndex:0];
                                _mediaPosition = frame.position;
                                _bufferedDuration -= frame.duration;
                            }
                        }
                        dispatch_semaphore_signal(_aFramesLock);
                    } else return;
                }
            }
            
            NSData *frameData = _playingAudioFrame.data;
            NSUInteger pos = _playingAudioFrameDataPosition;
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
                _playingAudioFrameDataPosition += bytesToCopy;
            } else {
                _playingAudioFrame = nil;
            }
        }
    }
}

- (void)handleError:(NSError *)error {
    if (error == nil) {
        return;
    }
    NSDictionary *userInfo = @{DLGPlayerNotificationErrorKey: error};
    [[NSNotificationCenter defaultCenter] postNotificationName:DLGPlayerNotificationError object:self userInfo:userInfo];
}

@end

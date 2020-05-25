//
//  DLGPlayer.h
//  DLGPlayer
//
//  Created by Liu Junqi on 09/12/2016.
//  Copyright © 2016 Liu Junqi. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DLGPlayerAudioFrame.h"
#import "DLGPlayerAudioManager.h"
#import "DLGPlayerControlStatus.h"
#import "DLGPlayerDef.h"
#import "DLGPlayerDecoder.h"
#import "DLGPlayerFrame.h"
#import "DLGPlayerUtils.h"
#import "DLGPlayerVideoFrame.h"
#import "DLGPlayerVideoRGBFrame.h"
#import "DLGPlayerVideoYUVFrame.h"
#import "DLGPlayerViewController.h"
#import "DLGSimplePlayerViewController.h"

typedef void (^onPauseComplete)(void);

@interface DLGPlayer : NSObject
@property (nonatomic) BOOL allowsFrameDrop;
@property (nonatomic) BOOL mute;
@property (atomic) BOOL playing;
@property (atomic) BOOL buffering;
@property (atomic) BOOL opened;
@property (nonatomic) float brightness;
@property (atomic) double frameDropDuration;
@property (atomic) double minBufferDuration;
@property (atomic) double maxBufferDuration;
@property (nonatomic) double position;
@property (nonatomic) double duration;
@property (nonatomic) double speed;
@property (nonatomic, strong) NSDictionary *metadata;
@property (nonatomic, readonly) UIView *playerView;
@property (nonatomic, readonly) DLGPlayerAudioManager *audio;

- (void)close;
- (void)closeAudio;
- (void)closeCompletely;
- (void)open:(NSString *)url;
- (void)play;
- (void)pause;
- (UIImage *)snapshot;
@end

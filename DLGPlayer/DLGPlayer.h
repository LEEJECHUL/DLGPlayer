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
#import "DLGPlayerDef.h"
#import "DLGPlayerDecoder.h"
#import "DLGPlayerFrame.h"
#import "DLGPlayerVideoFrame.h"
#import "DLGPlayerVideoRGBFrame.h"
#import "DLGPlayerVideoYUVFrame.h"
#import "DLGPlayerViewController.h"
#import "DLGPlayerUtils.h"
#import "DLGPlayerControlStatus.h"
#import "DLGSimplePlayerViewController.h"

typedef void (^onPauseComplete)(void);

@interface DLGPlayer : NSObject
@property (readonly, strong) UIView *playerView;
@property (nonatomic) BOOL allowsFrameDrop;
@property (atomic) BOOL playing;
@property (atomic) BOOL buffering;
@property (atomic) BOOL opened;
@property (nonatomic) float brightness;
@property (nonatomic) double minBufferDuration;
@property (nonatomic) double maxBufferDuration;
@property (nonatomic) double position;
@property (nonatomic) double duration;
@property (nonatomic) double speed;
@property (nonatomic, strong) NSDictionary *metadata;
@property (nonatomic, readonly) DLGPlayerAudioManager *audio;

- (void)open:(NSString *)url;
- (void)close;
- (void)play;
- (void)pause;
- (UIImage *)snapshot;
@end

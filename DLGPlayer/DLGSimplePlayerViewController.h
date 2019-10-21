//
//  DLGSimplePlayerViewController.h
//  DLGPlayer
//
//  Created by KWANG HYOUN KIM on 07/12/2018.
//  Copyright © 2018 KWANG HYOUN KIM. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DLGPlayer.h"

@class DLGPlayer;
@class DLGSimplePlayerViewController;

@protocol DLGSimplePlayerViewControllerDelegate <NSObject>
- (void)didBeginRenderInViewController:(DLGSimplePlayerViewController * _Nonnull)viewController;
- (void)viewController:(DLGSimplePlayerViewController * _Nonnull)viewController didChangeStatus:(DLGPlayerStatus)status;
- (void)viewController:(DLGSimplePlayerViewController * _Nonnull)viewController didReceiveError:(NSError *)error;
@end

@interface DLGSimplePlayerViewController : UIViewController
@property (nonatomic, readonly) BOOL hasUrl;
@property (nonatomic) BOOL isAllowsFrameDrop;
@property (nonatomic) BOOL isAutoplay;
@property (nonatomic) BOOL isMute;
@property (nonatomic, readonly) BOOL isPlaying;
@property (nonatomic) BOOL isRepeat;
@property (nonatomic) BOOL preventFromScreenLock;
@property (nonatomic) BOOL restorePlayAfterAppEnterForeground;
@property (nonatomic) CGFloat speed;
@property (nonatomic) double minBufferDuration;
@property (nonatomic) double maxBufferDuration;
@property (nullable, atomic, copy) NSString *url;
@property (nonnull, nonatomic, readonly) DLGPlayerControlStatus *controlStatus;
@property (nonatomic, readonly) DLGPlayerStatus status;
@property (nonnull, nonatomic, readonly) DLGPlayer *player;
@property (nullable, nonatomic, weak) id<DLGSimplePlayerViewControllerDelegate> delegate;
- (void)open;
- (void)play;
- (void)pause;
- (void)stop;
@end

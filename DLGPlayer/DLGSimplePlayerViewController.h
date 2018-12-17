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
- (void)viewController:(DLGSimplePlayerViewController *)viewController didChangeStatus:(DLGPlayerStatus)status;
- (void)viewController:(DLGSimplePlayerViewController *)viewController didReceiveError:(NSError *)error;
@end

@interface DLGSimplePlayerViewController : UIViewController
@property (nonatomic, readonly) BOOL hasUrl;
@property (nonatomic) BOOL isAutoplay;
@property (nonatomic) BOOL isMute;
@property (nonatomic, readonly) BOOL isPlaying;
@property (nonatomic) BOOL isRepeat;
@property (nonatomic) BOOL preventFromScreenLock;
@property (nonatomic) BOOL restorePlayAfterAppEnterForeground;
@property (nullable, nonatomic, copy) NSString *url;
@property (nonatomic, readonly) DLGPlayerStatus status;
@property (nonatomic, readonly) DLGPlayer *player;
@property (nonatomic, weak) id<DLGSimplePlayerViewControllerDelegate> delegate;
- (void)open;
- (void)close;
- (void)play;
- (void)pause;
- (void)reset;
@end

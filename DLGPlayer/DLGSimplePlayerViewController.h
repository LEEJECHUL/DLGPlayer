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

NS_ASSUME_NONNULL_BEGIN

@class DLGSimplePlayerViewController;

@protocol DLGSimplePlayerViewControllerDelegate <NSObject>
- (void)viewController:(DLGSimplePlayerViewController *)viewController didChangeStatus:(DLGPlayerStatus)status;
- (void)viewController:(DLGSimplePlayerViewController *)viewController didReceiveError:(NSError *)error;
@end

@interface DLGSimplePlayerViewController : UIViewController
@property (nonatomic, copy) NSString *url;
@property (nonatomic) BOOL isAutoplay;
@property (nonatomic) BOOL isMute;
@property (nonatomic) BOOL isRepeat;
@property (nonatomic) BOOL preventFromScreenLock;
@property (nonatomic) BOOL restorePlayAfterAppEnterForeground;
@property (nonatomic, readonly) DLGPlayerStatus status;
@property (nonatomic, readonly) DLGPlayer *player;
@property (nonatomic, weak) id<DLGSimplePlayerViewControllerDelegate> delegate;
- (void)open;
- (void)close;
- (void)play;
- (void)pause;
- (void)reset;
@end

NS_ASSUME_NONNULL_END

//
//  DLGPlayerView.h
//  DLGPlayer
//
//  Created by Liu Junqi on 05/12/2016.
//  Copyright © 2016 Liu Junqi. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DLGPlayerVideoFrameView.h"

@class DLGPlayerVideoFrame;

@interface DLGPlayerView : UIView <DLGPlayerVideoFrameView>
- (BOOL)setCurrentEAGLContext;
@end

//
//  DLGPlayerVideoFrameView.h
//  DLGPlayer
//
//  Created by KWANG HYOUN KIM on 21/08/2019.
//  Copyright © 2019 KWANG HYOUN KIM. All rights reserved.
//

#ifndef DLGPlayerVideoFrameView_h
#define DLGPlayerVideoFrameView_h

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@class DLGPlayerVideoFrame;

@protocol DLGPlayerVideoFrameView <NSObject>
@property (nonatomic) CGSize contentSize;
@property (nonatomic) CGFloat rotation;
@property (nonatomic) BOOL isYUV;
@property (nonatomic) BOOL keepLastFrame;

- (void)render:(DLGPlayerVideoFrame *)frame;
- (void)clear:(BOOL)forced;
- (UIImage *)snapshot;
@end

#endif /* DLGPlayerVideoFrameView_h */

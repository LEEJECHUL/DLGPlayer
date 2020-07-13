//
//  DLGPlayerVideoFrame.h
//  DLGPlayer
//
//  Created by Liu Junqi on 05/12/2016.
//  Copyright © 2016 Liu Junqi. All rights reserved.
//

#import "DLGPlayerFrame.h"
#import <OpenGLES/ES2/gl.h>
@import MetalKit;

typedef enum : NSUInteger {
    kDLGPlayerVideoFrameTypeNone,
    kDLGPlayerVideoFrameTypeRGB,
    kDLGPlayerVideoFrameTypeYUV
} DLGPlayerVideoFrameType;

@interface DLGPlayerVideoFrame : DLGPlayerFrame

@property (nonatomic, readonly) BOOL prepared;
@property (nonatomic) DLGPlayerVideoFrameType videoType;
@property (nonatomic) int width;
@property (nonatomic) int height;
@property (nonatomic) float brightness;

- (BOOL)prepareProgram:(GLuint)program;
- (BOOL)prepareDevice:(__weak id<MTLDevice>)device;
- (BOOL)render:(__weak id<MTLComputeCommandEncoder>)encoder;

@end

//
//  DLGPlayerVideoFrame.m
//  DLGPlayer
//
//  Created by Liu Junqi on 05/12/2016.
//  Copyright © 2016 Liu Junqi. All rights reserved.
//

#import "DLGPlayerVideoFrame.h"

@implementation DLGPlayerVideoFrame

- (id)init {
    self = [super init];
    if (self) {
        _brightness = 1;
        self.type = kDLGPlayerFrameTypeVideo;
    }
    return self;
}

- (BOOL)prepared {
    return NO;
}

- (BOOL)prepareProgram:(GLuint)program {
    return NO;
}

- (BOOL)prepareDevice:(__weak id<MTLDevice>)device {
    return NO;
}

- (BOOL)render:(__weak id<MTLComputeCommandEncoder>)encoder {
    return NO;
}

@end

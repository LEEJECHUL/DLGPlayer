//
//  MetalPlayerView.h
//  DLGPlayer
//
//  Created by KWANG HYOUN KIM on 20/08/2019.
//  Copyright © 2019 KWANG HYOUN KIM. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DLGPlayerVideoFrameView.h"
@import MetalKit;

NS_ASSUME_NONNULL_BEGIN

API_AVAILABLE(ios(9.0))
@interface MetalPlayerView : MTKView <DLGPlayerVideoFrameView>
@end

NS_ASSUME_NONNULL_END

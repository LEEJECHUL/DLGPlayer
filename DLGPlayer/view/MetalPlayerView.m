//
//  MetalPlayerView.m
//  DLGPlayer
//
//  Created by KWANG HYOUN KIM on 20/08/2019.
//  Copyright © 2019 KWANG HYOUN KIM. All rights reserved.
//

@import MetalKit;
#import "MetalPlayerView.h"
#import "DLGPlayerUtils.h"
#import "DLGPlayerVideoFrame.h"
#import "DLGPlayerVideoYUVFrame.h"

@interface MetalPlayerView () <MTKViewDelegate>
@property (nonatomic, readonly) BOOL isRenderingAvailable;
@end

@implementation MetalPlayerView
{
@private
    MTLSize threadsPerThreadgroup;
    MTLSize threadgroupsPerGrid;
    id<MTLLibrary> defaultLibrary;
    id<MTLCommandQueue> commandQueue;
    id<MTLComputePipelineState> pipelineState;
    MTKView *metalView;
    DLGPlayerVideoFrame *currentFrame;
}

@synthesize isYUV = _isYUV;
@synthesize keepLastFrame = _keepLastFrame;
@synthesize rotation = _rotation;
@synthesize contentSize = _contentSize;

#pragma mark - Constructors

- (void)dealloc {
    if (DLGPlayerUtils.debugEnabled) {
        NSLog(@"MetalPlayerView dealloc");
    }
    [self clear];
}

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self initProperties];
    }
    return self;
}

#pragma mark - Private Properties

- (BOOL)isRenderingAvailable {
    return metalView.currentDrawable != nil && currentFrame != nil && currentFrame.prepared;
}

#pragma mark - Overridden: UIView

- (void)layoutSubviews {
    [super layoutSubviews];
    
    metalView.frame = self.bounds;
}

#if TARGET_IPHONE_SIMULATOR
#else

#pragma mark - Private Methods
    
- (void)setUpPipelineState {
    @autoreleasepool {
        NSString *name = _isYUV ? @"YUVColorConversion" : @"RGBColorConversion";
        id<MTLFunction> kernelFunction = [defaultLibrary newFunctionWithName:name];
        
        if (!kernelFunction && DLGPlayerUtils.debugEnabled) {
            NSLog(@"Error creating compute shader");
            return;
        }
        
        pipelineState = [metalView.device newComputePipelineStateWithFunction:kernelFunction error:nil];
        
        if (!pipelineState && DLGPlayerUtils.debugEnabled) {
            NSLog(@"Error creating the pipeline state");
        }
    }
}

#pragma mark - Private Methods (MTKViewDelegate)

- (void)mtkView:(nonnull MTKView *)view drawableSizeWillChange:(CGSize)size {}

- (void)drawInMTKView:(nonnull MTKView *)view {
    if (!self.isRenderingAvailable || !pipelineState) {
        return;
    }
    
    @autoreleasepool {
        id<MTLCommandBuffer> commandBuffer = [commandQueue commandBuffer];
        
        if (!commandBuffer) {
            return;
        }
        
        id<MTLComputeCommandEncoder> commandEncoder = [commandBuffer computeCommandEncoder];
        
        if (commandEncoder) {
            float brightness = currentFrame.brightness;
            
            [commandEncoder setComputePipelineState:pipelineState];
            [commandEncoder setBytes:&brightness length:sizeof(brightness) atIndex:0];
            [currentFrame render:commandEncoder];
            [commandEncoder setTexture:metalView.currentDrawable.texture atIndex:3];
            [commandEncoder dispatchThreadgroups:threadgroupsPerGrid threadsPerThreadgroup:threadsPerThreadgroup];
            [commandEncoder endEncoding];
            
            [commandBuffer presentDrawable:metalView.currentDrawable];
            [commandBuffer commit];
        }
    }
}

#endif

- (void)initProperties {
    metalView = [MTKView new];
    metalView.autoResizeDrawable = NO;
    metalView.framebufferOnly = NO;
    metalView.contentScaleFactor = UIScreen.mainScreen.scale;
    metalView.colorPixelFormat = MTLPixelFormatBGRA8Unorm;
    metalView.clearColor = MTLClearColorMake(1, 1, 1, 1);
    metalView.device = MTLCreateSystemDefaultDevice();
    metalView.delegate = self;
    
    [self addSubview:metalView];
    
#if TARGET_IPHONE_SIMULATOR
    NSLog(@"[DLGPlayer] Metal will not work on simulator.");
#endif
    commandQueue = [metalView.device newCommandQueue];
    
    if (@available(iOS 10.0, *)) {
        @autoreleasepool {
            NSBundle *bundle = [NSBundle bundleForClass:[self class]];
            defaultLibrary = [metalView.device newDefaultLibraryWithBundle:bundle error:nil];
        }
    } else {
        defaultLibrary = [metalView.device newDefaultLibrary];
    }
    
    threadsPerThreadgroup = MTLSizeMake(16, 16, 1);
    threadgroupsPerGrid = MTLSizeMake(3840 / threadsPerThreadgroup.width, 2160 / threadsPerThreadgroup.height, 1);
}

#pragma mark - Public Methods (DLGPlayerVideoFrame)

- (void)setContentSize:(CGSize)contentSize {
    _contentSize = contentSize;
}

- (void)setRotation:(CGFloat)rotation {
    _rotation = rotation;
}

- (void)setIsYUV:(BOOL)isYUV {
    if (isYUV == _isYUV) {
        return;
    }
    
    _isYUV = isYUV;
#if TARGET_IPHONE_SIMULATOR
#else
    [self setUpPipelineState];
#endif
}

- (void)clear {
    if (!_keepLastFrame) {
        currentFrame = nil;
    }
    
    [metalView releaseDrawables];
}

- (void)render:(DLGPlayerVideoFrame *)frame {
    if (frame == nil || frame.width < 1 || frame.height < 1) {
        return;
    }
    
    currentFrame = frame;
    metalView.drawableSize = CGSizeMake(frame.width, frame.height);
    
    if ([frame prepareDevice:metalView.device]) {
        // TODO: - Impl scale / flip / rotation.
    }
}

- (UIImage *)snapshot {
#if TARGET_IPHONE_SIMULATOR
    NSLog(@"[DLGPlayer] Metal will not work to make snapshot on simulator.");
    return nil;
#else
    if (!self.isRenderingAvailable) {
        return nil;
    }
    
    const id<MTLTexture> texture = metalView.currentDrawable.texture;
    const NSInteger w = texture.width;
    const NSInteger h = texture.height;
    CIContext *context = [CIContext contextWithMTLDevice:metalView.device];
    CIImage *outputImage = [[CIImage alloc] initWithMTLTexture:texture options:@{kCIImageColorSpace: (__bridge_transfer id) CGColorSpaceCreateDeviceRGB()}];
    CGImageRef cgImg = [context createCGImage:outputImage fromRect:CGRectMake(0, 0, w, h)];
    UIImage *resultImg = [UIImage imageWithCGImage:cgImg scale:UIScreen.mainScreen.scale orientation:UIImageOrientationDownMirrored];
    CGImageRelease(cgImg);
    return resultImg;
#endif
}

@end

//
//  MetalPlayerView.m
//  DLGPlayer
//
//  Created by KWANG HYOUN KIM on 20/08/2019.
//  Copyright © 2019 KWANG HYOUN KIM. All rights reserved.
//

#import "MetalPlayerView.h"
#import "DLGPlayerVideoFrame.h"
#import "DLGPlayerVideoYUVFrame.h"

@interface MetalPlayerView ()
@property (nonatomic, readonly) BOOL isRenderingAvailable;
@property (nonatomic) MTLSize threadsPerThreadgroup;
@property (nonatomic) MTLSize threadgroupsPerGrid;
@property (nonatomic, strong) id<MTLLibrary> defaultLibrary;
@property (nonatomic, strong) id<MTLCommandQueue> commandQueue;
@property (nonatomic, strong) id<MTLComputePipelineState> pipelineState;
@property (nonatomic, strong) DLGPlayerVideoFrame *currentFrame;
@end

@implementation MetalPlayerView

@synthesize isYUV = _isYUV;
@synthesize keepLastFrame = _keepLastFrame;
@synthesize rotation = _rotation;
@synthesize contentSize = _contentSize;

#pragma mark - Constructors

- (id)init {
    self = [super init];
    if (self) {
        [self initProperties];
    }
    return self;
}

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self initProperties];
    }
    return self;
}

#if TARGET_IPHONE_SIMULATOR
#else

#pragma mark - Overridden: MTKView

- (void)drawRect:(CGRect)rect {
    [self executeMetalShader];
}

#pragma mark - Private Properties

- (BOOL)isRenderingAvailable {
    return self.currentDrawable != nil && _currentFrame != nil && _currentFrame.prepared;
}

#pragma mark - Private Methods

- (void)executeMetalShader {
    if (!self.isRenderingAvailable || !_pipelineState) {
        return;
    }
    
    @autoreleasepool {
        id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
        
        if (!commandBuffer) {
            return;
        }
        
        id<MTLComputeCommandEncoder> commandEncoder = [commandBuffer computeCommandEncoder];
        
        if (commandEncoder) {
            float brightness = _currentFrame.brightness;
            
            [commandEncoder setComputePipelineState:_pipelineState];
            [commandEncoder setBytes:&brightness length:sizeof(brightness) atIndex:0];
            [_currentFrame render:commandEncoder];
            [commandEncoder setTexture:self.currentDrawable.texture atIndex:3];
            [commandEncoder dispatchThreadgroups:_threadgroupsPerGrid threadsPerThreadgroup:_threadsPerThreadgroup];
            [commandEncoder endEncoding];
            
            [commandBuffer presentDrawable:self.currentDrawable];
            [commandBuffer commit];
        }
    }
}
    
- (void)setUpPipelineState {
    NSString *name = _isYUV ? @"YUVColorConversion" : @"RGBColorConversion";
    id<MTLFunction> kernelFunction = [_defaultLibrary newFunctionWithName:name];
    
    if (!kernelFunction) {
        NSLog(@"Error creating compute shader");
        return;
    }
    
    _pipelineState = [self.device newComputePipelineStateWithFunction:kernelFunction error:nil];
    
    if (!_pipelineState) {
        NSLog(@"Error creating the pipeline state");
    }
}
#endif

- (void)initProperties {
    self.framebufferOnly = NO;
    self.autoResizeDrawable = NO;
    self.colorPixelFormat = MTLPixelFormatBGRA8Unorm;
    self.contentScaleFactor = UIScreen.mainScreen.scale;
    self.clearColor = MTLClearColorMake(1, 1, 1, 1);
#if TARGET_IPHONE_SIMULATOR
    NSLog(@"[DLGPlayer] Metal will not work on simulator.");
#endif
    self.device = MTLCreateSystemDefaultDevice();
    _commandQueue = [self.device newCommandQueue];
    
    if (@available(iOS 10.0, *)) {
        @autoreleasepool {
            NSBundle *bundle = [NSBundle bundleForClass:[self class]];
            _defaultLibrary = [self.device newDefaultLibraryWithBundle:bundle error:nil];
        }
    } else {
        _defaultLibrary = [self.device newDefaultLibrary];
    }
    
    _threadsPerThreadgroup = MTLSizeMake(16, 16, 1);
    _threadgroupsPerGrid = MTLSizeMake(2048 / _threadsPerThreadgroup.width, 1536 / _threadsPerThreadgroup.height, 1);
}

#pragma mark - Implement: DLGPlayerVideoFrame

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
        _currentFrame = nil;
    }
}

- (void)render:(DLGPlayerVideoFrame *)frame {
    if (frame == nil || frame.width < 1 || frame.height < 1) {
        return;
    }
    
    _currentFrame = frame;
    self.drawableSize = CGSizeMake(frame.width, frame.height);
    
    if ([frame prepareDevice:self.device]) {
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
    
    const id<MTLTexture> texture = self.currentDrawable.texture;
    const NSInteger w = texture.width;
    const NSInteger h = texture.height;
    CIContext *context = [CIContext contextWithMTLDevice:self.device];
    CIImage *outputImage = [[CIImage alloc] initWithMTLTexture:texture options:@{kCIImageColorSpace: (__bridge_transfer id) CGColorSpaceCreateDeviceRGB()}];
    CGImageRef cgImg = [context createCGImage:outputImage fromRect:CGRectMake(0, 0, w, h)];
    UIImage *resultImg = [UIImage imageWithCGImage:cgImg scale:UIScreen.mainScreen.scale orientation:UIImageOrientationDownMirrored];
    CGImageRelease(cgImg);
    return resultImg;
#endif
}

@end

//
//  DLGPlayerVideoYUVFrame.m
//  DLGPlayer
//
//  Created by Liu Junqi on 09/12/2016.
//  Copyright © 2016 Liu Junqi. All rights reserved.
//

#import "DLGPlayerVideoYUVFrame.h"

struct FilterParamters {
    float brightness;
};

@interface DLGPlayerVideoYUVFrame () {
    GLint _sampler[3];
    GLuint _texture[3];
}
@property (nonatomic, strong) id<MTLTexture> yTexture;
@property (nonatomic, strong) id<MTLTexture> uTexture;
@property (nonatomic, strong) id<MTLTexture> vTexture;
@end

@implementation DLGPlayerVideoYUVFrame
    
@synthesize videoType = _videoType;
    
#pragma mark - Constructor
    
- (id)init {
    self = [super init];
    if (self) {
        _videoType = kDLGPlayerVideoFrameTypeYUV;
        for (int i = 0; i < 3; ++i) {
            _sampler[i] = -1;
            _texture[i] = 0;
        }
    }
    return self;
}
    
#pragma mark - Destructor
    
- (void)dealloc {
    [self deleteTextures];
}

#pragma mark - Overidden: DLGPlayerVideoFrame
    
- (BOOL)prepared {
    return (_yTexture != nil && _uTexture != nil && _vTexture != nil) || (_texture[0] != 0);
}
    
- (BOOL)prepareProgram:(GLuint)program {
    const int w = self.width;
    const int h = self.height;
    
    if (_Y.length != w * h) return NO;
    if (_Cb.length != ((w * h) / 4)) return NO;
    if (_Cr.length != ((w * h) / 4)) return NO;
    
    glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
    
    if (_texture[0] == 0) {
        glGenTextures(3, _texture);
        if (_texture[0] == 0) return NO;
    }
    
    const UInt8 *data[3] = { _Y.bytes, _Cb.bytes, _Cr.bytes };
    const int width[3] = { w, w / 2, w / 2 };
    const int height[3] = { h, h / 2, h / 2 };
    
    for (int i = 0; i < 3; ++i) {
        glBindTexture(GL_TEXTURE_2D, _texture[i]);
        glTexImage2D(GL_TEXTURE_2D,
                     0,
                     GL_LUMINANCE,
                     width[i],
                     height[i],
                     0,
                     GL_LUMINANCE,
                     GL_UNSIGNED_BYTE,
                     data[i]);
        
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    }
    
    if (![self initSampler:program]) return NO;
    
    for (int i = 0; i < 3; ++i) {
        glActiveTexture(GL_TEXTURE0 + i);
        glBindTexture(GL_TEXTURE_2D, _texture[i]);
        glUniform1i(_sampler[i], i);
    }
    
    glUniform1f(glGetUniformLocation(program, "f_brightness"), self.brightness);
    
    free(data);
    
    return YES;
}
    
- (BOOL)prepareDevice:(__weak id<MTLDevice>)device {
    const NSInteger w = self.width;
    const NSInteger h = self.height;
    
    if (_Y.length != w * h) return NO;
    if (_Cb.length != ((w * h) / 4)) return NO;
    if (_Cr.length != ((w * h) / 4)) return NO;
    
    [self createMTLTextures:device];
    [self updateMTLTextures];
    return YES;
}
    
- (BOOL)render:(__weak id<MTLComputeCommandEncoder>)encoder {
    if (!self.prepared) {
        return NO;
    }
    
    [encoder setTexture:_yTexture atIndex:0];
    [encoder setTexture:_uTexture atIndex:1];
    [encoder setTexture:_vTexture atIndex:2];
    
    return YES;
}
    
#pragma mark - Private Methods (OpenGL ES)
    
- (void)deleteTextures {
    if (_texture[0] != 0) {
        glDeleteTextures(3, _texture);
        for (int i = 0; i < 3; ++i) {
            _texture[i] = 0;
        }
    }
}
    
- (BOOL)initSampler:(GLuint)program {
    if (_sampler[0] == -1) {
        _sampler[0] = glGetUniformLocation(program, "s_texture_y");
        if (_sampler[0] == -1) return NO;
    }
    if (_sampler[1] == -1) {
        _sampler[1] = glGetUniformLocation(program, "s_texture_u");
        if (_sampler[1] == -1) return NO;
    }
    if (_sampler[2] == -1) {
        _sampler[2] = glGetUniformLocation(program, "s_texture_v");
        if (_sampler[2] == -1) return NO;
    }
    return YES;
}
    
#pragma mark - Private Methods (Metal)
    
- (void)createMTLTextures:(id<MTLDevice>)device {
    if (self.prepared) {
        return;
    }
    
    const NSInteger w = self.width;
    const NSInteger h = self.height;
    
    MTLTextureDescriptor *y = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatR8Uint width:w height:h mipmapped:NO];
    MTLTextureDescriptor *u = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatR8Uint width:w / 2 height:h / 2 mipmapped:NO];
    MTLTextureDescriptor *v = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatR8Uint width:w / 2 height:h / 2 mipmapped:NO];
    
    _yTexture = [device newTextureWithDescriptor:y];
    _uTexture = [device newTextureWithDescriptor:u];
    _vTexture = [device newTextureWithDescriptor:v];
}
    
- (void)updateMTLTextures {
    const NSInteger w = self.width;
    const NSInteger h = self.height;
    
    [_yTexture replaceRegion:MTLRegionMake2D(0, 0, w, h) mipmapLevel:0 withBytes:_Y.bytes bytesPerRow:w];
    [_uTexture replaceRegion:MTLRegionMake2D(0, 0, w / 2, h / 2) mipmapLevel:0 withBytes:_Cb.bytes bytesPerRow:w / 2];
    [_vTexture replaceRegion:MTLRegionMake2D(0, 0, w / 2, h / 2) mipmapLevel:0 withBytes:_Cr.bytes bytesPerRow:w / 2];
}
    
@end


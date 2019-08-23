//
//  DLGPlayerVideoRGBFrame.m
//  DLGPlayer
//
//  Created by Liu Junqi on 09/12/2016.
//  Copyright © 2016 Liu Junqi. All rights reserved.
//

#import "DLGPlayerVideoRGBFrame.h"

@interface DLGPlayerVideoRGBFrame () {
    GLint _sampler;
    GLuint _texture;
    GLint _format;
}
@property (nonatomic, strong) id<MTLTexture> mtlTexture;

@end

@implementation DLGPlayerVideoRGBFrame

- (id)init {
    self = [super init];
    if (self) {
        self.videoType = kDLGPlayerVideoFrameTypeRGB;
        _sampler = -1;
        _texture = 0;
        _hasAlpha = NO;
        _format = GL_RGB;
    }
    return self;
}

- (void)dealloc {
    [self deleteTexture];
}

- (void)deleteTexture {
    if (_texture != 0) {
        glDeleteTextures(1, &_texture);
        _texture = 0;
    }
}
    
#pragma mark - Overidden: DLGPlayerVideoFrame
    
- (BOOL)prepared {
    return (_mtlTexture != nil) || (_texture != 0);
}
    
- (BOOL)prepareProgram:(GLuint)program {
    glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
    
    if (_texture == 0) {
        glGenTextures(1, &_texture);
        if (_texture == 0) return NO;
    }
    
    glBindTexture(GL_TEXTURE_2D, _texture);
    glTexImage2D(GL_TEXTURE_2D,
                 0,
                 _format,
                 self.width,
                 self.height,
                 0,
                 _format,
                 GL_UNSIGNED_BYTE,
                 self.data.bytes);
    
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    
    if (_sampler == -1) {
        _sampler = glGetUniformLocation(program, "s_texture");
        if (_sampler == -1) return NO;
    }
    
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, _texture);
    glUniform1i(_sampler, 0);
    glUniform1f(glGetUniformLocation(program, "f_brightness"), self.brightness);
    
    return YES;
}
    
- (BOOL)prepareDevice:(id<MTLDevice>)device {
    const NSInteger w = self.width;
    const NSInteger h = self.height;
    
    if (self.data.length != w * h) return NO;
    
    [self createMTLTextures:device];
    [self updateMTLTextures];
    return YES;
}
    
- (BOOL)render:(id<MTLComputeCommandEncoder>)encoder {
    if (!self.prepared) {
        return NO;
    }
    
    [encoder setTexture:_mtlTexture atIndex:0];
    
    return YES;
}

#pragma mark - Public Methods
    
- (void)setHasAlpha:(BOOL)hasAlpha {
    _hasAlpha = hasAlpha;
    _format = hasAlpha ? GL_RGBA : GL_RGB;
}
    
#pragma mark - Private Methods (Metal)
    
- (void)createMTLTextures:(id<MTLDevice>)device {
    if (self.prepared) {
        return;
    }
    
    const NSInteger w = self.width;
    const NSInteger h = self.height;
    
    @autoreleasepool {
        MTLTextureDescriptor *descriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatR8Uint width:w height:h mipmapped:NO];
        
        _mtlTexture = [device newTextureWithDescriptor:descriptor];
    }
}
    
- (void)updateMTLTextures {
    const NSInteger w = self.width;
    const NSInteger h = self.height;
    
    [_mtlTexture replaceRegion:MTLRegionMake2D(0, 0, w, h) mipmapLevel:0 withBytes:self.data.bytes bytesPerRow:w];
}

@end

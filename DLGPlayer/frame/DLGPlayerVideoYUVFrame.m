//
//  DLGPlayerVideoYUVFrame.m
//  DLGPlayer
//
//  Created by Liu Junqi on 09/12/2016.
//  Copyright © 2016 Liu Junqi. All rights reserved.
//

#import "DLGPlayerVideoYUVFrame.h"

@interface DLGPlayerVideoYUVFrame () {
    GLint _sampler[3];
    GLuint _texture[3];
}

@end

@implementation DLGPlayerVideoYUVFrame

- (id)init {
    self = [super init];
    if (self) {
        self.videoType = kDLGPlayerVideoFrameTypeYUV;
        for (int i = 0; i < 3; ++i) {
            _sampler[i] = -1;
            _texture[i] = 0;
        }
    }
    return self;
}

- (void)dealloc {
    [self deleteTexture];
}

- (void)deleteTexture {
    if (_texture[0] != 0) {
        glDeleteTextures(3, _texture);
        for (int i = 0; i < 3; ++i) _texture[i] = 0;
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

- (BOOL)prepareRender:(GLuint)program {
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
    
    return YES;
}

@end

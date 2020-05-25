//
//  DLGPlayerDecoder.h
//  DLGPlayer
//
//  Created by Liu Junqi on 05/12/2016.
//  Copyright © 2016 Liu Junqi. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DLGPlayerDecoder : NSObject

@property (nonatomic) BOOL hasAudio;
@property (nonatomic) BOOL hasVideo;
@property (nonatomic) BOOL hasPicture;
@property (nonatomic) BOOL isEOF;
@property (nonatomic) BOOL isYUV;
@property (nonatomic) BOOL mute;

@property (nonatomic) double rotation;
@property (nonatomic) double duration;
@property (nonatomic) double speed;
@property (nonatomic, strong) NSDictionary *metadata;

@property (nonatomic) UInt32 audioChannels;
@property (nonatomic) float audioSampleRate;

@property (nonatomic) double videoFPS;
@property (nonatomic) double videoTimebase;
@property (nonatomic) double audioTimebase;

- (void)close;
- (void)prepareClose;
- (NSArray *)readFrames;
- (BOOL)open:(NSString *)url error:(NSError **)error;
- (void)seek:(double)position;
- (int)videoWidth;
- (int)videoHeight;

@end

//
//  DLGPlayerUtils.m
//  DLGPlayer
//
//  Created by Liu Junqi on 05/12/2016.
//  Copyright © 2016 Liu Junqi. All rights reserved.
//

#import "DLGPlayerUtils.h"
#import "DLGPlayerDef.h"
@import MetalKit;

static BOOL debugEnabled = NO;
static BOOL isMetalSupport = NO;
static BOOL isMetalSupportChecked = NO;

@implementation DLGPlayerUtils

+ (BOOL)createError:(NSError **)error withDomain:(NSString *)domain andCode:(NSInteger)code andMessage:(NSString *)message {
    if (error == nil) return NO;
    @autoreleasepool {
        NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
        if (message != nil) userInfo[NSLocalizedDescriptionKey] = message;
        *error = [NSError errorWithDomain:domain
                                     code:code
                                 userInfo:userInfo];
        return YES;
    }
}

+ (BOOL)createError:(NSError **)error withDomain:(NSString *)domain andCode:(NSInteger)code andMessage:(NSString *)message andRawError:(NSError *)rawError {
    if (error == nil) return NO;
    @autoreleasepool {
        NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
        if (message != nil) userInfo[NSLocalizedDescriptionKey] = message;
        if (rawError != nil) userInfo[NSLocalizedFailureReasonErrorKey] = rawError;
        *error = [NSError errorWithDomain:domain
                                     code:code
                                 userInfo:userInfo];
        return YES;
    }
}

+ (BOOL)debugEnabled {
    return debugEnabled;
}

+ (NSString *)localizedString:(NSString *)name {
    return [[NSBundle bundleForClass:[self class]] localizedStringForKey:name value:nil table:DLGPlayerLocalizedStringTable];
}

+ (NSString *)durationStringFromSeconds:(int)seconds {
    NSMutableString *ms = [[NSMutableString alloc] initWithCapacity:8];
    if (seconds < 0) { [ms appendString:@"∞"]; return ms; }
    
    int h = seconds / 3600;
    [ms appendFormat:@"%d:", h];
    int m = seconds / 60 % 60;
    if (m < 10) [ms appendString:@"0"];
    [ms appendFormat:@"%d:", m];
    int s = seconds % 60;
    if (s < 10) [ms appendString:@"0"];
    [ms appendFormat:@"%d", s];
    return ms;
}

+ (BOOL)isMetalSupport {
    #if !TARGET_IPHONE_SIMULATOR
        if (@available(iOS 9.0, *)) {
            if (isMetalSupportChecked) {
                return isMetalSupport;
            }
            
            isMetalSupport = MTLCreateSystemDefaultDevice() != nil;
            isMetalSupportChecked = YES;
            return isMetalSupport;
        }
    #endif
    return NO;
}

+ (void)setDebugEnabled:(BOOL)enabled {
    debugEnabled = enabled;
}


@end

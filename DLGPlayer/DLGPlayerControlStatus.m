//
//  DLGPlayerControlStatus.m
//  DLGPlayer
//
//  Created by KWANG HYOUN KIM on 19/12/2018.
//  Copyright © 2018 KWANG HYOUN KIM. All rights reserved.
//

#import "DLGPlayerControlStatus.h"

@implementation DLGPlayerControlStatus
{
    DLGPlayerStatus _status;
}

- (instancetype)initWithStatus:(DLGPlayerStatus)status {
    self = [super init];
    if (self) {
        _status = status;
    }
    return self;
}

- (BOOL)playing {
    switch (_status) {
        case DLGPlayerStatusPaused:
        case DLGPlayerStatusClosing:
        case DLGPlayerStatusClosed:
        case DLGPlayerStatusNone:
            return NO;
        default:
            return YES;
    }
}

- (void)setStatus:(DLGPlayerStatus)status {
    _status = status;
}

@end

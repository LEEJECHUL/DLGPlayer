//
//  DLGPlayerControlStatus.h
//  DLGPlayer
//
//  Created by KWANG HYOUN KIM on 19/12/2018.
//  Copyright © 2018 KWANG HYOUN KIM. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DLGPlayerDef.h"

@interface DLGPlayerControlStatus : NSObject
@property (nonatomic) BOOL playing;
- (instancetype)initWithStatus:(DLGPlayerStatus)status;
- (void)setStatus:(DLGPlayerStatus)status;
@end

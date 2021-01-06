//
//  DLGPlayerDef.h
//  DLGPlayer
//
//  Created by Liu Junqi on 05/12/2016.
//  Copyright © 2016 Liu Junqi. All rights reserved.
//

#ifndef DLGPlayerDef_h
#define DLGPlayerDef_h

#define DLGPlayerLocalizedStringTable   @"DLGPlayerStrings"

#define DLGPlayerFrameDropDuration  4
#define DLGPlayerMinBufferDuration  1
#define DLGPlayerMaxBufferDuration  5

#define DLGPlayerErrorDomainDecoder         @"DLGPlayerDecoder"
#define DLGPlayerErrorDomainAudioManager    @"DLGPlayerAudioManager"

#define DLGPlayerErrorCodeInvalidURL                        -1
#define DLGPlayerErrorCodeCannotOpenInput                   -2
#define DLGPlayerErrorCodeCannotFindStreamInfo              -3
#define DLGPlayerErrorCodeNoVideoAndAudioStream             -4

#define DLGPlayerErrorCodeNoAudioOuput                      -5
#define DLGPlayerErrorCodeNoAudioChannel                    -6
#define DLGPlayerErrorCodeNoAudioSampleRate                 -7
#define DLGPlayerErrorCodeNoAudioVolume                     -8
#define DLGPlayerErrorCodeCannotSetAudioCategory            -9
#define DLGPlayerErrorCodeCannotSetAudioActive              -10
#define DLGPlayerErrorCodeCannotInitAudioUnit               -11
#define DLGPlayerErrorCodeCannotCreateAudioComponent        -12
#define DLGPlayerErrorCodeCannotGetAudioStreamDescription   -13
#define DLGPlayerErrorCodeCannotSetAudioRenderCallback      -14
#define DLGPlayerErrorCodeCannotUninitAudioUnit             -15
#define DLGPlayerErrorCodeCannotDisposeAudioUnit            -16
#define DLGPlayerErrorCodeCannotDeactivateAudio             -17
#define DLGPlayerErrorCodeCannotStartAudioUnit              -18
#define DLGPlayerErrorCodeCannotStopAudioUnit               -19

#define Test 10000

#pragma mark - Notification
#define DLGPlayerNotificationAudioOpened            @"DLGPlayerNotificationAudioOpened"
#define DLGPlayerNotificationAudioClosed            @"DLGPlayerNotificationAudioClosed"
#define DLGPlayerNotificationOpened                 @"DLGPlayerNotificationOpened"
#define DLGPlayerNotificationClosed                 @"DLGPlayerNotificationClosed"
#define DLGPlayerNotificationEOF                    @"DLGPlayerNotificationEOF"
#define DLGPlayerNotificationBufferStateChanged     @"DLGPlayerNotificationBufferStateChanged"
#define DLGPlayerNotificationRenderBegan            @"DLGPlayerNotificationRenderBegan"
#define DLGPlayerNotificationError                  @"DLGPlayerNotificationError"

#pragma mark - Notification Key
#define DLGPlayerNotificationBufferStateKey         @"DLGPlayerNotificationBufferStateKey"
#define DLGPlayerNotificationSeekStateKey           @"DLGPlayerNotificationSeekStateKey"
#define DLGPlayerNotificationErrorKey               @"DLGPlayerNotificationErrorKey"
#define DLGPlayerNotificationRawErrorKey            @"DLGPlayerNotificationRawErrorKey"

typedef NS_ENUM(NSUInteger, DLGPlayerStatus) {
    DLGPlayerStatusNone,
    DLGPlayerStatusOpening,
    DLGPlayerStatusAudioOpened,
    DLGPlayerStatusOpened,
    DLGPlayerStatusPlaying,
    DLGPlayerStatusBuffering,
    DLGPlayerStatusPaused,
    DLGPlayerStatusEOF,
    DLGPlayerStatusClosing,
    DLGPlayerStatusAudioClosed,
    DLGPlayerStatusClosed
};

#endif /* DLGPlayerDef_h */

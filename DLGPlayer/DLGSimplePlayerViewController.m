//
//  DLGSimplePlayerViewController.m
//  DLGPlayer
//
//  Created by KWANG HYOUN KIM on 07/12/2018.
//  Copyright © 2018 KWANG HYOUN KIM. All rights reserved.
//

#import "DLGSimplePlayerViewController.h"
#import "DLGPlayerUtils.h"

typedef enum : NSUInteger {
    DLGPlayerOperationNone,
    DLGPlayerOperationOpen,
    DLGPlayerOperationPlay,
    DLGPlayerOperationPause,
    DLGPlayerOperationClose,
} DLGPlayerOperation;

@interface DLGSimplePlayerViewController () {
    BOOL restorePlay;
}

@property (nonatomic, strong) DLGPlayer *player;
@property (nonatomic, readwrite) DLGPlayerStatus status;
@end

@implementation DLGSimplePlayerViewController

- (void)dealloc {
    NSLog(@"DLGSimplePlayerViewController dealloc");
}

#pragma mark - Constructors
- (instancetype)init {
    self = [super init];
    if (self) {
        [self initAll];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self initAll];
    }
    return self;
}

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        [self initAll];
    }
    return self;
}

#pragma mark - View controller life cycle
- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self addPlayerView];
}
    
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self registerNotification];
}
    
- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    [self unregisterNotification];
}

#pragma mark - getter/setter
- (BOOL)hasUrl {
    return _url != nil && [_url stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet].length > 0;
}

- (BOOL)isPlaying {
    return self.player.playing;
}
    
- (void)setStatus:(DLGPlayerStatus)status {
    _status = status;
    [_controlStatus setStatus:_status];
    
    if ([_delegate respondsToSelector:@selector(viewController:didChangeStatus:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate viewController:self didChangeStatus:status];
        });
    }
}

- (BOOL)isMute {
    return self.player.mute;
}

- (void)setIsMute:(BOOL)isMute {
    self.player.mute = isMute;
}

- (double)minBufferDuration {
    return self.player.minBufferDuration;
}

- (void)setMinBufferDuration:(double)minBufferDuration {
    self.player.minBufferDuration = minBufferDuration;
}

- (double)maxBufferDuration {
    return self.player.maxBufferDuration;
}

- (void)setMaxBufferDuration:(double)maxBufferDuration {
    self.player.maxBufferDuration = maxBufferDuration;
}

- (BOOL)isAllowsFrameDrop {
    return self.player.allowsFrameDrop;
}

- (void)setIsAllowsFrameDrop:(BOOL)isAllowsFrameDrop {
    self.player.allowsFrameDrop = isAllowsFrameDrop;
}

- (double)speed {
    return self.player.speed;
}
- (void)setSpeed:(double)speed {
    self.player.speed = speed;
}
    
#pragma mark - Init
- (void)initAll {
    self.player = [[DLGPlayer alloc] init];
    _status = DLGPlayerStatusNone;
    _controlStatus = [[DLGPlayerControlStatus alloc] initWithStatus:_status];
}
    
- (void)open {
    self.status = DLGPlayerStatusOpening;
    [self.player open:_url];
}
    
- (void)play {
    [UIApplication sharedApplication].idleTimerDisabled = _preventFromScreenLock;
    [self.player play];
    self.status = DLGPlayerStatusPlaying;
}
    
- (void)replay {
    self.player.position = 0;
    [self play];
}
    
- (void)pause {
    [UIApplication sharedApplication].idleTimerDisabled = NO;
    [self.player pause];
    self.status = DLGPlayerStatusPaused;
}

- (void)stop {
    self.status = DLGPlayerStatusClosing;
    [UIApplication sharedApplication].idleTimerDisabled = NO;
    [self.player close];
}
    
    
#pragma mark - UI
- (void)addPlayerView {
    UIView *v = self.player.playerView;
    v.translatesAutoresizingMaskIntoConstraints = NO;
    
    [self.view addSubview:v];
    
    // Add constraints
    NSDictionary *views = NSDictionaryOfVariableBindings(v);
    NSArray<NSLayoutConstraint *> *ch = [NSLayoutConstraint constraintsWithVisualFormat:@"H:|[v]|"
                                                                                options:0
                                                                                metrics:nil
                                                                                  views:views];
    [self.view addConstraints:ch];
    NSArray<NSLayoutConstraint *> *cv = [NSLayoutConstraint constraintsWithVisualFormat:@"V:|[v]|"
                                                                                options:0
                                                                                metrics:nil
                                                                                  views:views];
    [self.view addConstraints:cv];
}
    
#pragma mark - Notifications
- (void)registerNotification {
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(notifyAppDidEnterBackground:)
               name:UIApplicationDidEnterBackgroundNotification object:nil];
    [nc addObserver:self selector:@selector(notifyAppWillEnterForeground:)
               name:UIApplicationWillEnterForegroundNotification object:nil];
    [nc addObserver:self selector:@selector(notifyPlayerOpened:) name:DLGPlayerNotificationOpened object:self.player];
    [nc addObserver:self selector:@selector(notifyPlayerClosed:) name:DLGPlayerNotificationClosed object:self.player];
    [nc addObserver:self selector:@selector(notifyPlayerEOF:) name:DLGPlayerNotificationEOF object:self.player];
    [nc addObserver:self selector:@selector(notifyPlayerBufferStateChanged:) name:DLGPlayerNotificationBufferStateChanged object:self.player];
    [nc addObserver:self selector:@selector(notifyPlayerRenderBegan:) name:DLGPlayerNotificationRenderBegan object:self.player];
    [nc addObserver:self selector:@selector(notifyPlayerError:) name:DLGPlayerNotificationError object:self.player];
}

- (void)unregisterNotification {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)notifyAppDidEnterBackground:(NSNotification *)notif {
    if (self.player.playing) {
        [self pause];
        if (_restorePlayAfterAppEnterForeground) restorePlay = YES;
    }
}
    
- (void)notifyAppWillEnterForeground:(NSNotification *)notif {
    if (restorePlay) {
        restorePlay = NO;
        [self play];
    }
}
    
- (void)notifyPlayerEOF:(NSNotification *)notif {
    self.status = DLGPlayerStatusEOF;
    
    if (_isRepeat) {
        [self replay];
    } else {
        [self stop];
    }
}
    
- (void)notifyPlayerClosed:(NSNotification *)notif {
    self.status = DLGPlayerStatusClosed;
}
    
- (void)notifyPlayerOpened:(NSNotification *)notif {
    self.status = DLGPlayerStatusOpened;
    
    if (_isAutoplay) [self play];
}
    
- (void)notifyPlayerBufferStateChanged:(NSNotification *)notif {
    NSDictionary *userInfo = notif.userInfo;
    BOOL state = [userInfo[DLGPlayerNotificationBufferStateKey] boolValue];
    if (state) {
        self.status = DLGPlayerStatusBuffering;
    } else {
        self.status = DLGPlayerStatusPlaying;
    }
}

- (void)notifyPlayerRenderBegan:(NSNotification *)notif {
    if ([_delegate respondsToSelector:@selector(didBeginRenderInViewController:)]) {
        [_delegate didBeginRenderInViewController:self];
    }
}
    
- (void)notifyPlayerError:(NSNotification *)notif {
    NSDictionary *userInfo = notif.userInfo;
    NSError *error = userInfo[DLGPlayerNotificationErrorKey];
    
    if ([error.domain isEqualToString:DLGPlayerErrorDomainDecoder]) {
        self.status = DLGPlayerStatusNone;
        
        if (DLGPlayerUtils.debugEnabled) {
            NSLog(@"Player decoder error: %@", error);
        }
    } else if ([error.domain isEqualToString:DLGPlayerErrorDomainAudioManager]) {
        if (DLGPlayerUtils.debugEnabled) {
            NSLog(@"Player audio error: %@", error);
        }
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.delegate respondsToSelector:@selector(viewController:didReceiveError:)]) {
            [self.delegate viewController:self didReceiveError:error];
        }
        
        [[NSNotificationCenter defaultCenter] postNotificationName:DLGPlayerNotificationError object:self userInfo:notif.userInfo];
    });
}
    
@end

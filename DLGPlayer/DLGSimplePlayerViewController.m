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
    return _player.playing;
}
    
- (void)setStatus:(DLGPlayerStatus)status {
    _status = status;
    [_controlStatus setStatus:_status];
    
    __weak typeof(self)weakSelf = self;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf)strongSelf = weakSelf;
        
        if (strongSelf && [strongSelf.delegate respondsToSelector:@selector(viewController:didChangeStatus:)]) {
            [strongSelf.delegate viewController:strongSelf didChangeStatus:status];
        }
    });
}

- (BOOL)isMute {
    return _player.mute;
}
- (void)setIsMute:(BOOL)isMute {
    _player.mute = isMute;
}

- (double)frameDropDuration {
    return _player.frameDropDuration;
}
- (void)setFrameDropDuration:(double)frameDropDuration {
    _player.frameDropDuration = frameDropDuration;
}

- (double)minBufferDuration {
    return _player.minBufferDuration;
}
- (void)setMinBufferDuration:(double)minBufferDuration {
    _player.minBufferDuration = minBufferDuration;
}

- (double)maxBufferDuration {
    return _player.maxBufferDuration;
}
- (void)setMaxBufferDuration:(double)maxBufferDuration {
    _player.maxBufferDuration = maxBufferDuration;
}

- (BOOL)isAllowsFrameDrop {
    return _player.allowsFrameDrop;
}
- (void)setIsAllowsFrameDrop:(BOOL)isAllowsFrameDrop {
    _player.allowsFrameDrop = isAllowsFrameDrop;
}

- (double)speed {
    return _player.speed;
}
- (void)setSpeed:(double)speed {
    _player.speed = speed;
}
    
#pragma mark - Init
- (void)initAll {
    _player = [[DLGPlayer alloc] init];
    _status = DLGPlayerStatusNone;
    _controlStatus = [[DLGPlayerControlStatus alloc] initWithStatus:_status];
}
    
- (void)open {
    self.status = DLGPlayerStatusOpening;
    [_player open:_url];
}
    
- (void)play {
//    [UIApplication sharedApplication].idleTimerDisabled = self.preventFromScreenLock;
    [_player play];
    self.status = DLGPlayerStatusPlaying;
}
    
- (void)replay {
    _player.position = 0;
    [self play];
}
    
- (void)pause {
//    [UIApplication sharedApplication].idleTimerDisabled = NO;
    [_player pause];
    self.status = DLGPlayerStatusPaused;
}

- (void)stop {
    self.status = DLGPlayerStatusClosing;
//    [UIApplication sharedApplication].idleTimerDisabled = NO;
    [_player close];
}
    
    
#pragma mark - UI
- (void)addPlayerView {
    UIView *v = _player.playerView;
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
    [nc addObserver:self selector:@selector(notifyPlayerAudioOpened:) name:DLGPlayerNotificationAudioOpened object:_player];
    [nc addObserver:self selector:@selector(notifyPlayerAudioClosed:) name:DLGPlayerNotificationAudioClosed object:_player];
    [nc addObserver:self selector:@selector(notifyPlayerOpened:) name:DLGPlayerNotificationOpened object:_player];
    [nc addObserver:self selector:@selector(notifyPlayerClosed:) name:DLGPlayerNotificationClosed object:_player];
    [nc addObserver:self selector:@selector(notifyPlayerEOF:) name:DLGPlayerNotificationEOF object:_player];
    [nc addObserver:self selector:@selector(notifyPlayerBufferStateChanged:) name:DLGPlayerNotificationBufferStateChanged object:_player];
    [nc addObserver:self selector:@selector(notifyPlayerRenderBegan:) name:DLGPlayerNotificationRenderBegan object:_player];
    [nc addObserver:self selector:@selector(notifyPlayerError:) name:DLGPlayerNotificationError object:_player];
}

- (void)unregisterNotification {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)notifyAppDidEnterBackground:(NSNotification *)notif {
    if (_player.playing) {
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

- (void)notifyPlayerAudioOpened:(NSNotification *)notif {
    self.status = DLGPlayerStatusAudioOpened;
}

- (void)notifyPlayerAudioClosed:(NSNotification *)notif {
    self.status = DLGPlayerStatusAudioClosed;
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
    
    __weak typeof(self)weakSelf = self;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf)strongSelf = weakSelf;
        
        if (!strongSelf) {
            return;
        }
        
        if ([strongSelf.delegate respondsToSelector:@selector(viewController:didReceiveError:)]) {
            [strongSelf.delegate viewController:strongSelf didReceiveError:error];
            [[NSNotificationCenter defaultCenter] postNotificationName:DLGPlayerNotificationError object:strongSelf userInfo:notif.userInfo];
        }
    });
}
    
@end

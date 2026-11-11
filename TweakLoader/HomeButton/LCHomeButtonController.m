#import "LCHomeButtonController.h"
#import "LCAppDeparture.h"
#import "LCHomeButtonViewController.h"
#import "LCHomeButtonWindow.h"
#import "LCSharedUtils.h"
#import "../../LiveContainer/utils.h"
#import <notify.h>

// How long the app gets to finish what it does on entering the background,
// such as saving, before ryC0 opens and the app's process ends.
static const NSTimeInterval LCHomeButtonSaveTime = 0.3;
// How long to wait for ryC0 to open before giving the app back.
static const NSTimeInterval LCHomeButtonLeaveTimeout = 4;

@interface LCHomeButtonController ()
@property (nonatomic, nullable) LCHomeButtonWindow *window;
@property (nonatomic, nullable) LCHomeButtonViewController *buttonController;
@property (nonatomic) LCAppDeparture *departure;
@property (nonatomic) BOOL isLeaving;
@property (nonatomic) LCGuestHomeControl homeControl;
@property (nonatomic, weak) UITouch *swipeTouch;
@property (nonatomic, weak) UIWindow *swipeWindow;
@property (nonatomic) CGPoint swipeStart;
@end

@implementation LCHomeButtonController

+ (LCHomeButtonController *)sharedController {
    static LCHomeButtonController *controller;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        controller = [[LCHomeButtonController alloc] init];
    });
    return controller;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _departure = [[LCAppDeparture alloc] init];
    }
    return self;
}

- (void)start {
    self.homeControl = [NSClassFromString(@"LCSharedUtils") guestHomeControl];
    if (self.homeControl == LCGuestHomeControlFloatingButton && [NSUserDefaults.guestAppInfo[@"hideHomeButton"] boolValue]) {
        self.homeControl = LCGuestHomeControlBar;
    }
    NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
    [center addObserver:self selector:@selector(sceneDidActivate:) name:UISceneDidActivateNotification object:nil];
    [center addObserver:self selector:@selector(windowDidBecomeVisible:) name:UIWindowDidBecomeVisibleNotification object:nil];
}

// The button moves to the screen the person is using.
- (void)sceneDidActivate:(NSNotification *)notification {
    if ([notification.object isKindOfClass:UIWindowScene.class] && [self isOwnScreen:notification.object]) {
        [self showSoonInScene:notification.object];
    }
}

// Whether a scene is on the iPhone's or iPad's own screen, rather than an
// external display an app shows video or slides on, where the button would
// leave the iPhone with no way back to ryC0.
- (BOOL)isOwnScreen:(UIWindowScene *)scene {
    return [scene.session.role isEqualToString:UIWindowSceneSessionRoleApplication];
}

// Screens often come up before the app has put its window on them, so the
// button waits for the app's first window before it shows.
- (void)windowDidBecomeVisible:(NSNotification *)notification {
    UIWindow *window = notification.object;
    if (![window isKindOfClass:UIWindow.class] || window == self.window) {
        return;
    }
    UIWindowScene *scene = window.windowScene;
    if (scene && [self isOwnScreen:scene] && (scene.activationState == UISceneActivationStateForegroundActive ||
                  scene.activationState == UISceneActivationStateForegroundInactive)) {
        [self showSoonInScene:scene];
    }
}

// Shows the button once the app is done with the change it is making to its
// windows, rather than in the middle of it.
- (void)showSoonInScene:(UIWindowScene *)scene {
    __weak LCHomeButtonController *weakSelf = self;
    __weak UIWindowScene *weakScene = scene;
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindowScene *laterScene = weakScene;
        if (laterScene) {
            [weakSelf showInScene:laterScene];
        }
    });
}

// Whether the app has put a window with content on the screen. The button's
// window takes its orientation and status bar from that window. The windows
// UIKit keeps for the keyboard sit far above the app's and don't count.
- (BOOL)appHasWindowInScene:(UIWindowScene *)scene {
    for (UIWindow *window in scene.windows) {
        if (window != self.window && !window.hidden && window.rootViewController &&
            window.windowLevel < UIWindowLevelStatusBar) {
            return YES;
        }
    }
    return NO;
}

- (void)showInScene:(UIWindowScene *)scene {
    @try {
        __weak LCHomeButtonController *weakSelf = self;
        if (self.window.windowScene == scene || ![self appHasWindowInScene:scene]) {
            return;
        }
        if (self.window) {
            self.window.windowScene = scene;
            self.window.hidden = NO;
            return;
        }

        LCHomeButtonViewController *buttonController = [[LCHomeButtonViewController alloc] init];
        buttonController.pressHandler = ^{
            [weakSelf returnToHomeOpeningSwitcher:NO];
        };
        buttonController.switcherHandler = ^{
            [weakSelf returnToHomeOpeningSwitcher:YES];
        };
        buttonController.homeControl = self.homeControl;
        LCHomeButtonWindow *window = [[LCHomeButtonWindow alloc] initWithWindowScene:scene];
        window.windowLevel = UIWindowLevelAlert + 1;
        window.backgroundColor = UIColor.clearColor;
        window.rootViewController = buttonController;
        self.buttonController = buttonController;
        self.window = window;
        window.hidden = NO;
    } @catch (NSException *exception) {
        NSLog(@"[LC] The Home button couldn't show: %@", exception);
    }
}

// LiveProcess draws into a remote view. UIKit delivers the touches to this
// process, so observe them here without cancelling the guest's recognizers.
- (void)trackHomeSwipe:(UIEvent *)event {
    if (self.homeControl != LCGuestHomeControlBar) return;
    NSSet<UITouch *> *touches = event.allTouches;
    if (touches.count != 1) {
        self.swipeTouch = nil;
        return;
    }
    UITouch *touch = touches.anyObject;
    if (touch.phase == UITouchPhaseBegan) {
        UIWindow *window = touch.window;
        self.swipeTouch = nil;
        if (!window || window == self.window || window.windowLevel >= UIWindowLevelStatusBar) return;
        CGPoint start = [touch locationInView:window];
        CGFloat center = CGRectGetMidX(window.bounds);
        CGFloat bottom = CGRectGetMaxY(window.bounds) - MAX(27, window.safeAreaInsets.bottom);
        if (fabs(start.x - center) <= 42 && start.y >= bottom - 48 && start.y <= bottom + 4) {
            self.swipeTouch = touch;
            self.swipeWindow = window;
            self.swipeStart = start;
        }
        return;
    }
    UIWindow *window = self.swipeWindow;
    if (touch != self.swipeTouch || !window) return;
    if (touch.phase == UITouchPhaseCancelled) {
        self.swipeTouch = nil;
        return;
    }
    if (touch.phase != UITouchPhaseEnded) return;
    self.swipeTouch = nil;
    CGPoint end = [touch locationInView:window];
    CGFloat dx = end.x - self.swipeStart.x;
    CGFloat dy = end.y - self.swipeStart.y;
    if (dy > -35 || -dy <= fabs(dx) * 1.25) return;

    if (NSUserDefaults.isLiveProcess) {
        const char *token = getenv(LC_HOME_SWIPE_TOKEN_ENV);
        if (!token) return;
        NSString *channel = [@LC_HOME_SWIPE_NOTIFICATION_PREFIX stringByAppendingString:@(token)];
        notify_post(channel.UTF8String);
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self returnToHomeOpeningSwitcher:NO];
        });
    }
}

// Play the Home transition while the classic guest gets time to save.
- (void)returnToHomeOpeningSwitcher:(BOOL)openSwitcher {
    Class sharedUtils = NSClassFromString(@"LCSharedUtils");
    if (self.isLeaving || ![sharedUtils respondsToSelector:@selector(launchToGuestAppWithClassicMode:)]) {
        return;
    }
    self.isLeaving = YES;
    __weak LCHomeButtonController *weakSelf = self;
    NSDictionary *guestInfo = NSUserDefaults.guestAppInfo;
    NSString *bundlePath = NSBundle.mainBundle.bundlePath;
    if ([sharedUtils respondsToSelector:@selector(setSwitcherPreview:forBundlePath:)]) {
        BOOL isPrivate = [guestInfo[@"isHidden"] boolValue] || [guestInfo[@"isLocked"] boolValue];
        UIImage *preview = isPrivate ? nil : [self.buttonController captureGuestPreview];
        [sharedUtils setSwitcherPreview:preview forBundlePath:bundlePath];
    }
    UIImage *backdrop = [sharedUtils respondsToSelector:@selector(takeHomeReturnBackdrop)]
        ? [sharedUtils takeHomeReturnBackdrop] : nil;
    [self.buttonController animateReturnWithBackdrop:backdrop];

    NSUserDefaults *defaults = NSUserDefaults.lcUserDefaults;
    [defaults removeObjectForKey:@"selected"];
    [defaults removeObjectForKey:@"selectedContainer"];
    [defaults removeObjectForKey:@"launchAppUrlScheme"];
    [sharedUtils setAppSwitcherRequested:openSwitcher];
    [defaults synchronize];
    [self.departure leave];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(LCHomeButtonSaveTime * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [weakSelf openRyC0With:sharedUtils];
    });
}

- (void)openRyC0With:(Class)sharedUtils {
    @try {
        [sharedUtils launchToGuestAppWithClassicMode:0];
    } @catch (NSException *exception) {
        NSLog(@"[LC] ryC0 couldn't open: %@", exception);
    }
    __weak LCHomeButtonController *weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(LCHomeButtonLeaveTimeout * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        LCHomeButtonController *controller = weakSelf;
        controller.isLeaving = NO;
        [sharedUtils setAppSwitcherRequested:NO];
        [controller.departure comeBack];
        [controller.buttonController fadeBackIn];
    });
}

@end

// Create the optional floating button in classic guests.
__attribute__((constructor))
static void LCHomeButtonInit(void) {
    if (!NSUserDefaults.lcGuestAppId || NSUserDefaults.isLiveProcess) {
        return;
    }
    [LCHomeButtonController.sharedController start];
}

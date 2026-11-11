#import "LCAppDeparture.h"

@interface LCAppDeparture ()
// The screens the app was told it left, which come back if it stays.
@property (nonatomic) NSArray<UIScene *> *departedScenes;
// Whether the app was told it left, so it is told only once each way.
@property (nonatomic) BOOL hasLeft;
@end

@implementation LCAppDeparture

- (instancetype)init {
    self = [super init];
    if (self) {
        _departedScenes = @[];
    }
    return self;
}

// The app's screens that are on screen now.
+ (NSArray<UIScene *> *)foregroundScenes {
    NSMutableArray<UIScene *> *scenes = [NSMutableArray array];
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (scene.activationState == UISceneActivationStateForegroundActive ||
            scene.activationState == UISceneActivationStateForegroundInactive) {
            [scenes addObject:scene];
        }
    }
    return scenes;
}

// Whether the app runs its screens through scene delegates. UIKit then calls
// those instead of the app delegate's foreground and background methods.
+ (BOOL)usesSceneDelegates:(NSArray<UIScene *> *)scenes {
    for (UIScene *scene in scenes) {
        if (scene.delegate) {
            return YES;
        }
    }
    return NO;
}

// Calls `selector` on the delegate with `argument`, when the delegate has it.
+ (void)callDelegate:(nullable id)delegate selector:(SEL)selector argument:(id)argument {
    if ([delegate respondsToSelector:selector]) {
        void (*call)(id, SEL, id) = (void (*)(id, SEL, id))[delegate methodForSelector:selector];
        call(delegate, selector, argument);
    }
}

// Tells every screen and the app about one step of the change, in the order
// UIKit does: each screen's delegate and notification, then the app's.
- (void)announceSceneSelector:(SEL)sceneSelector
            sceneNotification:(NSNotificationName)sceneNotification
                  appSelector:(SEL)appSelector
              appNotification:(NSNotificationName)appNotification {
    UIApplication *application = UIApplication.sharedApplication;
    NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
    for (UIScene *scene in self.departedScenes) {
        [LCAppDeparture callDelegate:scene.delegate selector:sceneSelector argument:scene];
        [center postNotificationName:sceneNotification object:scene];
    }
    if (![LCAppDeparture usesSceneDelegates:self.departedScenes]) {
        [LCAppDeparture callDelegate:application.delegate selector:appSelector argument:application];
    }
    [center postNotificationName:appNotification object:application];
}

- (void)leave {
    if (self.hasLeft) {
        return;
    }
    self.hasLeft = YES;
    self.departedScenes = [LCAppDeparture foregroundScenes];
    @try {
        [self announceSceneSelector:@selector(sceneWillResignActive:)
                  sceneNotification:UISceneWillDeactivateNotification
                        appSelector:@selector(applicationWillResignActive:)
                    appNotification:UIApplicationWillResignActiveNotification];
        [self announceSceneSelector:@selector(sceneDidEnterBackground:)
                  sceneNotification:UISceneDidEnterBackgroundNotification
                        appSelector:@selector(applicationDidEnterBackground:)
                    appNotification:UIApplicationDidEnterBackgroundNotification];
    } @catch (NSException *exception) {
        NSLog(@"[LC] The app couldn't be told it is leaving: %@", exception);
    }
}

- (void)comeBack {
    if (!self.hasLeft) {
        return;
    }
    self.hasLeft = NO;
    @try {
        [self announceSceneSelector:@selector(sceneWillEnterForeground:)
                  sceneNotification:UISceneWillEnterForegroundNotification
                        appSelector:@selector(applicationWillEnterForeground:)
                    appNotification:UIApplicationWillEnterForegroundNotification];
        [self announceSceneSelector:@selector(sceneDidBecomeActive:)
                  sceneNotification:UISceneDidActivateNotification
                        appSelector:@selector(applicationDidBecomeActive:)
                    appNotification:UIApplicationDidBecomeActiveNotification];
    } @catch (NSException *exception) {
        NSLog(@"[LC] The app couldn't be told it is back: %@", exception);
    }
    self.departedScenes = @[];
}

@end

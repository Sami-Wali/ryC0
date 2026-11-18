//
//  AppSceneView.m
//  LiveContainer
//
//  Created by s s on 2025/5/17.
//
#import "AppSceneViewController.h"
#import "DecoratedAppSceneViewController.h"
#import "LiveContainerSwiftUI-Swift.h"
#import "../LiveContainerSwiftUI/Utilities/LCUtils.h"
#import "PiPManager.h"
#import "Localization.h"
#import "LCSharedUtils.h"
#import "utils.h"
#import "UIKitPrivate+MultitaskSupport.h"
#import <notify.h>

@interface AppSceneViewController()
@property int resizeDebounceToken;
@property(nonatomic, readwrite) bool isNativeWindow;
@property NSUUID* identifier;
@end

@interface AppSceneViewController()
@property(nonatomic, weak) UIWindowScene *hostScene;
@property(nonatomic) NSString *settingsDiffKey;
@property(nonatomic) NSString *sceneID;
@property(nonatomic) NSExtension* extension;
@property(nonatomic) bool isAppTerminationCleanUpCalled;
@property(nonatomic) BOOL terminationRequested;
@property(nonatomic) BOOL isFullScreenGuest;
@property(nonatomic) NSString *previewRequestID;
@property(nonatomic) int previewNotification;
@property(nonatomic) int firstFrameNotification;
@property(nonatomic) int homeSwipeNotification;
@property(nonatomic, readwrite) BOOL hostedGuestHasDrawn;
@property(nonatomic) UIImage *hostedGuestFirstFrameImage;
@property(nonatomic, copy) void (^previewCompletion)(UIImage *);
@end

@implementation AppSceneViewController


- (instancetype)initWithBundleId:(NSString*)bundleId dataUUID:(NSString*)dataUUID delegate:(id<AppSceneViewControllerDelegate>)delegate {
    return [self initWithBundleId:bundleId dataUUID:dataUUID delegate:delegate fullScreen:NO launchURL:nil];
}

- (instancetype)initWithBundleId:(NSString *)bundleId dataUUID:(NSString *)dataUUID
    fullScreenDelegate:(id<AppSceneViewControllerDelegate>)delegate launchURL:(NSString *)launchURL {
    return [self initWithBundleId:bundleId dataUUID:dataUUID delegate:delegate fullScreen:YES launchURL:launchURL];
}

- (instancetype)initWithBundleId:(NSString *)bundleId dataUUID:(NSString *)dataUUID
    delegate:(id<AppSceneViewControllerDelegate>)delegate fullScreen:(BOOL)fullScreen launchURL:(NSString *)launchURL {
    self = [super initWithNibName:nil bundle:nil];
    self.delegate = delegate;
    self.dataUUID = dataUUID;
    self.bundleId = bundleId;
    self.scaleRatio = 1.0;
    self.isAppTerminationCleanUpCalled = false;
    self.isFullScreenGuest = fullScreen;
    self.firstFrameNotification = -1;
    self.homeSwipeNotification = -1;
    self.isNativeWindow = !fullScreen && [NSUserDefaults.lcSharedDefaults integerForKey:@"LCMultitaskMode" ] == 1;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        UIKitFixesInit();
    });
    
    // init extension
    NSError* error = nil;
    NSString *extensionID = LCUtils.liveProcessBundleIdentifier;
    if (extensionID) _extension = [NSExtension extensionWithIdentifier:extensionID error:&error];
    if (!_extension) {
        [delegate appSceneVC:self didInitializeWithError:error ?: [self hostedGuestError:@"LiveProcess is unavailable. Reinstall ryC0 with Keep Extensions enabled."]];
        return nil;
    }
    _extension.preferredLanguages = @[];
    
    NSExtensionItem *item = [NSExtensionItem new];
    NSMutableArray* bookmarks = [NSMutableArray array];
    NSMutableDictionary *userInfo = @{
        @"hostUrlScheme": NSUserDefaults.lcAppUrlScheme,
        @"selected": _bundleId,
        @"selectedContainer": _dataUUID,
        @"bookmarks": bookmarks,
        @"lcHomePath": NSHomeDirectory(),
    }.mutableCopy;
    if (fullScreen) {
        self.previewRequestID = NSUUID.UUID.UUIDString;
        self.previewNotification = -1;
        userInfo[@"ryGuestPreviewToken"] = self.previewRequestID;
    }
    
    NSString *launchAppUrlScheme = launchURL;
    if (!fullScreen) {
        launchAppUrlScheme = [NSUserDefaults.standardUserDefaults stringForKey:@"launchAppUrlScheme"];
        [NSUserDefaults.lcUserDefaults removeObjectForKey:@"launchAppUrlScheme"];
    }
    if(launchAppUrlScheme) {
        [userInfo setValue:launchAppUrlScheme forKey:@"launchAppUrlScheme"];
    }
    
    NSURL *docURL = [NSFileManager.defaultManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].lastObject;
    if ([NSUserDefaults.standardUserDefaults boolForKey:@"LCSharePrivateDataWithLiveProcess"]) {
        NSData* bookmarkData = [docURL bookmarkDataWithOptions:(1<<11) includingResourceValuesForKeys:0 relativeToURL:0 error:0];
        if (bookmarkData) [bookmarks addObject:bookmarkData];
    } else {
        bool isSharedApp = false;
        NSBundle* bundle = [LCSharedUtils findBundleWithBundleId:bundleId isSharedAppOut:&isSharedApp];
        // when mutlitask with private app, we can restrict its sandbox to only its own container
        if (!isSharedApp) {
            NSURL *dataURL = [docURL URLByAppendingPathComponent:[NSString stringWithFormat:@"Data/Application/%@", dataUUID]];
            NSURL *tweaksURL = [docURL URLByAppendingPathComponent:@"Tweaks"];
            NSData *bundleBookmark = [bundle.bundleURL bookmarkDataWithOptions:(1<<11) includingResourceValuesForKeys:0 relativeToURL:nil error:nil];
            if (!bundleBookmark && fullScreen) {
                [delegate appSceneVC:self didInitializeWithError:[self hostedGuestError:@"Could not access the guest app bundle."]];
                return nil;
            }
            if (bundleBookmark) [bookmarks addObject:bundleBookmark];
            NSData* containerBookmark = [dataURL bookmarkDataWithOptions:(1<<11) includingResourceValuesForKeys:0 relativeToURL:0 error:0];
            if(containerBookmark) {
                [bookmarks addObject:containerBookmark];
            }
            NSData *tweaksBookmark = [tweaksURL bookmarkDataWithOptions:(1<<11) includingResourceValuesForKeys:0 relativeToURL:nil error:nil];
            if (tweaksBookmark) [bookmarks addObject:tweaksBookmark];
        }
    }
    // Give the extension access to the host's event inbox without granting it
    // access to other apps' containers or to the whole Documents directory.
    NSURL *events = [LCSharedUtils guestEventsDirectory];
    NSData *eventsBookmark = [events bookmarkDataWithOptions:(1<<11) includingResourceValuesForKeys:0
        relativeToURL:nil error:nil];
    if (eventsBookmark) [bookmarks addObject:eventsBookmark];
    NSURL *systemNotifications = [LCSharedUtils systemNotificationDirectoryForApp:_bundleId container:_dataUUID];
    NSData *systemNotificationsBookmark = [systemNotifications bookmarkDataWithOptions:(1<<11) includingResourceValuesForKeys:0
        relativeToURL:nil error:nil];
    if (systemNotificationsBookmark) userInfo[@"systemNotificationsBookmark"] = systemNotificationsBookmark;
    __weak typeof(self) weakSelf = self;
    if ([delegate respondsToSelector:@selector(appSceneVCRequestedHome:)]) {
        NSString *swipeID = NSUUID.UUID.UUIDString;
        NSString *channel = [@LC_HOME_SWIPE_NOTIFICATION_PREFIX stringByAppendingString:swipeID];
        int token;
        if (notify_register_dispatch(channel.UTF8String, &token, dispatch_get_main_queue(), ^(int notification) {
            AppSceneViewController *controller = weakSelf;
            if (controller && !controller.isAppTerminationCleanUpCalled &&
                (fullScreen || [LCSharedUtils guestHomeControl] == LCGuestHomeControlBar)) {
                [controller.delegate appSceneVCRequestedHome:controller];
            }
        }) == NOTIFY_STATUS_OK) {
            self.homeSwipeNotification = token;
            userInfo[@"ryGuestHomeSwipeToken"] = swipeID;
        }
    }
    item.userInfo = userInfo;

    if (fullScreen) {
        if (@available(iOS 18.0, *)) {
            NSString *channel = [NSString stringWithFormat:@"com.ry0.ryC0.preview.%@.firstFrame", self.previewRequestID];
            int token;
            NSURL *frameURL = [LCSharedUtils guestPreviewTransferURL:self.previewRequestID];
            if (notify_register_dispatch(channel.UTF8String, &token, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^(int notification) {
                notify_cancel(notification);
                UIImage *source = [UIImage imageWithContentsOfFile:frameURL.path];
                UIImage *image = [source imageByPreparingForDisplay] ?: source;
#if DEBUG
                if ([NSProcessInfo.processInfo.arguments containsObject:@"--ryc0-debug-keep-awake"]) {
                    NSURL *diagnostic = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:@"ryc0-first-frame.jpg"]];
                    [NSFileManager.defaultManager removeItemAtURL:diagnostic error:nil];
                    [NSFileManager.defaultManager copyItemAtURL:frameURL toURL:diagnostic error:nil];
                }
#endif
                [NSFileManager.defaultManager removeItemAtURL:frameURL error:nil];
                dispatch_async(dispatch_get_main_queue(), ^{
                    AppSceneViewController *controller = weakSelf;
                    if (!controller || controller.isAppTerminationCleanUpCalled) return;
                    controller.firstFrameNotification = -1;
                    controller.hostedGuestFirstFrameImage = image;
                    controller.hostedGuestHasDrawn = YES;
                    if ([controller.delegate respondsToSelector:@selector(appSceneVCGuestDidDraw:)]) {
                        [controller.delegate appSceneVCGuestDidDraw:controller];
                    }
                });
            }) == NOTIFY_STATUS_OK) {
                self.firstFrameNotification = token;
            }
        }
    }
    [_extension setRequestCancellationBlock:^(NSUUID *uuid, NSError *error) {
        if (fullScreen) {
            dispatch_async(dispatch_get_main_queue(), ^{
                AppSceneViewController *controller = weakSelf;
                if (!controller || controller.isAppTerminationCleanUpCalled) return;
                [controller.delegate appSceneVC:controller didInitializeWithError:error ?: [controller hostedGuestError:@"The guest launch was cancelled."]];
                [controller appTerminationCleanUp];
            });
            return;
        }
        [weakSelf appTerminationCleanUp];
        [weakSelf.delegate appSceneVC:weakSelf didInitializeWithError:error];
    }];
    [_extension setRequestInterruptionBlock:^(NSUUID *uuid) {
        [weakSelf appTerminationCleanUp];
    }];
    [_extension beginExtensionRequestWithInputItems:@[item] completion:^(NSUUID *identifier) {
        if (fullScreen) {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.identifier = identifier;
                self.pid = identifier ? [self.extension pidForRequestIdentifier:identifier] : 0;
                BOOL usedByWindow = [MultitaskManager ownsWindowProcess:self.pid];
                if (self.isAppTerminationCleanUpCalled) {
                    if (!usedByWindow && self.pid != getpid()) [self terminate];
                    return;
                }
                if (!self.isAppRunning || self.pid == getpid() || usedByWindow || ![self setUpAppPresenter]) {
                    [self.delegate appSceneVC:self didInitializeWithError:[self hostedGuestError:@"LiveProcess could not start a separate guest scene."]];
                    if (!usedByWindow && self.pid != getpid()) [self terminate];
                    [self appTerminationCleanUp];
                    return;
                }
                [self.delegate appSceneVC:self didInitializeWithError:nil];
            });
            return;
        }
        if(identifier) {
            // The list of containers in use is changed only on the main thread
            dispatch_async(dispatch_get_main_queue(), ^{
                if(!self.isAppTerminationCleanUpCalled) {
                    [MultitaskManager register:self];
                }
            });
            self.identifier = identifier;
            self.pid = [self.extension pidForRequestIdentifier:self.identifier];
            [delegate appSceneVC:self didInitializeWithError:nil];
            dispatch_async(dispatch_get_main_queue(), ^{
                [self setUpAppPresenter];
            });
        } else {
            NSError* error = [NSError errorWithDomain:@"LiveProcess" code:2 userInfo:@{NSLocalizedDescriptionKey: @"Failed to start app. Child process has unexpectedly crashed"}];
            [delegate appSceneVC:self didInitializeWithError:error];
        }
    }];
    
    return self;
}

- (NSError *)hostedGuestError:(NSString *)message {
    return [NSError errorWithDomain:@"LiveProcess" code:2 userInfo:@{NSLocalizedDescriptionKey: message}];
}

- (BOOL)setUpAppPresenter {
    RBSProcessPredicate* predicate = [PrivClass(RBSProcessPredicate) predicateMatchingIdentifier:@(self.pid)];
    FBProcessManager *manager = [PrivClass(FBProcessManager) sharedInstance];
    // At this point, the process is spawned and we're ready to create a scene to render in our app
    RBSProcessHandle* processHandle = [PrivClass(RBSProcessHandle) handleForPredicate:predicate error:nil];
    if (!processHandle) return NO;
    [manager registerProcessForAuditToken:processHandle.auditToken];
    UIApplicationSceneSpecification *specification = [UIApplicationSceneSpecification specification];
    
    void (^updateSceneSettings)(id) = ^void(UIMutableApplicationSceneSettings *settings) {
        settings.canShowAlerts = YES;
        settings.cornerRadiusConfiguration = [[PrivClass(BSCornerRadiusConfiguration) alloc] initWithTopLeft:self.view.layer.cornerRadius bottomLeft:self.view.layer.cornerRadius bottomRight:self.view.layer.cornerRadius topRight:self.view.layer.cornerRadius];
        settings.displayConfiguration = UIScreen.mainScreen.displayConfiguration;
        settings.foreground = YES;
        //settings.interruptionPolicy = 2; // reconnect
        settings.level = 1;
        settings.persistenceIdentifier = self.dataUUID;
        settings.statusBarDisabled = !self.isNativeWindow && !self.isFullScreenGuest;
        //settings.previewMaximumSize =
        //settings.deviceOrientationEventsEnabled = YES;
        if(!self.usesHostingControllerAPI) {
            settings.safeAreaInsetsPortrait = self.view.safeAreaInsets;
        }
    };
    void (^updateSceneClientSettings)(id) = ^void(UIMutableApplicationSceneClientSettings *clientSettings) {
        clientSettings.interfaceOrientation = UIInterfaceOrientationPortrait;
        clientSettings.statusBarStyle = 0;
    };

    if (@available(iOS 18.0, *)) {
        // Use new API for iOS 18+. While some of these APIs are available since 17.0, we're only interested in fixing event deferring issue
        _UISceneHostingControllerAdvancedConfiguration *config = [[_UISceneHostingControllerAdvancedConfiguration alloc] initWithProcessIdentity:processHandle.identity];
        config.sceneSpecification = specification;
        if (@available(iOS 27.0, *)) {} else {
            // on 27 manually adding this is not need, also setAdditionalExtensions: doesn't exist for some reason
            config.additionalExtensions = [NSOrderedSet orderedSetWithArray:@[
                PrivClass(_UISceneHostingEventDeferringExtension),
            ]];
        }
        self.hostingController = [[_UISceneHostingController alloc] initWithAdvancedConfiguration:config];
        /// !! do NOT use self.hostingController.sceneView here as it breaks keyboard focus on iOS 26 below. I have no idea why this happens even though both return the same object. Maybe sceneView didn't initialize its ViewController properly?
        self.contentView = self.hostingController.sceneViewController.view;
        self.contentView.clipsToBounds = NO;
        // _scenePresenter was a property in 26, but made only ivar in 27
        self.presenter = [self.contentView valueForKey:@"_scenePresenter"];
        if (self.isFullScreenGuest && !self.presenter.scene) return NO;
        self.sceneID = self.presenter.identifier;
        FBScene *scene = self.presenter.scene;
        [scene configureParameters:^(FBSMutableSceneParameters *parameters) {
            [parameters updateSettingsWithBlock:updateSceneSettings];
            [parameters updateClientSettingsWithBlock:updateSceneClientSettings];
        }];
        
        /// Fix keyboard focus by setting up event deferring extension. Previously we worked around it by changing identifier, but that broke other things
        _UISceneEventDeferringHostComponent *deferringComponent = self.hostingController._eventDeferringComponent;
        NSAssert(deferringComponent, @"Unexpectedly nil _UISceneEventDeferringHostComponent");
        if (@available(iOS 27.0, *)) { // _UIKeyboardArbiterUsesDeferringGraph()
            /// UIKitCore`__85-[_UIRemoteViewControllerSceneHostingImpl _viewServiceHostSessionDidConnectToClient:]_block_invoke
            /// iOS 27 requires setting up _UISceneEventDeferringHostComponent for keyboard focus to work
            
            /// Replicate these methods since they are made private
            /// -[_UISceneEventDeferringHostComponent setFirstResponderTrackingSelectionPath:]:
            [deferringComponent setValue:self forKey:@"_firstResponderTrackingSelectionPath"];
            // if (!deferringComponent->_flags.clientIsInChain) return;
            /// -[_UISceneEventDeferringHostComponent becomeFirstResponderIfNecessary]:
            // if (deferringComponent->_flags.maintainHostFirstResponderWhenClientWantsKeyboard)
            
            deferringComponent.grantBehavior = 2;
            deferringComponent.selectionRequestBehavior = 2;
        }
        /// UIKitCore`-[_UISceneHostingController createSceneWithConfiguration:]
        /// Lower iOS uses _UISceneHostingEventDeferringExtension, no further setup needed
        
        // Now it's time to get the initial settings from decorated VC
        if ([self.delegate respondsToSelector:@selector(appSceneVCWillActivateScene:)]) {
            [self.delegate appSceneVCWillActivateScene:self];
        }
        [self addChildViewController:self.hostingController.sceneViewController];
        
        // For new API, let FBSSceneObserver send host scene events instead of NSExtensionContext
        NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
        [center removeObserver:self.extension name:UIApplicationDidBecomeActiveNotification object:UIApp];
        [center removeObserver:self.extension name:UIApplicationWillResignActiveNotification object:UIApp];
        [center removeObserver:self.extension name:UIApplicationDidEnterBackgroundNotification object:UIApp];
        [center removeObserver:self.extension name:UIApplicationWillEnterForegroundNotification object:UIApp];
    } else {
        self.sceneID = [NSString stringWithFormat:@"sceneID:%@-%@", NSBundle.mainBundle.bundleIdentifier, self.dataUUID];
        FBSMutableSceneDefinition *definition = [PrivClass(FBSMutableSceneDefinition) definition];
        definition.identity = [PrivClass(FBSSceneIdentity) identityForIdentifier:self.sceneID];
        definition.clientIdentity = [PrivClass(FBSSceneClientIdentity) identityForProcessIdentity:processHandle.identity];
        definition.specification = specification;
        
        FBSMutableSceneParameters *parameters = [PrivClass(FBSMutableSceneParameters) parametersForSpecification:specification];
        [parameters updateSettingsWithBlock:updateSceneSettings];
        [parameters updateClientSettingsWithBlock:updateSceneClientSettings];
        FBScene *scene = [[PrivClass(FBSceneManager) sharedInstance] createSceneWithDefinition:definition initialParameters:parameters];
        self.presenter = [scene.uiPresentationManager createPresenterWithIdentifier:self.sceneID];
        [self.presenter modifyPresentationContext:^(UIMutableScenePresentationContext *context) {
            context.appearanceStyle = 2;
        }];
        [self.presenter activate];
        
        self.contentView = [[UIView alloc] init];
        [self.contentView addSubview:self.presenter.presentationView];
    }
    [self.view addSubview:_contentView];
    
    // If we have a staging URL scheme, pass it now
    NSString *launchUrl = self.isFullScreenGuest ? nil : [NSUserDefaults.standardUserDefaults stringForKey:@"launchAppUrlScheme"];
    if(launchUrl) {
        [NSUserDefaults.standardUserDefaults removeObjectForKey:@"launchAppUrlScheme"];
        [self openURLScheme:launchUrl];
    }
    
    __weak typeof(self) weakSelf = self;
    [self.extension setRequestInterruptionBlock:^(NSUUID *uuid) {
        [weakSelf appTerminationCleanUp];
    }];
    self.contentView.layer.anchorPoint = CGPointMake(0, 0);
    self.contentView.layer.position = CGPointMake(0, 0);
    
    // Unregister later from the same scene: the view has no window by then. The
    // legacy scene ID repeats for a container, so the key is this window's own.
    self.settingsDiffKey = NSUUID.UUID.UUIDString;
    [self updateHostScene:self.view.window.windowScene];
    return YES;
}

- (void)setHostedGuestVisible:(BOOL)visible {
    _UIScenePresenter *presenter = self.presenter;
    if (!self.isFullScreenGuest || self.isAppTerminationCleanUpCalled || !presenter) return;
    [presenter.scene updateSettingsWithBlock:^(UIMutableApplicationSceneSettings *settings) {
        settings.foreground = visible;
        if (visible) settings.deactivationReasons = 0;
    }];
    if (visible && !presenter.isActive) {
        [presenter activate];
    } else if (!visible && presenter.isActive) {
        [presenter deactivate];
    }
}

- (UIImage *)takeHostedGuestFirstFrameImage {
    UIImage *image = self.hostedGuestFirstFrameImage;
    self.hostedGuestFirstFrameImage = nil;
    return image;
}

- (void)requestHostedGuestPreview:(void (^)(UIImage *))completion {
    if (!self.previewRequestID) return;
    NSURL *url = [LCSharedUtils guestPreviewTransferURL:self.previewRequestID];
    if (!url) return;
    self.previewCompletion = completion;
    NSString *channel = [@"com.ry0.ryC0.preview." stringByAppendingString:self.previewRequestID];
    if (self.previewNotification < 0) {
        int token = -1;
        __weak typeof(self) weakSelf = self;
        uint32_t status = notify_register_dispatch([channel stringByAppendingString:@".ready"].UTF8String, &token,
            dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^(int notification) {
                UIImage *source = [UIImage imageWithContentsOfFile:url.path];
                UIImage *image = [source imageByPreparingForDisplay] ?: source;
                [NSFileManager.defaultManager removeItemAtURL:url error:nil];
                dispatch_async(dispatch_get_main_queue(), ^{
                    void (^completed)(UIImage *) = weakSelf.previewCompletion;
                    weakSelf.previewCompletion = nil;
                    if (completed) completed(image);
                });
            });
        if (status != NOTIFY_STATUS_OK) {
            self.previewCompletion = nil;
            return;
        }
        self.previewNotification = token;
    }
    notify_post(channel.UTF8String);
}

- (NSTimeInterval)terminationGracePeriod {
    return self.isFullScreenGuest ? 1.0 : 3.0;
}

- (void)terminate {
    if (self.terminationRequested || !self.isAppRunning) return;
    self.terminationRequested = YES;
    pid_t pid = self.pid;
    [self.extension _kill:SIGTERM];
    int64_t delay = (int64_t)(self.terminationGracePeriod * NSEC_PER_SEC);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, delay), dispatch_get_main_queue(), ^{
        if (self.pid == pid && self.isAppRunning) {
            [self.extension _kill:SIGKILL];
        }
    });
}

- (void)_performActionsForUIScene:(UIScene *)scene withUpdatedFBSScene:(id)fbsScene settingsDiff:(FBSSceneSettingsDiff *)diff fromSettings:(UIApplicationSceneSettings *)settings transitionContext:(id)context lifecycleActionType:(uint32_t)actionType {
    if(!self.isAppRunning) {
        [self appTerminationCleanUp];
    }
    if (!diff || ![self.delegate respondsToSelector:@selector(appSceneVC:didUpdateFromSettings:transitionContext:lifecycleActionType:)]) return;
    
    UIMutableApplicationSceneSettings *baseSettings = [diff settingsByApplyingToMutableCopyOfSettings:settings];
    UIApplicationSceneTransitionContext *newContext = [context copy];
    newContext.actions = nil;
    [self.delegate appSceneVC:self didUpdateFromSettings:baseSettings transitionContext:newContext lifecycleActionType:actionType];
}

- (void)viewWillLayoutSubviews {
    /// For native window we let iPadOS handle it however it wants, which is usually live resize (autoresizingMask set in appSceneVCWillActivateScene)
    if(_contentView.autoresizingMask != (UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight)) {
        [self updateFrameWithSettingsBlock:nil];
    }
}
- (void)updateFrameWithSettingsBlock:(void (^)(UIMutableApplicationSceneSettings *settings))block {
    __block int currentDebounceToken = ++_resizeDebounceToken;
    dispatch_block_t queueBlock = ^{
        if(currentDebounceToken != self.resizeDebounceToken) {
            return;
        }
        [self updateSettingsWithBlock:^(UIMutableApplicationSceneSettings *settings) {
            settings.deviceOrientation = UIDevice.currentDevice.orientation;
            settings.interfaceOrientation = self.view.window.windowScene.interfaceOrientation;
            CGRect frame = self.view.frame;
            if(!self.usesHostingControllerAPI) {
                frame.size.width /= self.scaleRatio;
                frame.size.height /= self.scaleRatio;
            }
            if(UIInterfaceOrientationIsLandscape(settings.interfaceOrientation)) {
                CGSize size = frame.size;
                frame.size.width = size.height;
                frame.size.height = size.width;
            }
            settings.frame = frame;
            if(block) {
                block(settings);
            }
        }];
    };
    if(_shouldSkipDebounceOnce) {
        _shouldSkipDebounceOnce = NO;
        queueBlock();
    } else {
        dispatch_time_t delay = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC));
        dispatch_after(delay, dispatch_get_main_queue(), queueBlock);
    }
}
- (void)updateSettingsWithBlock:(void(^)(UIMutableApplicationSceneSettings *settings))updateSettingsBlock {
    if(_shouldIgnoreSceneUpdates) {
        // Ignore all updates when in PiP mode
        return;
    }
    
    if(!_hostingController && self.contentView) {
        // Legacy path
        [self.presenter.scene updateSettingsWithBlock:updateSettingsBlock];
        return;
    }
    
    /// iOS 18.0 path, most are automatically handled by setting values to _UISceneHostingViewController
    /// This is also reachable on legacy path when contentView is nil during early setup
    UIMutableApplicationSceneSettings *tempSettings = [self.presenter.scene.settings mutableCopy];
    if(!tempSettings) {
        tempSettings = [UIMutableApplicationSceneSettings new];
    }
    updateSettingsBlock(tempSettings);
    CGRect frame = tempSettings.frame;
    if(UIInterfaceOrientationIsLandscape(tempSettings.interfaceOrientation)) {
        frame = CGRectMake(frame.origin.x, frame.origin.y, frame.size.height, frame.size.width);
    }
    
    if (self.contentView) {
        // Discard position
        frame.origin = CGPointZero;
        self.contentView.frame = frame;
    } else {
        // This method can be called while contentView is nil to set up initial frame
        self.view.frame = frame;
    }
}

- (void)dealloc {
    if (_homeSwipeNotification >= 0) notify_cancel(_homeSwipeNotification);
}

- (BOOL)isAppRunning {
    return _pid > 0 && getpgid(_pid) > 0;
}

- (void)appTerminationCleanUp {
    if(_isAppTerminationCleanUpCalled) {
        return;
    }
    _isAppTerminationCleanUpCalled = true;
    if (self.homeSwipeNotification >= 0) {
        notify_cancel(self.homeSwipeNotification);
        self.homeSwipeNotification = -1;
    }
    if (self.firstFrameNotification >= 0) {
        notify_cancel(self.firstFrameNotification);
        self.firstFrameNotification = -1;
    }
    if (self.previewRequestID && self.previewNotification >= 0) {
        notify_cancel(self.previewNotification);
        self.previewNotification = -1;
        self.previewCompletion = nil;
    }
    self.hostedGuestFirstFrameImage = nil;
    if (self.previewRequestID) {
        NSURL *preview = [LCSharedUtils guestPreviewTransferURL:self.previewRequestID];
        if (preview) [NSFileManager.defaultManager removeItemAtURL:preview error:nil];
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        if(self.sceneID) {
            [[PrivClass(FBSceneManager) sharedInstance] destroyScene:self.sceneID withTransitionContext:nil];
        }
        if(self.usesHostingControllerAPI) {
            if(@available(iOS 17.0, *)) {
                [self.hostingController invalidate];
                [self.hostingController.sceneViewController removeFromParentViewController];
                self.hostingController = nil;
            }
        } else if(self.presenter){
            [self.presenter deactivate];
            [self.presenter invalidate];
        }
        self.presenter = nil;
        
        [self.delegate appSceneVCAppDidExit:self];
        if (!self.isFullScreenGuest) [MultitaskManager unregister:self];
    });
}

- (void)setBackgroundNotificationEnabled:(bool)enabled {
    if(self.usesHostingControllerAPI) {
        /// Issue with new API: FBSSceneObserver takes priority over to send UIApplicationWillResignActiveNotification regressed #942,
        /// so here we make it foreground (UIApplicationDidBecomeActiveNotification) again.
        [self.presenter.scene updateSettingsWithBlock:^(UIMutableApplicationSceneSettings *settings) {
            settings.foreground = YES;
            settings.deactivationReasons = 0;
        }];
        return;
    }
    NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
    if(enabled) {
        // Re-add UIApplicationDidEnterBackgroundNotification
        [center addObserver:self.extension selector:@selector(_hostDidEnterBackgroundNote:) name:UIApplicationDidEnterBackgroundNotification object:UIApp];
        [center addObserver:self.extension selector:@selector(_hostWillResignActiveNote:) name:UIApplicationWillResignActiveNotification object:UIApp];
    } else {
        // Remove UIApplicationDidEnterBackgroundNotification so apps like YouTube can continue playing video
        [center removeObserver:self.extension name:UIApplicationDidEnterBackgroundNotification object:UIApp];
        [center removeObserver:self.extension name:UIApplicationWillResignActiveNotification object:UIApp];
    }
}

- (void)viewDidMoveToWindow:(UIWindow *)newWindow shouldAppearOrDisappear:(BOOL)appear {
    [super viewDidMoveToWindow:newWindow shouldAppearOrDisappear:appear];
    if (self.isFullScreenGuest) {
        [self updateHostScene:newWindow.windowScene];
        return;
    }
    if(!newWindow) {
        [self updateHostScene:nil];
        self.settingsDiffKey = nil;
        self.delegate = nil;
    }
}

- (void)updateHostScene:(UIWindowScene *)scene {
    if (!self.settingsDiffKey || self.hostScene == scene) return;
    [self.hostScene _unregisterSettingsDiffActionArrayForKey:self.settingsDiffKey];
    self.hostScene = scene;
    [scene _registerSettingsDiffActionArray:@[self] forKey:self.settingsDiffKey];
}

- (void)openURLScheme:(NSString *)urlString {
    [self.presenter.scene updateSettingsWithTransitionBlock:^(id settings) {
        // pull from UserDefaults.standard.setValue(launchURLStr, forKey: "launchAppUrlScheme")
        UIApplicationSceneTransitionContext *context = [UIApplicationSceneTransitionContext new];
        NSURL *url = [NSURL URLWithString:urlString];
        context.payload = @{UIApplicationLaunchOptionsURLKey: urlString};
        context.actions = [NSSet setWithObject:[[UIOpenURLAction alloc] initWithURL:url]];
        return context;
    }];
}

- (void)handleStatusBarTapAction:(UIAction *)action {
    [self.presenter.scene updateSettingsWithTransitionBlock:^(id settings) {
        UIApplicationSceneTransitionContext *context = [UIApplicationSceneTransitionContext new];
        context.actions = [NSSet setWithObject:action];
        return context;
    }];
}

- (BOOL)usesHostingControllerAPI {
    return _hostingController != nil;
}

@end
 

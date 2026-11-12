#import "RYNativeAppSwitcher.h"
#import <objc/message.h>
#import <objc/runtime.h>
#import <dlfcn.h>

void LCLoadSpringBoardFramework(void);

typedef void (^RYCompletion)(BOOL);
static __weak RYNativeAppSwitcher *RYCurrentSwitcher;
static void *RYDeckOffsetContext = &RYDeckOffsetContext;

// Declared initializer families let ARC transfer the allocated receiver and
// owned result correctly, including initializers which return another object.
@protocol RYDeckConstructing
- (instancetype)initWithRootModifier:(id)modifier;
- (instancetype)initWithPersonality:(id)personality liveContentOverlayCoordinator:(id)overlay dataSource:(id)source delegate:(id)delegate applicationController:(id)applications debugName:(id)name;
- (instancetype)initWithPersonality:(id)personality liveContentOverlayCoordinator:(id)overlay dataSource:(id)source delegate:(id)delegate debugName:(id)name;
- (instancetype)initWithItemsForLayoutRoles:(id)items environment:(NSInteger)environment preferredDisplayOrdinal:(NSInteger)ordinal;
- (instancetype)initWithItemsForLayoutRoles:(id)items configuration:(NSInteger)configuration environment:(NSInteger)environment preferredDisplayOrdinal:(NSInteger)ordinal;
- (instancetype)_initWithLayoutElements:(id)elements interfaceOrientation:(NSInteger)orientation interfaceOrientationByLayoutElement:(id)orientations spaceConfiguration:(NSInteger)space floatingConfiguration:(NSInteger)floating unlockedEnvironmentMode:(NSInteger)mode floatingSwitcherVisible:(BOOL)visible centerConfiguration:(NSInteger)center centerEntityModal:(BOOL)modal peekConfiguration:(NSInteger)peek bundleIDShowingAppExpose:(id)bundle windowPickerRole:(NSInteger)role displayOrdinal:(NSInteger)ordinal isDisplayExternal:(BOOL)external;
- (instancetype)initWithTransitionID:(id)identifier phase:(NSUInteger)phase animated:(BOOL)animated;
@end

@implementation RYNativeSwitcherItem
@end

static id RYGet(id object, NSString *key) {
    if (!object) return nil;
    @try { return [object valueForKey:key]; } @catch (__unused NSException *error) { return nil; }
}
static id RYSend(id object, NSString *name) {
    SEL selector = NSSelectorFromString(name);
    return [object respondsToSelector:selector] ? ((id (*)(id, SEL))objc_msgSend)(object, selector) : nil;
}
static void RYSet(id object, NSString *key, id value) {
    @try { [object setValue:value forKey:key]; } @catch (__unused NSException *error) { }
}
static UIScrollView *RYFindDeck(UIView *view) {
    if ([view isKindOfClass:UIScrollView.class] && [NSStringFromClass(view.class) containsString:@"Switcher"]) return (id)view;
    for (UIView *child in view.subviews) { UIScrollView *found = RYFindDeck(child); if (found) return found; }
    return nil;
}
static void RYAdd(Class cls, NSString *selector, id block, const char *types) {
    class_addMethod(cls, NSSelectorFromString(selector), imp_implementationWithBlock(block), types);
}
@interface RYRuntimeNull : NSObject
@end
@implementation RYRuntimeNull
+ (BOOL)resolveInstanceMethod:(SEL)selector {
    if (sel_getName(selector)[0] == '_') return [super resolveInstanceMethod:selector];
    return class_addMethod(self, selector, imp_implementationWithBlock(^id(id object) { return nil; }), "@16@0:8");
}
@end

@interface RYRuntimeChain : NSObject
@end
@implementation RYRuntimeChain
+ (BOOL)resolveInstanceMethod:(SEL)selector {
    if (sel_getName(selector)[0] == '_') return [super resolveInstanceMethod:selector];
    return class_addMethod(self, selector, imp_implementationWithBlock(^id(id object) { return object; }), "@16@0:8");
}
@end

@interface RYLiveOverlayCoordinator : RYRuntimeNull
@property (nonatomic) NSInteger containerOrientation;
@property (nonatomic) BOOL liveContentOverlayUpdatesSuspended;
@property (nonatomic, weak) id delegate;
@end
@implementation RYLiveOverlayCoordinator
- (instancetype)init { if ((self = [super init])) _containerOrientation = 1; return self; }
- (BOOL)areLiveContentOverlayUpdatesSuspended { return self.liveContentOverlayUpdatesSuspended; }
@end

@interface RYSwitcherApplication : RYRuntimeNull
@property (nonatomic, copy) NSString *bundleIdentifier;
@end

@interface RYNativeAppSwitcher () <UIGestureRecognizerDelegate>
@property (nonatomic, strong) UIViewController *deck;
@property (nonatomic, strong) UIVisualEffectView *blurView;
@property (nonatomic, strong) UIView *dimView;
@property (nonatomic, strong) UIViewPropertyAnimator *blurAnimator;
@property (nonatomic, strong) CADisplayLink *blurLink;
@property (nonatomic, strong) CADisplayLink *clampLink;
@property (nonatomic, strong) id liveOverlayCoordinator;
@property (nonatomic, strong) NSMutableDictionary<NSString *, id> *layoutsByScene;
@property (nonatomic, strong) NSMutableDictionary<NSString *, RYNativeSwitcherItem *> *itemsByScene;
@property (nonatomic, strong) NSMutableDictionary<NSString *, id> *applications;
@property (nonatomic, strong) NSMutableSet<NSString *> *closing;
@property (nonatomic, strong) NSArray *appLayouts;
@property (nonatomic, strong, nullable) id activatingLayout;
@property (nonatomic, strong, nullable) id leavingLayout;
@property (nonatomic, strong) id layoutProvider;
@property (nonatomic, weak) id snapshotCache;
@property (nonatomic) BOOL usesNativeDeck;
@property (nonatomic) BOOL started;
@property (nonatomic) BOOL exiting;
@property (nonatomic) NSUInteger generation;
@property (nonatomic) double blurFrom;
@property (nonatomic) double blurTo;
@property (nonatomic) double blurStart;
@property (nonatomic) double blurProgress;
@property (nonatomic, copy) RYCompletion blurCompletion;
@property (nonatomic) double clampDeadline;
@property (nonatomic) double pendingOffset;
@property (nonatomic) double pendingContentWidth;
@property (nonatomic, weak) UIScrollView *observedScroll;
@property (nonatomic, strong) NSMutableDictionary<NSString *, UIAccessibilityElement *> *cardAccessibility;
- (RYNativeSwitcherItem *)itemForBundle:(NSString *)bundle;
- (void)requestSnapshotForScene:(NSString *)scene completion:(void (^)(UIImage * _Nullable))completion;
- (void)transitionFrom:(NSInteger)from to:(NSInteger)to animated:(BOOL)animated completion:(nullable RYCompletion)completion;
- (void)closeScene:(NSString *)scene;
- (void)openScene:(NSString *)scene;
- (void)setBlurProgress:(double)progress mode:(NSInteger)mode completion:(nullable RYCompletion)completion;
- (void)updateAccessibility;
@end

@interface RYDeckAccessibilityCard : UIAccessibilityElement
@property (nonatomic, weak) RYNativeAppSwitcher *host;
@property (nonatomic, copy) NSString *scene;
@end
@implementation RYDeckAccessibilityCard
- (BOOL)accessibilityActivate { [self.host openScene:self.scene]; return YES; }
- (BOOL)closeCard:(UIAccessibilityCustomAction *)action { [self.host closeScene:self.scene]; return YES; }
@end

@implementation RYSwitcherApplication
- (NSString *)displayName { return [RYCurrentSwitcher itemForBundle:self.bundleIdentifier].name ?: self.bundleIdentifier; }
- (NSString *)displayNameForSwitcher { return self.displayName; }
- (NSString *)displayNameForLocale:(id)locale { return self.displayName; }
@end

@interface RYSwitcherAppHost : RYRuntimeNull
@property (nonatomic, strong) id applicationController;
@property (nonatomic, strong) id sceneManager;
@end
@implementation RYSwitcherAppHost
@end

static id RYApplicationController(void) {
    static id controller;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        Class base = NSClassFromString(@"SBApplicationController");
        if (!base) return;
        Class cls = objc_allocateClassPair(base, "RYDeckApplicationController", 0);
        RYAdd(cls, @"applicationWithBundleIdentifier:", ^id(id object, NSString *bundle) {
            if (!bundle) return nil;
            RYNativeAppSwitcher *host = RYCurrentSwitcher;
            id application = host.applications[bundle];
            if (!application) {
                RYSwitcherApplication *created = [RYSwitcherApplication new];
                created.bundleIdentifier = bundle;
                host.applications[bundle] = created;
                application = created;
            }
            return application;
        }, "@24@0:8@16");
        RYAdd(cls, @"applicationForDisplayItem:", ^id(id object, id item) {
            return ((id (*)(id, SEL, id))objc_msgSend)(object,
                NSSelectorFromString(@"applicationWithBundleIdentifier:"), RYSend(item, @"bundleIdentifier"));
        }, "@24@0:8@16");
        for (NSString *name in @[@"allApplications", @"runningApplications", @"allInstalledApplications", @"allBundleIdentifiers"]) {
            RYAdd(cls, name, ^id(id object) { return @[]; }, "@16@0:8");
        }
        objc_registerClassPair(cls);
        controller = class_createInstance(cls, 0);
        // Keep this uninitialized service stand-in alive for the process lifetime.
        (void)CFBridgingRetain(controller);
        for (NSString *name in @[@"sharedInstance", @"sharedInstanceIfExists", @"sharedApplicationController"]) {
            Method method = class_getClassMethod(base, NSSelectorFromString(name));
            if (method) method_setImplementation(method, imp_implementationWithBlock(^id(id object) { return controller; }));
        }
        void **slot = dlsym(RTLD_DEFAULT, "SBApp");
        if (slot && !*slot) {
            RYSwitcherAppHost *host = [RYSwitcherAppHost new];
            host.applicationController = controller;
            host.sceneManager = [RYRuntimeChain new];
            *slot = (void *)CFBridgingRetain(host);
        }
    });
    return controller;
}

typedef id (*RYHeaderInitializer)(id __attribute__((ns_consumed)), SEL, id, id, id, BOOL, BOOL, BOOL) __attribute__((ns_returns_retained));
static id RYInitializeHeader(id __attribute__((ns_consumed)) object, SEL selector, id layout, id provider, id identity, BOOL titles, BOOL windowing, BOOL footer) __attribute__((ns_returns_retained));
static id __attribute__((ns_returns_retained)) RYInitializeHeader(id __attribute__((ns_consumed)) object, SEL selector, id layout, id provider, id identity, BOOL titles, BOOL windowing, BOOL footer) {
    SEL original = NSSelectorFromString([@"ry_original_" stringByAppendingString:NSStringFromSelector(selector)]);
    id result = ((RYHeaderInitializer)objc_msgSend)(object, original, layout, provider, identity, titles, windowing, footer);
    for (id item in RYSend(layout, @"allItems")) {
        RYNativeSwitcherItem *entry = [RYCurrentSwitcher itemForBundle:RYSend(item, @"bundleIdentifier")];
        if (entry.name.length) ((void (*)(id, SEL, id, id))objc_msgSend)(result,
            NSSelectorFromString(@"setCustomTitleText:forDisplayItem:"), entry.name, item);
    }
    return result;
}

static void RYInstallDeckHooks(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        // The app supplies its wallpaper; the system wallpaper service belongs
        // to SpringBoard's process and must not be started by a hosted deck.
        Method wallpaperService = class_getClassMethod(NSClassFromString(@"SBWallpaperController"), @selector(sharedInstance));
        if (wallpaperService) method_setImplementation(wallpaperService, imp_implementationWithBlock(^id(id object) { return nil; }));
        Class page = NSClassFromString(@"SBAppSwitcherPageView");
        SEL wallpaper = NSSelectorFromString(@"_createOrDestroyWallpaperOverlayView");
        Method wallpaperMethod = class_getInstanceMethod(page, wallpaper);
        if (wallpaperMethod) {
            method_setImplementation(wallpaperMethod, imp_implementationWithBlock(^(id object) {}));
        }
        Class fluid = NSClassFromString(@"SBFluidSwitcherViewController");
        SEL updateWallpaper = NSSelectorFromString(@"_updateWallpaperStyle");
        Method updateWallpaperMethod = class_getInstanceMethod(fluid, updateWallpaper);
        if (updateWallpaperMethod) {
            method_setImplementation(updateWallpaperMethod, imp_implementationWithBlock(^(id object) {}));
        }
        // Guest process activation belongs to ryC0. A hosted deck must not
        // acquire SpringBoard's process assertions for synthetic scene IDs.
        Method resignAssertions = class_getInstanceMethod(fluid, NSSelectorFromString(@"_updateResignActiveAssertions"));
        if (resignAssertions) method_setImplementation(resignAssertions, imp_implementationWithBlock(^(id object) {}));
        Class scene = NSClassFromString(@"SBWindowScene");
        if (scene) {
            static id chain; chain = [RYRuntimeChain new];
            static id icons; icons = [RYRuntimeNull new];
            RYAdd(UIWindowScene.class, @"layoutStateTransitionCoordinator", ^id(id object) { return chain; }, "@16@0:8");
            RYAdd(UIWindowScene.class, @"iconController", ^id(id object) { return icons; }, "@16@0:8");
            unsigned count = 0;
            Method *methods = class_copyMethodList(scene, &count);
            for (unsigned i = 0; i < count; i++) {
                SEL selector = method_getName(methods[i]);
                if (![UIWindowScene instancesRespondToSelector:selector]) {
                    class_addMethod(UIWindowScene.class, selector,
                        imp_implementationWithBlock(^id(id object) { return nil; }), method_getTypeEncoding(methods[i]));
                }
            }
            free(methods);
        }
        Class cache = NSClassFromString(@"SBAppSwitcherSnapshotImageCache");
        SEL load = NSSelectorFromString(@"_loadSnapshotForRequest:withDisplayItem:inAppLayout:");
        Method method = class_getInstanceMethod(cache, load);
        if (method) {
            IMP original = method_getImplementation(method);
            method_setImplementation(method, imp_implementationWithBlock(^(id object, id request, id item, id layout) {
                NSString *sceneID = RYSend(item, @"uniqueIdentifier");
                if (![sceneID hasPrefix:@"ryc0-switcher:"]) {
                    ((void (*)(id, SEL, id, id, id))original)(object, load, request, item, layout);
                    return;
                }
                Ivar ivar = class_getInstanceVariable(object_getClass(object), "_controlQueue");
                dispatch_queue_t queue = ivar ? object_getIvar(object, ivar) : nil;
                if (!queue) return;
                dispatch_async(dispatch_get_main_queue(), ^{
                    RYNativeAppSwitcher *host = RYCurrentSwitcher;
                    if (!host.itemsByScene[sceneID]) return;
                    host.snapshotCache = object;
                    NSUInteger generation = host.generation;
                    [host requestSnapshotForScene:sceneID completion:^(UIImage *image) {
                        if (host.generation != generation || !host.deck) return;
                        dispatch_async(queue, ^{
                            ((void (*)(id, SEL, id, id))objc_msgSend)(object,
                                NSSelectorFromString(@"_snapshotImage:finishedLoadingForRequest:"), image, request);
                        });
                    }];
                });
            }));
        }
        Class header = NSClassFromString(@"SBFluidSwitcherSpaceTitleItemController");
        for (NSString *name in @[
            @"initWithAppLayout:applicationSceneHandleProvider:displayIdentity:showCanvasTitles:isChamoisOrFlexibleWindowingEnabled:isFooterViewOfItemContainer:",
            @"initWithAppLayout:windowScene:applicationController:showCanvasTitles:isFlexibleWindowingEnabled:isFooterViewOfItemContainer:"
        ]) {
            SEL headerInit = NSSelectorFromString(name);
            Method headerInitMethod = class_getInstanceMethod(header, headerInit);
            if (!headerInitMethod) continue;
            SEL original = NSSelectorFromString([@"ry_original_" stringByAppendingString:name]);
            class_addMethod(header, original, method_getImplementation(headerInitMethod), method_getTypeEncoding(headerInitMethod));
            method_setImplementation(headerInitMethod, (IMP)RYInitializeHeader);
        }
        SEL maximum = NSSelectorFromString(@"setMaximumNumberOfVisibleIcons:");
        Method maximumMethod = class_getInstanceMethod(header, maximum);
        if (maximumMethod) {
            IMP original = method_getImplementation(maximumMethod);
            method_setImplementation(maximumMethod, imp_implementationWithBlock(^(id object, NSInteger count) {
                ((void (*)(id, SEL, NSInteger))original)(object, maximum, RYCurrentSwitcher ? MAX(1, count) : count);
            }));
        }
        SEL icon = NSSelectorFromString(@"_iconViewForDisplayItem:");
        Method iconMethod = class_getInstanceMethod(header, icon);
        if (iconMethod) {
            IMP original = method_getImplementation(iconMethod);
            method_setImplementation(iconMethod, imp_implementationWithBlock(^id(id object, id item) {
                RYNativeSwitcherItem *entry = [RYCurrentSwitcher itemForBundle:RYSend(item, @"bundleIdentifier")];
                if (!entry.icon) return ((id (*)(id, SEL, id))original)(object, icon, item);
                CGFloat size = 28;
                UIImageView *image = [[UIImageView alloc] initWithImage:entry.icon];
                image.frame = CGRectMake(0, 0, size, size);
                image.contentMode = UIViewContentModeScaleAspectFill;
                image.clipsToBounds = YES;
                image.layer.cornerCurve = kCACornerCurveContinuous;
                image.layer.cornerRadius = size * 0.225;
                return image;
            }));
        }
        for (NSString *name in @[@"SBSwitcherContentViewControllerDataSource", @"SBSwitcherContentViewControllerDelegate"]) {
            Protocol *protocol = NSProtocolFromString(name);
            if (protocol) class_addProtocol(RYNativeAppSwitcher.class, protocol);
        }
    });
}

@implementation RYNativeAppSwitcher

- (instancetype)init {
    if ((self = [super init])) {
        _items = @[];
        _layoutsByScene = [NSMutableDictionary dictionary];
        _itemsByScene = [NSMutableDictionary dictionary];
        _applications = [NSMutableDictionary dictionary];
        _closing = [NSMutableSet set];
        _cardAccessibility = [NSMutableDictionary dictionary];
        _pendingOffset = -1;
    }
    return self;
}

- (BOOL)prefersStatusBarHidden { return YES; }
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.clearColor;
    self.view.accessibilityIdentifier = @"ryc0.switcher.native";
    self.blurView = [[UIVisualEffectView alloc] initWithEffect:nil];
    self.blurView.frame = self.view.bounds;
    self.blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.blurView];
    self.dimView = [[UIView alloc] initWithFrame:self.view.bounds];
    self.dimView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.dimView.backgroundColor = UIColor.blackColor;
    self.dimView.alpha = 0;
    [self.view addSubview:self.dimView];
    __weak typeof(self) weakSelf = self;
    self.blurAnimator = [[UIViewPropertyAnimator alloc] initWithDuration:1 curve:UIViewAnimationCurveLinear animations:^{
        weakSelf.blurView.effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterialDark];
    }];
    self.blurAnimator.pausesOnCompletion = YES;
    self.blurAnimator.fractionComplete = 0.001;
    self.blurProgress = 0.001;
    UIButton *home = [UIButton buttonWithType:UIButtonTypeCustom];
    home.accessibilityLabel = [NSLocale.preferredLanguages.firstObject hasPrefix:@"ar"] ? @"الشاشة الرئيسية" : @"Home";
    home.accessibilityIdentifier = @"ryc0.switcher.home";
    home.frame = CGRectMake((self.view.bounds.size.width - 180) / 2, self.view.bounds.size.height - 44, 180, 44);
    home.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    [home addTarget:self action:@selector(backgroundTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:home];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (self.started) return;
    self.started = YES;
    RYCurrentSwitcher = self;
    @try {
        LCLoadSpringBoardFramework();
        RYInstallDeckHooks();
        [self refreshItems];
        id root = [NSClassFromString(@"SBFullScreenFluidSwitcherRootSwitcherModifier") new];
        id personality = [(id<RYDeckConstructing>)[NSClassFromString(@"SBFluidSwitcherPersonality") alloc] initWithRootModifier:root];
        self.liveOverlayCoordinator = [RYLiveOverlayCoordinator new];
        id controller = RYApplicationController();
        Class cls = NSClassFromString(@"SBDeckSwitcherViewController");
        SEL initializer = NSSelectorFromString(@"initWithPersonality:liveContentOverlayCoordinator:dataSource:delegate:applicationController:debugName:");
        id deck;
        if ([cls instancesRespondToSelector:initializer]) {
            deck = [(id<RYDeckConstructing>)[cls alloc] initWithPersonality:personality liveContentOverlayCoordinator:self.liveOverlayCoordinator dataSource:self delegate:self applicationController:controller debugName:@"ryC0"];
        } else {
            initializer = NSSelectorFromString(@"initWithPersonality:liveContentOverlayCoordinator:dataSource:delegate:debugName:");
            deck = [(id<RYDeckConstructing>)[cls alloc] initWithPersonality:personality liveContentOverlayCoordinator:self.liveOverlayCoordinator dataSource:self delegate:self debugName:@"ryC0"];
        }
        if (![deck isKindOfClass:UIViewController.class]) @throw [NSException exceptionWithName:@"RYDeckUnavailable" reason:@"The system app switcher is unavailable." userInfo:nil];
        self.deck = deck;
        self.usesNativeDeck = YES;
        [self addChildViewController:self.deck];
        self.deck.view.frame = self.view.bounds;
        self.deck.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        self.deck.view.backgroundColor = UIColor.clearColor;
        [self.view addSubview:self.deck.view];
        [self.deck didMoveToParentViewController:self];
        RYSend(self.deck, @"noteAppLayoutsDidChange");
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(backgroundTapped)];
        tap.delegate = self;
        tap.cancelsTouchesInView = NO;
        [self.view addGestureRecognizer:tap];
        for (UIView *view in self.view.subviews) if ([view.accessibilityIdentifier isEqualToString:@"ryc0.switcher.home"]) [self.view bringSubviewToFront:view];
        [self.deck.view layoutIfNeeded];
        self.observedScroll = RYFindDeck(self.deck.view);
        [self.observedScroll addObserver:self forKeyPath:@"contentOffset" options:NSKeyValueObservingOptionNew context:RYDeckOffsetContext];
        NSString *scene = self.entryIdentifier ? [@"ryc0-switcher:" stringByAppendingString:self.entryIdentifier] : nil;
        self.leavingLayout = scene ? self.layoutsByScene[scene] : nil;
        [self transitionFrom:self.leavingLayout ? 3 : 1 to:2 animated:!UIAccessibilityIsReduceMotionEnabled() completion:^(BOOL finished) {
            self.leavingLayout = nil;
            [self updateAccessibility];
        }];
        [self updateAccessibility];
    } @catch (NSException *error) {
        NSLog(@"[ryC0 switcher] %@: %@", error.name, error.reason);
        self.usesNativeDeck = NO;
        UILabel *message = [[UILabel alloc] initWithFrame:self.view.bounds];
        message.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        message.numberOfLines = 0;
        message.textAlignment = NSTextAlignmentCenter;
        message.textColor = UIColor.whiteColor;
        message.text = [NSLocale.preferredLanguages.firstObject hasPrefix:@"ar"]
            ? @"تعذر فتح مبدّل التطبيقات الأصلي على إصدار النظام هذا."
            : @"The system app switcher could not open on this iOS version.";
        message.accessibilityIdentifier = @"ryc0.switcher.error";
        [self.view insertSubview:message belowSubview:self.view.subviews.lastObject];
    }
}

- (RYNativeSwitcherItem *)itemForBundle:(NSString *)bundle {
    for (RYNativeSwitcherItem *item in self.items) if ([item.bundleIdentifier isEqualToString:bundle]) return item;
    return nil;
}
- (void)requestSnapshotForScene:(NSString *)scene completion:(void (^)(UIImage *))completion {
    completion(self.itemsByScene[scene].snapshot);
}

- (void)refreshItems {
    // Recency changes as the guest starts. Keep the selected layout stable
    // until its native expansion has handed over to that guest.
    if (self.exiting) return;
    if (!NSClassFromString(@"SBDisplayItem")) return;
    NSMutableArray *layouts = [NSMutableArray array];
    NSMutableArray *changedImages = [NSMutableArray array];
    NSMutableDictionary *entries = [NSMutableDictionary dictionary];
    for (RYNativeSwitcherItem *item in self.items) {
        NSString *scene = [@"ryc0-switcher:" stringByAppendingString:item.identifier];
        if ([self.closing containsObject:scene]) continue;
        entries[scene] = item;
        RYNativeSwitcherItem *previous = self.itemsByScene[scene];
        if (previous && (previous.snapshot != item.snapshot || previous.icon != item.icon)) [changedImages addObject:scene];
        id layout = self.layoutsByScene[scene];
        if (!layout) {
            id displayItem = ((id (*)(id, SEL, id, id))objc_msgSend)(NSClassFromString(@"SBDisplayItem"),
                NSSelectorFromString(@"applicationDisplayItemWithBundleIdentifier:sceneIdentifier:"), item.bundleIdentifier, scene);
            Class cls = NSClassFromString(@"SBAppLayout");
            SEL init = NSSelectorFromString(@"initWithItemsForLayoutRoles:environment:preferredDisplayOrdinal:");
            if ([cls instancesRespondToSelector:init]) {
                layout = [(id<RYDeckConstructing>)[cls alloc] initWithItemsForLayoutRoles:@{@1:displayItem} environment:1 preferredDisplayOrdinal:0];
            } else {
                init = NSSelectorFromString(@"initWithItemsForLayoutRoles:configuration:environment:preferredDisplayOrdinal:");
                layout = [(id<RYDeckConstructing>)[cls alloc] initWithItemsForLayoutRoles:@{@1:displayItem} configuration:1 environment:1 preferredDisplayOrdinal:0];
            }
            if (layout) self.layoutsByScene[scene] = layout;
        }
        if (layout) [layouts addObject:layout];
    }
    BOOL changed = ![layouts isEqualToArray:self.appLayouts];
    self.appLayouts = layouts;
    self.itemsByScene = entries;
    if (changed && self.deck) RYSend(self.deck, @"noteAppLayoutsDidChange");
    // Capture the cache from its snapshot request hook. Scanning arbitrary
    // system ivars can retain non-owning or stale pointers on device builds.
    id cache = self.snapshotCache;
    for (NSString *scene in changedImages) {
        for (id item in RYSend(self.layoutsByScene[scene], @"allItems")) {
            SEL reload = NSSelectorFromString(@"reloadSnapshotForDisplayItem:");
            if ([cache respondsToSelector:reload]) ((void (*)(id, SEL, id))objc_msgSend)(cache, reload, item);
        }
    }
    if (self.deck) [self updateAccessibility];
}

- (void)collectFrames:(UIView *)view into:(NSMutableDictionary *)frames {
    if ([NSStringFromClass(view.class) isEqualToString:@"SBReusableSnapshotItemContainer"]) {
        id layout = RYGet(view, @"appLayout");
        for (id item in RYSend(layout, @"allItems")) {
            NSString *scene = RYSend(item, @"uniqueIdentifier");
            RYNativeSwitcherItem *entry = self.itemsByScene[scene];
            if (entry && ![self.closing containsObject:scene]) {
                CGRect frame = [view convertRect:view.bounds toView:self.view];
                if (!CGRectIsEmpty(CGRectIntersection(frame, self.view.bounds))) frames[entry.identifier] = [NSValue valueWithCGRect:frame];
            }
        }
        return;
    }
    for (UIView *child in view.subviews) [self collectFrames:child into:frames];
}
- (NSDictionary<NSString *, NSValue *> *)cardFrames {
    NSMutableDictionary *frames = [NSMutableDictionary dictionary];
    if (self.deck.isViewLoaded) [self collectFrames:self.deck.view into:frames];
    return frames;
}
- (NSString *)focusedIdentifier {
    __block NSString *focused;
    __block CGFloat best = 0;
    [self.cardFrames enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSValue *value, BOOL *stop) {
        CGRect visible = CGRectIntersection(value.CGRectValue, self.view.bounds);
        CGFloat area = visible.size.width * visible.size.height;
        if (area > best) { best = area; focused = key; }
    }];
    return focused;
}
- (void)updateAccessibility {
    NSDictionary *frames = self.cardFrames;
    NSString *focused = self.focusedIdentifier;
    NSMutableArray *elements = [NSMutableArray array];
    for (RYNativeSwitcherItem *item in self.items) {
        NSValue *value = frames[item.identifier];
        if (!value) continue;
        RYDeckAccessibilityCard *card = (id)self.cardAccessibility[item.identifier];
        if (!card) {
            card = [[RYDeckAccessibilityCard alloc] initWithAccessibilityContainer:self.deck.view];
            card.host = self;
            card.scene = [@"ryc0-switcher:" stringByAppendingString:item.identifier];
            card.accessibilityIdentifier = @"ryc0.switcher.card";
            NSString *verb = [NSLocale.preferredLanguages.firstObject hasPrefix:@"ar"] ? @"إغلاق" : @"Close";
            card.accessibilityCustomActions = @[[[UIAccessibilityCustomAction alloc] initWithName:[NSString stringWithFormat:@"%@ %@", verb, item.name] target:card selector:@selector(closeCard:)]];
            self.cardAccessibility[item.identifier] = card;
        }
        card.accessibilityLabel = item.name;
        card.accessibilityValue = [NSString stringWithFormat:@"%lu / %lu", (unsigned long)[self.items indexOfObject:item] + 1, (unsigned long)self.appLayouts.count];
        card.accessibilityTraits = UIAccessibilityTraitButton | ([focused isEqualToString:item.identifier] ? UIAccessibilityTraitSelected : 0);
        card.accessibilityFrameInContainerSpace = CGRectIntersection(value.CGRectValue, self.view.bounds);
        [elements addObject:card];
    }
    self.deck.view.accessibilityElements = elements;
}
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (context == RYDeckOffsetContext) [self updateAccessibility];
    else [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}

- (id)layoutStateWithMode:(NSInteger)mode {
    Class cls = NSClassFromString(@"SBMainDisplayLayoutState");
    return [(id<RYDeckConstructing>)[cls alloc] _initWithLayoutElements:[NSSet set] interfaceOrientation:1 interfaceOrientationByLayoutElement:@{} spaceConfiguration:0 floatingConfiguration:0 unlockedEnvironmentMode:mode floatingSwitcherVisible:NO centerConfiguration:0 centerEntityModal:NO peekConfiguration:0 bundleIDShowingAppExpose:nil windowPickerRole:0 displayOrdinal:0 isDisplayExternal:NO];
}

- (void)transitionFrom:(NSInteger)from to:(NSInteger)to animated:(BOOL)animated completion:(RYCompletion)completion {
    Class requestClass = NSClassFromString(@"SBMainWorkspaceTransitionRequest");
    UIScreen *screen = self.view.window.windowScene.screen ?: UIScreen.mainScreen;
    id configuration = RYSend(screen, @"displayConfiguration");
    // The transition context derives its display identity from this request.
    // Supply the display without initializing SpringBoard's workspace service.
    id request = [requestClass alloc];
    RYSet(request, @"displayConfiguration", configuration);
    id context = [NSClassFromString(@"SBWorkspaceApplicationSceneTransitionContext") new];
    RYSet(context, @"layoutState", [self layoutStateWithMode:to]);
    RYSet(context, @"previousLayoutState", [self layoutStateWithMode:from]);
    RYSet(context, @"request", request);
    RYSet(context, @"requestedUnlockedEnvironmentMode", @(to));
    ((void (*)(id, SEL, id, BOOL, id))objc_msgSend)(self.deck,
        NSSelectorFromString(@"performTransitionWithContext:animated:completion:"), context, animated, completion);
}

- (NSArray *)appLayoutsForSwitcherContentController:(id)controller { return self.appLayouts ?: @[]; }
- (NSInteger)activeInterfaceOrientationForSwitcherContentController:(id)controller { return 1; }
- (NSInteger)switcherInterfaceOrientationForSwitcherContentController:(id)controller { return 1; }
- (CGRect)switcherContentController:(id)controller frameForItemWithRole:(NSInteger)role inMainAppLayout:(id)layout interfaceOrientation:(NSInteger)orientation { return self.view.bounds; }
- (NSInteger)nextDisplayItemInteractionTimeForSwitcherContentController:(id)controller { return 0; }
- (UIWindowScene *)windowSceneForSwitcherContentController:(id)controller { return self.view.window.windowScene; }
- (id)displayItemLayoutAttributesProvider {
    if (!self.layoutProvider) self.layoutProvider = [NSClassFromString(@"SBDisplayItemLayoutAttributesProvider") new];
    return self.layoutProvider;
}
- (id)switcherContentController:(id)controller transitionEventForContext:(id)context identifier:(id)identifier phase:(NSUInteger)phase animated:(BOOL)animated {
    id event = [(id<RYDeckConstructing>)[NSClassFromString(@"SBTransitionSwitcherModifierEvent") alloc] initWithTransitionID:identifier phase:phase animated:animated];
    RYSet(event, @"fromEnvironmentMode", RYGet(RYGet(context, @"previousLayoutState"), @"unlockedEnvironmentMode") ?: @1);
    RYSet(event, @"toEnvironmentMode", RYGet(RYGet(context, @"layoutState"), @"unlockedEnvironmentMode") ?: @2);
    RYSet(event, @"fromInterfaceOrientation", @1);
    RYSet(event, @"toInterfaceOrientation", @1);
    if (self.leavingLayout) RYSet(event, @"fromAppLayout", self.leavingLayout);
    if (self.activatingLayout) {
        RYSet(event, @"toAppLayout", self.activatingLayout);
        RYSet(event, @"activatingAppLayout", self.activatingLayout);
    }
    return event;
}
- (BOOL)switcherContentController:(id)controller supportsTitleItemsForAppLayout:(id)layout { return YES; }
- (BOOL)switcherContentController:(id)controller supportsKillingOfAppLayout:(id)layout { return YES; }
- (void)switcherContentController:(id)controller deletedDisplayItem:(id)item inAppLayout:(id)layout forReason:(NSInteger)reason { [self closeScene:RYSend(item, @"uniqueIdentifier")]; }
- (void)switcherContentController:(id)controller performTransitionWithRequest:(id)request gestureInitiated:(BOOL)gesture {
    id item = RYSend(request, @"activatingDisplayItem");
    if (!item) item = RYSend(RYSend(RYSend(request, @"appLayout"), @"allItems"), @"firstObject");
    NSString *scene = RYSend(item, @"uniqueIdentifier");
    if (scene) [self openScene:scene]; else [self backgroundTapped];
}

- (void)setBlurProgress:(double)progress mode:(NSInteger)mode completion:(RYCompletion)completion {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!self.deck) { if (completion) completion(YES); return; }
        double target = MIN(1, MAX(0.001, progress));
        if (fabs(target - self.blurTo) < 0.0001) { if (completion) completion(YES); return; }
        [self.blurLink invalidate];
        self.blurLink = nil;
        if (self.blurAnimator.state != UIViewAnimatingStateActive) {
            self.blurView.effect = nil;
            __weak typeof(self) weakSelf = self;
            self.blurAnimator = [[UIViewPropertyAnimator alloc] initWithDuration:1 curve:UIViewAnimationCurveLinear animations:^{
                weakSelf.blurView.effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterialDark];
            }];
            self.blurAnimator.pausesOnCompletion = YES;
            self.blurAnimator.fractionComplete = self.blurProgress;
        }
        self.blurTo = target;
        if (mode && !UIAccessibilityIsReduceMotionEnabled()) {
            self.blurFrom = self.blurProgress;
            self.blurStart = CACurrentMediaTime();
            self.blurCompletion = completion;
            self.blurLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(blurTick:)];
            [self.blurLink addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
        } else {
            self.blurAnimator.fractionComplete = target;
            self.blurProgress = target;
            [self.blurAnimator stopAnimation:NO];
            [self.blurAnimator finishAnimationAtPosition:UIViewAnimatingPositionCurrent];
            if (completion) completion(YES);
        }
    });
}
- (void)blurTick:(CADisplayLink *)link {
    double time = MIN(1, (CACurrentMediaTime() - self.blurStart) / 0.7);
    self.blurProgress = self.blurFrom + (1 - pow(1 - time, 3)) * (self.blurTo - self.blurFrom);
    self.blurAnimator.fractionComplete = self.blurProgress;
    if (time >= 1) {
        [self.blurLink invalidate]; self.blurLink = nil;
        [self.blurAnimator stopAnimation:NO];
        [self.blurAnimator finishAnimationAtPosition:UIViewAnimatingPositionCurrent];
        RYCompletion completion = self.blurCompletion; self.blurCompletion = nil;
        if (completion) completion(YES);
    }
}
- (void)switcherContentController:(id)controller setHomeScreenBackdropBlurProgress:(double)progress withAnimationMode:(NSInteger)mode completion:(RYCompletion)completion { [self setBlurProgress:progress mode:mode completion:completion]; }
- (void)switcherContentController:(id)controller setHomeScreenDimmingAlpha:(double)alpha withSettings:(id)settings animationMode:(NSInteger)mode completion:(RYCompletion)completion {
    dispatch_async(dispatch_get_main_queue(), ^{
        [UIView animateWithDuration:mode && !UIAccessibilityIsReduceMotionEnabled() ? 0.7 : 0 animations:^{ self.dimView.alpha = alpha; } completion:completion];
    });
}
- (void)switcherContentController:(id)controller setHomeScreenScale:(double)scale withAnimationMode:(NSInteger)mode completion:(RYCompletion)completion { if (completion) completion(YES); }
- (void)switcherContentController:(id)controller setHomeScreenAlpha:(double)alpha withAnimationMode:(NSInteger)mode completion:(RYCompletion)completion { if (completion) completion(YES); }
- (void)switcherContentController:(id)controller setWallpaperScale:(double)scale withAnimationMode:(NSInteger)mode completion:(RYCompletion)completion { if (completion) completion(YES); }

- (void)openScene:(NSString *)scene {
    if (self.exiting) return;
    RYNativeSwitcherItem *item = self.itemsByScene[scene];
    if (!item) return;
    self.exiting = YES;
    self.activatingLayout = self.layoutsByScene[scene];
#if DEBUG
    NSLog(@"[ryC0 launch] %.3f native card selected", CACurrentMediaTime());
#endif
    // Start guest preparation during the native animation, rather than
    // serializing process startup after the card has filled the screen.
    if (self.openHandler) self.openHandler(item.identifier, self.view.bounds);
    __block BOOL completed = NO;
    void (^open)(BOOL) = ^(BOOL finished) {
        if (completed) return;
        completed = YES;
#if DEBUG
        NSLog(@"[ryC0 launch] %.3f native card expanded", CACurrentMediaTime());
#endif
        if (self.didFinishOpeningHandler) self.didFinishOpeningHandler();
    };
    [self transitionFrom:2 to:3 animated:!UIAccessibilityIsReduceMotionEnabled() completion:open];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1200 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{ open(YES); });
}
- (void)closeScene:(NSString *)scene {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!scene || [self.closing containsObject:scene]) return;
        RYNativeSwitcherItem *item = self.itemsByScene[scene];
        if (!item) return;
        [self.closing addObject:scene];
        id layout = self.layoutsByScene[scene];
        UIScrollView *scroll = RYFindDeck(self.deck.view);
        NSUInteger count = self.appLayouts.count;
        NSUInteger removed = [self.appLayouts indexOfObject:layout];
        CGFloat width = scroll.bounds.size.width;
        if (count > 1 && removed != NSNotFound && width >= 1) {
            NSInteger focused = MIN(count - 1, MAX(0, (NSInteger)count - 1 - lround(scroll.contentOffset.x / width)));
            NSInteger next = focused == removed ? MIN(removed, count - 2) : focused - (removed < focused);
            self.pendingOffset = width * (count - 2 - next);
            self.pendingContentWidth = width * (count - 1);
        }
        NSMutableArray *layouts = [self.appLayouts mutableCopy];
        [layouts removeObject:layout];
        self.appLayouts = layouts;
        [self.layoutsByScene removeObjectForKey:scene];
        RYSend(self.deck, @"noteAppLayoutsDidChange");
        if (self.closeHandler) self.closeHandler(item.identifier);
        self.clampDeadline = CACurrentMediaTime() + 1.2;
        if (!self.clampLink) {
            self.clampLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(clampTick:)];
            [self.clampLink addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
        }
        if (!layouts.count) dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 350 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{ if (!self.appLayouts.count) [self backgroundTapped]; });
    });
}
- (void)clampTick:(CADisplayLink *)link {
    UIScrollView *scroll = RYFindDeck(self.deck.view);
    if (self.pendingOffset >= 0 && fabs(scroll.contentSize.width - self.pendingContentWidth) < 1) {
        scroll.contentOffset = CGPointMake(self.pendingOffset, scroll.contentOffset.y);
        self.pendingOffset = -1;
    }
    CGFloat maxX = MAX(0, scroll.contentSize.width - scroll.bounds.size.width);
    if (scroll.contentOffset.x < -0.5 || scroll.contentOffset.x > maxX + 0.5) {
        scroll.contentOffset = CGPointMake(MIN(maxX, MAX(0, scroll.contentOffset.x)), scroll.contentOffset.y);
    }
    if (CACurrentMediaTime() > self.clampDeadline || !self.deck) { [self.clampLink invalidate]; self.clampLink = nil; }
    [self updateAccessibility];
}
- (void)backgroundTapped {
    if (!self.usesNativeDeck) { if (self.homeHandler) self.homeHandler(); return; }
    if (self.exiting) return;
    self.exiting = YES;
    [self transitionFrom:2 to:1 animated:!UIAccessibilityIsReduceMotionEnabled() completion:^(BOOL finished) {
        if (self.homeHandler) self.homeHandler();
    }];
}
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gesture shouldReceiveTouch:(UITouch *)touch {
    for (UIView *view = touch.view; view && view != self.view; view = view.superview) {
        NSString *name = NSStringFromClass(view.class);
        if ([name containsString:@"ItemContainer"] || [name containsString:@"PageView"] || [name containsString:@"Snapshot"] || [view isKindOfClass:UIControl.class]) return NO;
    }
    return YES;
}
- (void)invalidate {
    [self tearDownDeck];
}
- (void)tearDownDeck {
    self.exiting = YES;
    self.generation++;
    [self.observedScroll removeObserver:self forKeyPath:@"contentOffset" context:RYDeckOffsetContext];
    self.observedScroll = nil;
    [self.blurLink invalidate]; self.blurLink = nil;
    self.blurCompletion = nil;
    [self.clampLink invalidate]; self.clampLink = nil;
    if (self.blurAnimator.state == UIViewAnimatingStateActive) [self.blurAnimator stopAnimation:YES];
    self.deck.view.accessibilityElements = nil;
    [self.cardAccessibility removeAllObjects];
    // A system deck asserts during deallocation unless it has been invalidated.
    // Invalidate while its host and data source are still alive, then detach it.
    RYSend(self.deck, @"invalidate");
    [self.deck willMoveToParentViewController:nil];
    [self.deck.view removeFromSuperview];
    [self.deck removeFromParentViewController];
    self.deck = nil;
    self.snapshotCache = nil;
    self.usesNativeDeck = NO;
    if (RYCurrentSwitcher == self) RYCurrentSwitcher = nil;
}
- (void)dealloc {
    [_observedScroll removeObserver:self forKeyPath:@"contentOffset" context:RYDeckOffsetContext];
    [_blurLink invalidate]; [_clampLink invalidate];
    if (_blurAnimator.state == UIViewAnimatingStateActive) [_blurAnimator stopAnimation:YES];
    RYSend(_deck, @"invalidate");
}
@end

#import "LCHomeButtonViewController.h"
#import "LCHomeButtonPlacement.h"
#import "LCHomeButtonView.h"
#import "Localization.h"
#import "../../LiveContainer/utils.h"
#import <objc/message.h>

// The space between the button and the edges of the screen's safe area.
static const CGFloat LCHomeButtonEdgeMargin = 6;
// How long the button stays bright after a touch before it dims, and how
// bright it is then, like AssistiveTouch's idle opacity.
static const NSTimeInterval LCHomeButtonDimDelay = 3;
static const CGFloat LCHomeButtonDimmedAlpha = 0.4;
// How far a flung button carries on, in seconds of its speed when let go.
static const CGFloat LCHomeButtonFlingCarry = 0.12;

@interface LCHomeButtonViewController ()
@property (nonatomic) LCHomeButtonView *button;
@property (nonatomic) UIButton *homeHandle;
@property (nonatomic) UIButton *clockControl;
@property (nonatomic) LCHomeButtonPlacement *placement;
// The Home Screen and the outgoing guest snapshot during the handoff.
@property (nonatomic, nullable) UIView *cover;
@property (nonatomic) BOOL isDragging;
// Where the finger holds the button, from the button's center.
@property (nonatomic) CGPoint dragOffset;
// Counts touches, so a dimming planned before the last touch doesn't happen.
@property (nonatomic) NSUInteger dimmingGeneration;
@property (nonatomic, copy, nullable) dispatch_block_t pendingClockTap;
@property (nonatomic) UIImpactFeedbackGenerator *clockFeedback;
@end

@implementation LCHomeButtonViewController

- (void)loadView {
    UIView *view = [[UIView alloc] init];
    view.backgroundColor = UIColor.clearColor;
    self.view = view;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.placement = [LCHomeButtonPlacement savedPlacement];

    LCHomeButtonView *button = [[LCHomeButtonView alloc] initWithFrame:CGRectZero];
    [button addTarget:self action:@selector(buttonTouchedDown) forControlEvents:UIControlEventTouchDown];
    [button addTarget:self action:@selector(buttonPressed) forControlEvents:UIControlEventTouchUpInside];
    [button addTarget:self action:@selector(buttonLetGo) forControlEvents:UIControlEventTouchUpOutside | UIControlEventTouchCancel];
    [button addGestureRecognizer:[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(buttonDragged:)]];
    [button addGestureRecognizer:[[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(buttonHeld:)]];
    button.accessibilityCustomActions = @[
        [[UIAccessibilityCustomAction alloc] initWithName:@"ryc0.switcher.title".loc
                                                   target:self selector:@selector(accessibilityOpenSwitcher:)]
    ];
    button.hidden = self.homeControl != LCGuestHomeControlFloatingButton;
    [self.view addSubview:button];
    self.button = button;
    if (self.homeControl == LCGuestHomeControlFloatingButton) return;

    if (self.homeControl == LCGuestHomeControlClock) {
        self.clockFeedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
        UIButton *clock = [UIButton buttonWithType:UIButtonTypeCustom];
        clock.translatesAutoresizingMaskIntoConstraints = NO;
        clock.accessibilityLabel = @"ryc0.home.homeButton".loc;
        clock.accessibilityCustomActions = button.accessibilityCustomActions;
        [clock addTarget:self action:@selector(prepareClockFeedback) forControlEvents:UIControlEventTouchDown];
        [clock addTarget:self action:@selector(clockPressed) forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:clock];
        self.clockControl = clock;
        NSLayoutConstraint *safeTop = [clock.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor];
        safeTop.priority = UILayoutPriorityDefaultHigh;
        [NSLayoutConstraint activateConstraints:@[
            [clock.topAnchor constraintEqualToAnchor:self.view.topAnchor],
            [clock.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
            [clock.widthAnchor constraintEqualToConstant:112],
            [clock.heightAnchor constraintGreaterThanOrEqualToConstant:44],
            safeTop
        ]];
        return;
    }

    UIButton *handle = [UIButton buttonWithType:UIButtonTypeCustom];
    handle.translatesAutoresizingMaskIntoConstraints = NO;
    handle.backgroundColor = [UIColor.blackColor colorWithAlphaComponent:0.45];
    handle.layer.cornerRadius = 15;
    handle.accessibilityLabel = @"ryc0.home.homeButton".loc;
    [handle addTarget:self action:@selector(buttonPressed) forControlEvents:UIControlEventTouchUpInside];
    [handle addGestureRecognizer:[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleSwiped:)]];
    [handle addGestureRecognizer:[[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(buttonHeld:)]];
    handle.accessibilityCustomActions = button.accessibilityCustomActions;
    UIView *bar = [[UIView alloc] init];
    bar.translatesAutoresizingMaskIntoConstraints = NO;
    bar.backgroundColor = [UIColor.whiteColor colorWithAlphaComponent:0.92];
    bar.layer.cornerRadius = 2.5;
    bar.userInteractionEnabled = NO;
    [handle addSubview:bar];
    [self.view addSubview:handle];
    self.homeHandle = handle;
    NSLayoutConstraint *safeBottom = [handle.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-5];
    safeBottom.priority = UILayoutPriorityDefaultHigh;
    [NSLayoutConstraint activateConstraints:@[
        [handle.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [handle.bottomAnchor constraintLessThanOrEqualToAnchor:self.view.bottomAnchor constant:-27],
        safeBottom,
        [handle.widthAnchor constraintEqualToConstant:84],
        [handle.heightAnchor constraintEqualToConstant:34],
        [bar.centerXAnchor constraintEqualToAnchor:handle.centerXAnchor],
        [bar.centerYAnchor constraintEqualToAnchor:handle.centerYAnchor],
        [bar.widthAnchor constraintEqualToConstant:42],
        [bar.heightAnchor constraintEqualToConstant:5]
    ]];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self dimSoon];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    if (!self.isDragging) {
        self.button.center = [self.placement centerInArea:self.restingArea];
    }
}

// The area the button's center rests in: the safe area, less the button's
// radius and a small margin.
- (CGRect)restingArea {
    CGRect safeArea = UIEdgeInsetsInsetRect(self.view.bounds, self.view.safeAreaInsets);
    CGFloat inset = LCHomeButtonView.diameter / 2 + LCHomeButtonEdgeMargin;
    CGRect area = CGRectInset(safeArea, inset, inset);
    if (CGRectIsNull(area) || CGRectIsEmpty(area)) {
        return CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 0, 0);
    }
    return area;
}

#pragma mark Touches

- (void)buttonTouchedDown {
    [self brighten];
}

- (void)buttonLetGo {
    [self dimSoon];
}

- (void)buttonPressed {
    [self dimSoon];
    [[[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight] impactOccurred];
    if (self.pressHandler) {
        self.pressHandler();
    }
}

- (void)prepareClockFeedback {
    [self.clockFeedback prepare];
}

- (void)clockPressed {
    [self.clockFeedback impactOccurred];
    [self.clockFeedback prepare];
    if (self.pendingClockTap) {
        dispatch_block_cancel(self.pendingClockTap);
        self.pendingClockTap = nil;
        if (self.switcherHandler) self.switcherHandler();
        return;
    }
    __weak typeof(self) weakSelf = self;
    dispatch_block_t singleTap = dispatch_block_create(0, ^{
        typeof(self) self = weakSelf;
        self.pendingClockTap = nil;
        if (self.pressHandler) self.pressHandler();
    });
    self.pendingClockTap = singleTap;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 280 * NSEC_PER_MSEC), dispatch_get_main_queue(), singleTap);
}

- (void)handleSwiped:(UIPanGestureRecognizer *)gesture {
    CGPoint movement = [gesture translationInView:self.view];
    if (gesture.state == UIGestureRecognizerStateEnded && -movement.y > MAX(28, fabs(movement.x))) {
        [self buttonPressed];
    }
}

- (void)buttonHeld:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan) {
        [self accessibilityOpenSwitcher:nil];
    }
}

- (BOOL)accessibilityOpenSwitcher:(nullable UIAccessibilityCustomAction *)action {
    if (!self.switcherHandler) return NO;
    if (self.pendingClockTap) dispatch_block_cancel(self.pendingClockTap);
    self.pendingClockTap = nil;
    [[[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium] impactOccurred];
    self.switcherHandler();
    return YES;
}

// Follows the finger, then lets the button settle against the edge nearest
// to where it was going when let go.
- (void)buttonDragged:(UIPanGestureRecognizer *)pan {
    CGPoint finger = [pan locationInView:self.view];
    switch (pan.state) {
        case UIGestureRecognizerStateBegan:
            self.isDragging = YES;
            self.dragOffset = CGPointMake(self.button.center.x - finger.x, self.button.center.y - finger.y);
            [self brighten];
            break;
        case UIGestureRecognizerStateChanged: {
            CGFloat radius = LCHomeButtonView.diameter / 2;
            CGRect bounds = CGRectInset(self.view.bounds, radius, radius);
            CGFloat x = finger.x + self.dragOffset.x;
            CGFloat y = finger.y + self.dragOffset.y;
            self.button.center = CGPointMake(MIN(MAX(x, CGRectGetMinX(bounds)), CGRectGetMaxX(bounds)),
                                             MIN(MAX(y, CGRectGetMinY(bounds)), CGRectGetMaxY(bounds)));
            break;
        }
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled:
        case UIGestureRecognizerStateFailed: {
            self.isDragging = NO;
            CGPoint velocity = [pan velocityInView:self.view];
            CGPoint heading = CGPointMake(self.button.center.x + velocity.x * LCHomeButtonFlingCarry,
                                          self.button.center.y + velocity.y * LCHomeButtonFlingCarry);
            CGRect area = self.restingArea;
            self.placement = [LCHomeButtonPlacement placementNearestToPoint:heading inArea:area];
            [self.placement save];
            CGPoint target = [self.placement centerInArea:area];
            [UIView animateWithDuration:0.45
                                  delay:0
                 usingSpringWithDamping:0.78
                  initialSpringVelocity:0
                                options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                             animations:^{
                self.button.center = target;
            } completion:nil];
            [self dimSoon];
            break;
        }
        default:
            break;
    }
}

#pragma mark Dimming

- (void)brighten {
    self.dimmingGeneration += 1;
    [UIView animateWithDuration:0.15
                          delay:0
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.button.alpha = 1;
    } completion:nil];
}

- (void)dimSoon {
    NSUInteger generation = ++self.dimmingGeneration;
    __weak LCHomeButtonViewController *weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(LCHomeButtonDimDelay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        LCHomeButtonViewController *controller = weakSelf;
        if (!controller || controller.dimmingGeneration != generation || controller.isDragging || controller.button.isTracking) {
            return;
        }
        [UIView animateWithDuration:0.5
                              delay:0
                            options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                         animations:^{
            controller.button.alpha = LCHomeButtonDimmedAlpha;
        } completion:nil];
    });
}

#pragma mark Going back to ryC0

- (UIImage *)captureGuestPreview {
    UIWindow *guest = self.appViewController.viewIfLoaded.window;
    if (!guest || CGRectIsEmpty(guest.bounds)) return nil;
    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat defaultFormat];
    format.scale = MIN(1, 520.0 / MAX(guest.bounds.size.width, guest.bounds.size.height));
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithBounds:guest.bounds format:format];
    __block BOOL drawn = NO;
    UIImage *image = [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
        drawn = [guest drawViewHierarchyInRect:guest.bounds afterScreenUpdates:NO];
    }];
    return drawn ? image : nil;
}

- (void)animateReturnWithBackdrop:(UIImage *)backdrop {
    self.dimmingGeneration += 1;
    self.button.alpha = 0;
    self.homeHandle.alpha = 0;
    self.clockControl.userInteractionEnabled = NO;
    [self.cover removeFromSuperview];
    NSUserDefaults *defaults = NSUserDefaults.lcUserDefaults;
    NSString *storedFrame = [defaults stringForKey:@"ryc0.homeReturnIcon"];
    [defaults removeObjectForKey:@"ryc0.homeReturnIcon"];
    CGRect normalized = storedFrame ? CGRectFromString(storedFrame) : CGRectZero;
    if (!backdrop) return;
    UIWindow *guest = self.appViewController.viewIfLoaded.window;
    UIView *snapshot = [guest snapshotViewAfterScreenUpdates:NO];
    if (!snapshot) return;

    UIImageView *cover = [[UIImageView alloc] initWithImage:backdrop];
    cover.frame = self.view.bounds;
    cover.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    cover.contentMode = UIViewContentModeScaleAspectFill;
    cover.clipsToBounds = YES;
    cover.userInteractionEnabled = YES;
    snapshot.frame = cover.bounds;
    UIView *viewport = [[UIView alloc] initWithFrame:cover.bounds];
    viewport.layer.cornerCurve = kCACornerCurveContinuous;
    viewport.clipsToBounds = YES;
    [viewport addSubview:snapshot];
    [cover addSubview:viewport];
    [self.view addSubview:cover];
    self.cover = cover;
    CGSize size = cover.bounds.size;
    CGRect icon = CGRectMake(normalized.origin.x * size.width, normalized.origin.y * size.height,
                             normalized.size.width * size.width, normalized.size.height * size.height);
    if (UIAccessibilityIsReduceMotionEnabled() || CGRectIsEmpty(icon) || !CGRectContainsRect(cover.bounds, icon)) {
        [UIView animateWithDuration:0.16 animations:^{ snapshot.alpha = 0; }];
        return;
    }

    CGFloat scale = MAX(icon.size.width / size.width, icon.size.height / size.height);
    [UIView animateWithDuration:0.30 delay:0 usingSpringWithDamping:0.88 initialSpringVelocity:0
                         options:UIViewAnimationOptionBeginFromCurrentState animations:^{
        viewport.bounds = CGRectMake(0, 0, icon.size.width, icon.size.height);
        viewport.center = CGPointMake(CGRectGetMidX(icon), CGRectGetMidY(icon));
        viewport.layer.cornerRadius = icon.size.width * 0.225;
        snapshot.center = CGPointMake(CGRectGetMidX(viewport.bounds), CGRectGetMidY(viewport.bounds));
        snapshot.transform = CGAffineTransformMakeScale(scale, scale);
    } completion:nil];
    [UIView animateWithDuration:0.16 delay:0.14 options:UIViewAnimationOptionBeginFromCurrentState
                     animations:^{ snapshot.alpha = 0; } completion:nil];
}

- (void)fadeBackIn {
    UIView *cover = self.cover;
    self.cover = nil;
    self.clockControl.userInteractionEnabled = YES;
    [UIView animateWithDuration:0.25 animations:^{
        cover.alpha = 0;
        self.button.alpha = 1;
        self.homeHandle.alpha = 1;
    } completion:^(BOOL finished) {
        [cover removeFromSuperview];
    }];
    [self dimSoon];
}

#pragma mark Leaving the screen to the app

// The view controller of the app's main window that UIKit asks about the
// screen: the key window's (or else the first ordinary window's) root view
// controller, or the one it presents over everything.
- (nullable UIViewController *)appViewController {
    UIWindow *ownWindow = self.viewIfLoaded.window;
    UIWindow *appWindow = nil;
    for (UIWindow *window in ownWindow.windowScene.windows) {
        if (window == ownWindow || window.hidden || !window.rootViewController) {
            continue;
        }
        if (window.isKeyWindow) {
            appWindow = window;
            break;
        }
        if (!appWindow && window.windowLevel <= UIWindowLevelNormal) {
            appWindow = window;
        }
    }
    UIViewController *controller = appWindow.rootViewController;
    while (controller.presentedViewController && !controller.presentedViewController.isBeingDismissed) {
        controller = controller.presentedViewController;
    }
    return controller == self ? nil : controller;
}

// The view controller that decides the app's orientations, which UIKit finds
// with a private method of the root view controller when it has it.
- (nullable UIViewController *)appOrientationViewController {
    UIWindow *ownWindow = self.viewIfLoaded.window;
    UIViewController *controller = nil;
    for (UIWindow *window in ownWindow.windowScene.windows) {
        if (window != ownWindow && !window.hidden && window.isKeyWindow) {
            controller = window.rootViewController;
            break;
        }
    }
    if (!controller) {
        return self.appViewController;
    }
    SEL decider = NSSelectorFromString(@"_viewControllerForSupportedInterfaceOrientations");
    if ([controller respondsToSelector:decider]) {
        id found = ((id (*)(id, SEL))objc_msgSend)(controller, decider);
        if ([found isKindOfClass:UIViewController.class]) {
            controller = found;
        }
    }
    return controller == self ? nil : controller;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    UIInterfaceOrientationMask orientations = 0;
    @try {
        orientations = self.appOrientationViewController.supportedInterfaceOrientations;
    } @catch (NSException *exception) {
        orientations = 0;
    }
    // UIKit rejects an empty set of orientations.
    return orientations ?: UIInterfaceOrientationMaskAll;
}

- (UIViewController *)childViewControllerForStatusBarStyle {
    return self.appViewController;
}

- (UIViewController *)childViewControllerForStatusBarHidden {
    return self.appViewController;
}

- (UIViewController *)childViewControllerForHomeIndicatorAutoHidden {
    return self.appViewController;
}

- (UIViewController *)childViewControllerForScreenEdgesDeferringSystemGestures {
    return self.appViewController;
}

@end

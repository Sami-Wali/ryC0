#import "LCHomeButtonView.h"
#import "Localization.h"

// The SDK version the app counts as linked against, which can be spoofed.
// iOS gives an app Liquid Glass from the iOS 26 SDK (0x1a0000) on.
extern uint32_t dyld_get_program_sdk_version(void);

static const CGFloat LCHomeButtonDiameter = 52;
// The rings from the outside in, as HomeDesign.homeButtonRings: each one's
// width and how white it is.
static const CGFloat LCHomeButtonRings[][2] = {{40, 0.12}, {32, 0.22}, {24, 0.92}};
// How dark the glass is tinted, as HomeDesign.homeButtonTint.
static const CGFloat LCHomeButtonTint = 0.32;
// How white the rim is where Liquid Glass isn't used, as HomeDesign.homeButtonRim.
static const CGFloat LCHomeButtonRim = 0.22;
// How much the button shrinks while pressed, as HomeDesign.homeButtonPressedScale.
static const CGFloat LCHomeButtonPressedScale = 0.9;

@interface LCHomeButtonView ()
// The glass and the rings, which shrink while the button is pressed. The
// button itself is left alone, since the controller dims it when idle.
@property (nonatomic) UIView *face;
@end

@implementation LCHomeButtonView

+ (CGFloat)diameter {
    return LCHomeButtonDiameter;
}

// Whether the app runs with Liquid Glass: on iOS 26 or later, linked against
// the iOS 26 SDK or later (or spoofing it), and not asking for the earlier design.
+ (BOOL)appUsesLiquidGlass {
    if (@available(iOS 26.0, *)) {
        if (dyld_get_program_sdk_version() < 0x1a0000) {
            return NO;
        }
        id compatibility = NSBundle.mainBundle.infoDictionary[@"UIDesignRequiresCompatibility"];
        if ([compatibility respondsToSelector:@selector(boolValue)] && [compatibility boolValue]) {
            return NO;
        }
        return YES;
    }
    return NO;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:CGRectMake(frame.origin.x, frame.origin.y, LCHomeButtonDiameter, LCHomeButtonDiameter)];
    if (self) {
        _face = [[UIView alloc] initWithFrame:self.bounds];
        _face.userInteractionEnabled = NO;
        [self addSubview:_face];
        [self addGlass];
        [self addRings];

        self.isAccessibilityElement = YES;
        self.accessibilityLabel = @"ryc0.home.homeButton".loc;
        self.accessibilityHint = @"ryc0.guestTweak.homeButtonHint".loc;
        self.accessibilityTraits = UIAccessibilityTraitButton;
    }
    return self;
}

- (void)addGlass {
    UIVisualEffect *effect = nil;
    if (@available(iOS 26.0, *)) {
        if (LCHomeButtonView.appUsesLiquidGlass) {
            UIGlassEffect *glass = [UIGlassEffect effectWithStyle:UIGlassEffectStyleRegular];
            glass.tintColor = [UIColor colorWithWhite:0 alpha:LCHomeButtonTint];
            effect = glass;
        }
    }

    UIVisualEffectView *glassView = [[UIVisualEffectView alloc] initWithEffect:effect];
    glassView.frame = self.face.bounds;
    glassView.userInteractionEnabled = NO;

    if (effect) {
        if (@available(iOS 26.0, *)) {
            glassView.cornerConfiguration = [UICornerConfiguration capsuleConfiguration];
        }
    } else {
        // A dark blur with a dark tint and a light rim, and a soft shadow to
        // lift it off light screens.
        glassView.effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterialDark];
        glassView.layer.cornerRadius = LCHomeButtonDiameter / 2;
        glassView.clipsToBounds = YES;
        glassView.layer.borderWidth = 1;
        glassView.layer.borderColor = [UIColor colorWithWhite:1 alpha:LCHomeButtonRim].CGColor;

        UIView *tint = [[UIView alloc] initWithFrame:glassView.contentView.bounds];
        tint.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        tint.backgroundColor = [UIColor colorWithWhite:0 alpha:LCHomeButtonTint];
        [glassView.contentView addSubview:tint];

        self.face.layer.shadowColor = UIColor.blackColor.CGColor;
        self.face.layer.shadowOpacity = 0.2;
        self.face.layer.shadowRadius = 8;
        self.face.layer.shadowOffset = CGSizeMake(0, 2);
        self.face.layer.shadowPath = [UIBezierPath bezierPathWithOvalInRect:self.face.bounds].CGPath;
    }
    [self.face addSubview:glassView];
}

- (void)addRings {
    CGPoint middle = CGPointMake(LCHomeButtonDiameter / 2, LCHomeButtonDiameter / 2);
    for (size_t index = 0; index < sizeof(LCHomeButtonRings) / sizeof(LCHomeButtonRings[0]); index++) {
        CGFloat size = LCHomeButtonRings[index][0];
        UIView *ring = [[UIView alloc] initWithFrame:CGRectMake(0, 0, size, size)];
        ring.center = middle;
        ring.backgroundColor = [UIColor colorWithWhite:1 alpha:LCHomeButtonRings[index][1]];
        ring.layer.cornerRadius = size / 2;
        ring.userInteractionEnabled = NO;
        [self.face addSubview:ring];
    }
}

- (void)setHighlighted:(BOOL)highlighted {
    BOOL changed = highlighted != self.highlighted;
    [super setHighlighted:highlighted];
    if (!changed) {
        return;
    }
    BOOL reduceMotion = UIAccessibilityIsReduceMotionEnabled();
    UIView *face = self.face;
    [UIView animateWithDuration:0.3
                          delay:0
         usingSpringWithDamping:0.7
          initialSpringVelocity:0
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        if (reduceMotion) {
            face.alpha = highlighted ? 0.7 : 1;
        } else {
            CGFloat scale = highlighted ? LCHomeButtonPressedScale : 1;
            face.transform = CGAffineTransformMakeScale(scale, scale);
        }
    } completion:nil];
}

@end

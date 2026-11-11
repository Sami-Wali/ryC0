#import "LCHomeButtonWindow.h"

@implementation LCHomeButtonWindow

// Touches that land on nothing but the window or its root view go on to the
// windows below. Whatever else is here takes its touches: the button, the
// cover shown while ryC0 opens, and anything an app presents on this
// window because it was the last one in UIApplication's list.
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hit = [super hitTest:point withEvent:event];
    if (hit == self || hit == self.rootViewController.view) {
        return nil;
    }
    return hit;
}

- (BOOL)canBecomeKeyWindow {
    return NO;
}

// UIKit asks this, privately, before letting a window's view controllers
// decide how the status bar looks.
- (BOOL)_canAffectStatusBarAppearance {
    return NO;
}

@end

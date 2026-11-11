//
//  LCStatusBarManager.m
//  LiveContainer
//
//  Created by Duy Tran on 20/2/26.
//
#import "LCStatusBarManager.h"
#import "LCSharedUtils.h"
#import "LiveContainerSwiftUI-Swift.h"
#import "VirtualWindowsHostView.h"

@implementation LCStatusBarManager
- (void)handleTapAction:(UIAction *)action {
    if ([LCSharedUtils guestHomeControl] == LCGuestHomeControlClock && [action respondsToSelector:NSSelectorFromString(@"xPosition")]) {
        CGFloat width = CGRectGetWidth(self.statusBarFrame);
        CGFloat x = [[action valueForKey:@"xPosition"] doubleValue];
        if (UIApplication.sharedApplication.userInterfaceLayoutDirection == UIUserInterfaceLayoutDirectionRightToLeft) x = width - x;
        if (x >= 0 && x < MIN(112, width / 2)) {
            AppSceneViewController *window = self.nativeWindowViewController;
            if (window.isAppRunning && [window.delegate respondsToSelector:@selector(appSceneVCRequestedHome:)]) {
                [window.delegate appSceneVCRequestedHome:window];
                return;
            }
            if (!window && [MainWindow returnFromGuestClockTap]) return;
        }
    }
    if(self.nativeWindowViewController) {
        [self.nativeWindowViewController handleStatusBarTapAction:action];
        return;
    }
    BOOL handledByVirtualWindow = [MultitaskDockManager.shared.windowHostingView handleStatusBarTapAction:action];
    if(!handledByVirtualWindow) {
        [super handleTapAction:action];
    }
}
@end

@implementation UIApplication(LiveContainer)
+ (Class)_statusBarManagerClass {
    if (@available(iOS 16.0, *)) {
        return LCStatusBarManager.class;
    } else {
        return UIStatusBarManager.class;
    }
}
@end

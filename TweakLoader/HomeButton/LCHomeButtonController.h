@import UIKit;

NS_ASSUME_NONNULL_BEGIN

// Puts the Home button over an app ryC0 runs, and takes the person back
// to ryC0 when they press it. ryC0 turned into the app when it
// opened it, so going back means opening ryC0 again with no app chosen:
// LCSharedUtils' launchToGuestAppWithClassicMode:, as the Home Screen uses to
// open apps, which ryC0's launch takes as a request for its own screens.
// First it tells the app it is going to the background (LCAppDeparture), as
// pressing Home on the iPhone does, so the app can save before it ends.
//
// TweakLoader starts it in every app ryC0 runs itself. It stays out of
// apps in multitask windows (LiveProcess), which ryC0's windows already
// frame, and out of apps whose settings turn the Home button off.
@interface LCHomeButtonController : NSObject

// The one controller of this app's process.
@property (class, nonatomic, readonly) LCHomeButtonController *sharedController;

// Shows the button as soon as the app's screen is up, and again on whichever
// screen the app comes back to.
- (void)start;
- (void)trackHomeSwipe:(UIEvent *)event;

@end

NS_ASSUME_NONNULL_END

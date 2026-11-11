@import UIKit;

NS_ASSUME_NONNULL_BEGIN

// Walks the app through what iOS tells an app when the person goes Home,
// before the Home button closes it to open ryC0 again. Pressing the
// button ends the app's process while it is still on screen, so without this
// it would never hear that it is leaving, and apps that save their work only
// then (games, Core Data apps saving in the background callback) would lose
// it. Each screen of the app resigns active and enters the background, through
// its scene delegate and the scene notifications; the app does the same
// through its app delegate, when it has no scene delegates, and the app
// notifications. Termination isn't announced, since the app isn't ending yet
// if ryC0 doesn't open.
@interface LCAppDeparture : NSObject

// Tells the app it is resigning active and entering the background.
- (void)leave;

// Brings the app back to the foreground and makes it active again, for when
// ryC0 didn't open after all and the app stays.
- (void)comeBack;

@end

NS_ASSUME_NONNULL_END

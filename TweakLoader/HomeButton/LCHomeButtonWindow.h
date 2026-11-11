@import UIKit;

NS_ASSUME_NONNULL_BEGIN

// The window the Home button floats in, above a running app's windows. It
// covers the screen so it turns with it, but lets every touch outside its
// content through to the app, never becomes the key window (the app keeps the
// keyboard), and leaves the status bar to the app.
@interface LCHomeButtonWindow : UIWindow
@end

NS_ASSUME_NONNULL_END

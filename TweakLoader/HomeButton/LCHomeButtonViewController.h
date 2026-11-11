@import UIKit;
#import "LCSharedUtils.h"

NS_ASSUME_NONNULL_BEGIN

// The Home button window's root view controller. It keeps the button against
// an edge of the screen, lets it be dragged or flung to another place like
// AssistiveTouch, dims it after a few seconds without a touch, and leaves
// rotation, the status bar, the Home indicator and the screen edge gestures to
// the app underneath.
@interface LCHomeButtonViewController : UIViewController
@property (nonatomic) LCGuestHomeControl homeControl;

// Called when the button is pressed.
@property (nonatomic, copy, nullable) void (^pressHandler)(void);
@property (nonatomic, copy, nullable) void (^switcherHandler)(void);

// Captures the guest before it receives the background callbacks.
- (nullable UIImage *)captureGuestPreview;
- (void)animateReturnWithBackdrop:(nullable UIImage *)backdrop;

// Restores the guest if the launcher could not be opened.
- (void)fadeBackIn;

@end

NS_ASSUME_NONNULL_END

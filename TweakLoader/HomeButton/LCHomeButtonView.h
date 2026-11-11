@import UIKit;

NS_ASSUME_NONNULL_BEGIN

// The round Home button drawn over a running app. It is the button
// ryC0's own screens show (HomeButton in LiveContainerSwiftUI), drawn
// with UIKit: dark tinted Liquid Glass when the app runs with Liquid Glass, a
// dark blur with a light rim otherwise, and AssistiveTouch's rings on top. It
// shrinks a little while pressed, or dims with Reduce Motion on.
@interface LCHomeButtonView : UIControl

// The button's width and height, HomeDesign.homeButtonSize in the SwiftUI app.
@property (class, nonatomic, readonly) CGFloat diameter;

@end

NS_ASSUME_NONNULL_END

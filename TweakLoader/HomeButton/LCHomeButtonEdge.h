@import Foundation;

// The edge of the screen the Home button rests against over a running app.
// These are the screen's own edges as the app is shown, whatever the
// language's reading direction.
typedef NS_ENUM(NSInteger, LCHomeButtonEdge) {
    LCHomeButtonEdgeLeft,
    LCHomeButtonEdgeRight,
    LCHomeButtonEdgeTop,
    LCHomeButtonEdgeBottom,
};

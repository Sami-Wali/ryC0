//
//  HomeJiggle.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The wobble icons make in edit mode: a small tilt one way and the other,
/// repeating. Each icon starts its own way and at its own pace, so they don't
/// move in step. Every loop starts and ends level, so it repeats without a
/// jump. The animation runs outside the view's body, so jiggling doesn't
/// redraw the icons.
struct HomeJiggle: ViewModifier {
    /// Whether the icon jiggles. It comes to rest when this turns false.
    let isActive: Bool
    /// Varies the direction and pace, so neighboring icons differ. It is 0 or more.
    let seed: Int

    func body(content: Content) -> some View {
        let angle = HomeDesign.jiggleAngle * (seed.isMultiple(of: 2) ? 1 : -1)
        let quarter = HomeDesign.jiggleDuration / 4 * (1 + Double(seed % 5) * 0.03)
        content.keyframeAnimator(initialValue: 0.0, repeating: isActive) { view, tilt in
            view.rotationEffect(.degrees(tilt))
        } keyframes: { _ in
            KeyframeTrack {
                CubicKeyframe(angle, duration: quarter)
                CubicKeyframe(0, duration: quarter)
                CubicKeyframe(-angle, duration: quarter)
                CubicKeyframe(0, duration: quarter)
            }
        }
    }
}

extension View {
    /// Makes the view jiggle like a Home Screen icon in edit mode while
    /// `isActive` is true.
    func homeJiggle(isActive: Bool, seed: Int) -> some View {
        modifier(HomeJiggle(isActive: isActive, seed: seed))
    }
}

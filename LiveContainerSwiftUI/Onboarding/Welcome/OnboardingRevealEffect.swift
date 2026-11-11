//
//  OnboardingRevealEffect.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// Lets a part of the welcome screen arrive as Apple's welcome screens do,
/// after the part above it: it starts soft, a touch small and a little low,
/// then sharpens, grows and rises into place as it fades in. Reduce Motion
/// keeps only the fade. VoiceOver users get every part at once, so nothing
/// they swipe to is still invisible.
struct OnboardingRevealEffect: ViewModifier {
    let isRevealed: Bool
    /// Where the part comes on the screen, from the top, which sets how long
    /// it waits.
    let order: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled

    func body(content: Content) -> some View {
        let isShown = isRevealed || voiceOverEnabled
        let moves = !isShown && !reduceMotion

        content
            .opacity(isShown ? 1 : 0)
            .blur(radius: moves ? OnboardingDesign.revealBlur : 0)
            .scaleEffect(moves ? 0.96 : 1)
            .offset(y: moves ? OnboardingDesign.revealOffset : 0)
            .animation(animation, value: isShown)
    }

    private var animation: Animation {
        OnboardingDesign.revealSpring.delay(OnboardingDesign.revealDelay + Double(order) * OnboardingDesign.revealStagger)
    }
}

extension View {
    /// Has the view arrive out of a blur when `isRevealed` becomes true, after
    /// the parts with a lower `order`, rising into place unless Reduce Motion
    /// is on.
    func onboardingReveal(_ isRevealed: Bool, order: Int) -> some View {
        modifier(OnboardingRevealEffect(isRevealed: isRevealed, order: order))
    }
}

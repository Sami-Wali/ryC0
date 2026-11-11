//
//  OnboardingBottomBar.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// Pins an onboarding page's footer to the bottom of the screen and makes
/// room for it, so the page's last rows scroll out from under it. On iOS 26
/// and later it's a safe area bar, which also fades the rows scrolling
/// beneath it, as toolbars do.
struct OnboardingBottomBar<Bar: View>: ViewModifier {
    @ViewBuilder let bar: Bar

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.safeAreaBar(edge: .bottom) {
                bar
            }
        } else {
            content.safeAreaInset(edge: .bottom) {
                bar
            }
        }
    }
}

extension View {
    /// Pins this onboarding page's footer to the bottom of the screen.
    func onboardingBottomBar(@ViewBuilder _ bar: () -> some View) -> some View {
        modifier(OnboardingBottomBar(bar: bar))
    }
}

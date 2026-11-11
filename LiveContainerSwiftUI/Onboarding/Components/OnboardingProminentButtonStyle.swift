//
//  OnboardingProminentButtonStyle.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The style of the main button at the bottom of an onboarding page: the
/// prominent Liquid Glass button on iOS 26 and later, and before that a
/// filled capsule.
struct OnboardingProminentButtonStyle: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *), SharedModel.isLiquidGlassEnabled {
            content.buttonStyle(.glassProminent)
        } else {
            content
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
        }
    }
}

extension View {
    /// Styles this button as an onboarding page's main button.
    func onboardingProminentButtonStyle() -> some View {
        modifier(OnboardingProminentButtonStyle())
    }
}

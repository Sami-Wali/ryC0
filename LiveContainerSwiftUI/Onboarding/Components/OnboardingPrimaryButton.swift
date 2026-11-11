//
//  OnboardingPrimaryButton.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The prominent button at the bottom of an onboarding page, as wide as the
/// page allows, like Continue in iOS's own setup.
struct OnboardingPrimaryButton: View {
    /// The button's title, already localized.
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity)
        }
        .onboardingProminentButtonStyle()
        .controlSize(.large)
    }
}

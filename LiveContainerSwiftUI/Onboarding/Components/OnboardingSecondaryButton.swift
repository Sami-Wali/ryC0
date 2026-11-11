//
//  OnboardingSecondaryButton.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// A plain button under an onboarding page's main one, like Set Up Later in
/// iOS's own setup. Everything left for later is in Settings.
struct OnboardingSecondaryButton: View {
    /// The button's title, already localized.
    let title: String
    let action: () -> Void

    var body: some View {
        Button(title, action: action)
            .buttonStyle(OnboardingPlainButtonStyle())
    }
}

//
//  OnboardingProgressButton.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The main button of a step that does its work by itself, like Check Setup:
/// while the work runs it turns to clear glass, shows a spinner and what's
/// happening, and ignores taps; then it's an ordinary main button.
struct OnboardingProgressButton: View {
    /// The button's title, already localized.
    let title: String
    /// What shows beside the spinner, like "Checking…", already localized.
    let progressTitle: String
    let isInProgress: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            // Both stay in the layout, so the button keeps its size.
            ZStack {
                Text(title)
                    .opacity(isInProgress ? 0 : 1)

                Label {
                    Text(progressTitle)
                } icon: {
                    ProgressView()
                }
                // In ryC0's pink on the clear glass, where the white
                // title would vanish.
                .foregroundStyle(OnboardingDesign.accent)
                .tint(OnboardingDesign.accent)
                .opacity(isInProgress ? 1 : 0)
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
        }
        .onboardingProminentButtonStyle()
        .tint(isInProgress ? Color.clear : nil)
        .controlSize(.large)
        .allowsHitTesting(!isInProgress)
        .animation(.smooth(duration: 0.25), value: isInProgress)
        .accessibilityLabel(isInProgress ? Text(progressTitle) : Text(title))
    }
}

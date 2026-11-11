//
//  OnboardingWelcomeHeader.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The top of the welcome screen: ryC0's icon putting itself together,
/// and a welcome with its name in ryC0's pink, the way Apple's own
/// apps greet you, coming into focus as the icon finishes.
struct OnboardingWelcomeHeader: View {
    let isRevealed: Bool

    var body: some View {
        VStack(spacing: OnboardingDesign.headerSpacing) {
            OnboardingWelcomeIcon(isRevealed: isRevealed)

            Text(title)
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
                .onboardingReveal(isRevealed, order: 0)
        }
        .frame(maxWidth: .infinity)
    }

    /// "Welcome to ryC0", with the name in pink.
    private var title: AttributedString {
        let name = "ryC0"
        var title = AttributedString("ryc0.onboarding.welcome.title %@".localizeWithFormat(name))
        if let range = title.range(of: name) {
            title[range].swiftUI.foregroundColor = OnboardingDesign.accent
        }
        return title
    }
}

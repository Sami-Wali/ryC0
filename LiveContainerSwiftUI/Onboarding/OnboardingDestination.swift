//
//  OnboardingDestination.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The page for each step pushed over the welcome screen.
struct OnboardingDestination: View {
    let step: OnboardingStep

    var body: some View {
        Group {
            switch step {
            case .connect:
                OnboardingConnectPage()
            case .checkSetup:
                OnboardingCheckSetupPage()
            case .addApps:
                OnboardingAddAppsPage()
            case .done:
                OnboardingDonePage()
            }
        }
        // No title, so the only thing at the top is the system's Back button.
        .navigationBarTitleDisplayMode(.inline)
    }
}

//
//  OnboardingPlainButtonStyle.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The style of the plain buttons under an onboarding page's main one, like
/// Set Up Later in iOS's own setup: tinted text with a full size tap area,
/// which dims while pressed. Buttons made elsewhere, like importing a
/// certificate, take it on too.
struct OnboardingPlainButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        OnboardingPlainButtonLabel(configuration: configuration)
    }
}

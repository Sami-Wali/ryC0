//
//  OnboardingDoneBadge.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The check in ryC0's pink on the corner of its icon at the end of
/// onboarding, ringed in the page's color so it looks cut out of the icon.
struct OnboardingDoneBadge: View {
    var body: some View {
        Image(systemName: "checkmark")
            .resizable()
            .scaledToFit()
            .bold()
            .foregroundStyle(.white)
            .frame(width: OnboardingDesign.badgeSize * OnboardingDesign.glyphRatio, height: OnboardingDesign.badgeSize * OnboardingDesign.glyphRatio)
            .frame(width: OnboardingDesign.badgeSize, height: OnboardingDesign.badgeSize)
            .background(OnboardingDesign.accent, in: .circle)
            .padding(OnboardingDesign.badgeRing)
            .background(OnboardingDesign.background, in: .circle)
            .accessibilityHidden(true)
    }
}

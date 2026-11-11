//
//  OnboardingFooter.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The buttons pinned to the bottom of an onboarding page, as in iOS's own
/// setup: one prominent button that does the step, and under it plain ones,
/// like the one that leaves it for later. They stay a comfortable width on
/// wide screens.
struct OnboardingFooter<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: OnboardingDesign.footerSpacing) {
            content
        }
        .frame(maxWidth: OnboardingDesign.contentWidth)
        .padding(.horizontal, OnboardingDesign.pageMargin)
        .padding(.vertical, OnboardingDesign.footerPadding)
        .frame(maxWidth: .infinity)
        .background {
            // Liquid Glass sets the bar apart with its scroll edge effect.
            // Without it, the page's own color keeps rows from showing
            // through the buttons.
            if #available(iOS 26.0, *), SharedModel.isLiquidGlassEnabled {
                Color.clear
            } else {
                Rectangle()
                    .fill(OnboardingDesign.background)
                    .ignoresSafeArea()
            }
        }
    }
}

//
//  OnboardingWelcomePage.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The first screen, laid out like the welcome screens of Apple's own apps:
/// ryC0's icon and name, what it does, and Continue pinned at the
/// bottom under a note on what sharing one sandbox means. On iPad the icon
/// and features sit in the middle of the room above the footer, so a tall
/// window doesn't leave a wide gap under them.
struct OnboardingWelcomePage: View {
    @Environment(OnboardingFlow.self) private var flow

    /// Set the first time the screen appears, which starts the header and the
    /// features arriving in turn. Coming back with Back leaves them in place.
    @State private var isRevealed = false
    /// On iPad, the height of the room between the top and the footer, which
    /// the content is centered in. It stays nil on iPhone, where the content
    /// sits at the top.
    @State private var visibleHeight: CGFloat?

    var body: some View {
        ScrollView {
            VStack(spacing: OnboardingDesign.welcomeSpacing) {
                OnboardingWelcomeHeader(isRevealed: isRevealed)

                VStack(alignment: .leading, spacing: OnboardingDesign.featureSpacing) {
                    ForEach(OnboardingFeature.allCases) { feature in
                        OnboardingFeatureRow(feature: feature)
                            .onboardingReveal(isRevealed, order: feature.rawValue + 1)
                    }
                }
            }
            .padding(.horizontal, OnboardingDesign.welcomeMargin)
            .padding(.top, OnboardingDesign.welcomeTopPadding)
            .padding(.bottom, OnboardingDesign.welcomeBottomPadding)
            .frame(maxWidth: OnboardingDesign.contentWidth)
            .frame(maxWidth: .infinity, minHeight: visibleHeight)
        }
        .scrollBounceBehavior(.basedOnSize)
        .onGeometryChange(for: Double.self, of: { $0.size.height - $0.safeAreaInsets.top - $0.safeAreaInsets.bottom }, action: visibleHeightChanged)
        .background(OnboardingDesign.background)
        .navigationBarTitleDisplayMode(.inline)
        .onboardingBottomBar {
            OnboardingFooter {
                OnboardingSandboxNote()
                OnboardingPrimaryButton(title: "lc.common.continue".loc, action: continueTapped)
            }
            // The footer arrives after the features.
            .onboardingReveal(isRevealed, order: OnboardingFeature.allCases.count + 1)
        }
        .onAppear(perform: reveal)
    }

    private func reveal() {
        isRevealed = true
    }

    private func continueTapped() {
        flow.begin()
    }

    /// Centers the content on iPad in the room the scroll view shows between
    /// the navigation bar and the footer. The iPhone keeps it at the top.
    private func visibleHeightChanged(_ height: Double) {
        guard !SharedModel.isPhone else {
            return
        }
        visibleHeight = CGFloat(max(height, 0))
    }
}

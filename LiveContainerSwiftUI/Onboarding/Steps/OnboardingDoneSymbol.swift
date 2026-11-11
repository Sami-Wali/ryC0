//
//  OnboardingDoneSymbol.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The top of the last step: ryC0's icon, with a check in its pink
/// popping onto the corner once the page has slid in, and a tap to go with
/// it. With Reduce Motion on, the check fades in instead.
struct OnboardingDoneSymbol: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Whether the check has popped on.
    @State private var isShowingCheck = false

    var body: some View {
        RyC0Mark()
            .overlay(alignment: .bottomTrailing) {
                OnboardingDoneBadge()
                    .offset(x: OnboardingDesign.badgeOffset, y: OnboardingDesign.badgeOffset)
                    .scaleEffect(isShowingCheck || reduceMotion ? 1 : 0.3)
                    .opacity(isShowingCheck ? 1 : 0)
            }
            .animation(OnboardingDesign.pop, value: isShowingCheck)
            .sensoryFeedback(.success, trigger: isShowingCheck) { _, isShowing in
                isShowing
            }
            .task {
                await showCheck()
            }
    }

    /// Waits for the page to finish sliding in, then pops the check on, so
    /// the tap lands with it.
    private func showCheck() async {
        try? await Task.sleep(for: .seconds(OnboardingDesign.badgeDelay))
        guard !Task.isCancelled else { return }
        isShowingCheck = true
    }
}

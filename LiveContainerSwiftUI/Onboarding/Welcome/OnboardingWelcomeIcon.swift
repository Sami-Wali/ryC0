//
//  OnboardingWelcomeIcon.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// ryC0's icon on the welcome screen, which puts itself together: the
/// pink tile swells in, then its apps pop onto it from the top left, with a
/// light tap as they start. With Reduce Motion the icon only fades in, and
/// with VoiceOver it's there from the start.
struct OnboardingWelcomeIcon: View {
    let isRevealed: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled

    @State private var stage = RyC0MarkStage.hidden

    var body: some View {
        RyC0Mark(stage: stage)
            .sensoryFeedback(.impact(weight: .light, intensity: 0.7), trigger: stage) { _, newStage in
                newStage == .apps
            }
            .onChange(of: isRevealed, initial: true, arrive)
    }

    /// Brings the icon in, one part after another, the first time the
    /// screen shows.
    private func arrive() {
        guard isRevealed, stage == .hidden else { return }
        if voiceOverEnabled {
            stage = .apps
        } else if reduceMotion {
            // RyC0Mark keeps its parts whole with Reduce Motion, so
            // only their opacity changes.
            withAnimation(OnboardingDesign.markFade) {
                stage = .apps
            }
        } else {
            withAnimation(OnboardingDesign.markTileArrival) {
                stage = .tile
            } completion: {
                // Each app brings its own animation, one diagonal after
                // another.
                stage = .apps
            }
        }
    }
}

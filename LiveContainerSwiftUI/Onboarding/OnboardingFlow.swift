//
//  OnboardingFlow.swift
//  LiveContainerSwiftUI
//

import Observation

/// Onboarding's place: which steps sit over the welcome screen, and whether
/// the last has been passed. Pages only ever move on by asking it.
///
/// Each move only happens while the step it moves from is the one showing,
/// so a double tap, or a check that finishes late, can't push a page twice
/// or out of order.
@MainActor
@Observable
final class OnboardingFlow {
    /// The steps shown over the welcome screen, in the order they were
    /// reached. Back takes the last one off.
    var path: [OnboardingStep]

    /// Set once the person moves on from the last step; onboarding closes then.
    private(set) var isFinished = false

    /// - Parameter step: The step to show over the welcome screen from the
    ///   start, as Settings asks for, or nil to open on the welcome screen.
    init(startingAt step: OnboardingStep?) {
        path = step.map { [$0] } ?? []
    }

    /// Leaves the welcome screen for the first step.
    func begin() {
        guard path.isEmpty else { return }
        path.append(.connect)
    }

    /// Pushes the step that follows `step`, or finishes when there's none.
    func advance(from step: OnboardingStep) {
        move(from: step, to: step.next)
    }

    /// Moves past `step` without doing it, leaving it for Settings.
    func skip(_ step: OnboardingStep, hasCertificate: Bool) {
        move(from: step, to: step.nextWhenSkipped(hasCertificate: hasCertificate))
    }

    private func move(from step: OnboardingStep, to next: OnboardingStep?) {
        guard path.last == step else { return }

        if let next {
            path.append(next)
        } else {
            isFinished = true
        }
    }
}

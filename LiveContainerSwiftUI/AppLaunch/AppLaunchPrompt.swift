//
//  AppLaunchPrompt.swift
//  LiveContainerSwiftUI
//

import Observation

/// A question one of AppLaunchCoordinator's flows waits on, such as which app an
/// install replaces. The flow awaits `ask()`, a view shows the question while
/// `isPresented` is true, and the view's buttons call `answer(_:)`.
@MainActor
@Observable
final class AppLaunchPrompt<Answer> {
    /// Whether the question is on screen.
    var isPresented = false

    @ObservationIgnored private var continuation: CheckedContinuation<Answer?, Never>?

    /// Shows the question and waits for the answer. Returns nil when the person
    /// dismissed it without answering, or when the question was asked again
    /// before they answered.
    func ask() async -> Answer? {
        continuation?.resume(returning: nil)
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            isPresented = true
        }
    }

    /// Answers the open question and takes it off screen. Once a question has
    /// its answer, later answers only hide it, so a dismissal that follows a
    /// button tap doesn't change what the button chose.
    func answer(_ answer: Answer?) {
        isPresented = false
        continuation?.resume(returning: answer)
        continuation = nil
    }
}

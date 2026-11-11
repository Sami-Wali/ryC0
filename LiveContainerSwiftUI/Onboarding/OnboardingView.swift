//
//  OnboardingView.swift
//  LiveContainerSwiftUI
//

import SwiftUI

struct OnboardingView: View {
    @Environment(OnboardingModel.self) private var onboarding
    @Environment(HomeRouter.self) private var router

    @State private var flow: OnboardingFlow
    /// The certificate and setup state the steps share, read afresh each
    /// time onboarding opens.
    @State private var connection = SigningStatus()

    init(startsAtConnect: Bool) {
        _flow = State(initialValue: OnboardingFlow(startingAt: startsAtConnect ? .connect : nil))
    }

    var body: some View {
        NavigationStack(path: $flow.path) {
            OnboardingWelcomePage()
                .navigationDestination(for: OnboardingStep.self, destination: OnboardingDestination.init)
        }
        .environment(flow)
        .environment(connection)
        .tint(OnboardingDesign.accent)
        .onChange(of: flow.isFinished, finish)
        .onChange(of: router.certificatesStored) {
            connection.certificateChanged()
        }
    }

    private func finish() {
        guard flow.isFinished else { return }
        onboarding.finish()
    }
}

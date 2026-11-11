//
//  OnboardingSandboxNote.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The note above Continue on the welcome screen, where Apple's own welcome
/// screens note privacy: the apps inside ryC0 share one sandbox, so
/// they can see each other's files and use ryC0's certificate.
struct OnboardingSandboxNote: View {
    var body: some View {
        Text("ryc0.onboarding.sandboxNote".loc)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.bottom, OnboardingDesign.noteSpacing)
    }
}

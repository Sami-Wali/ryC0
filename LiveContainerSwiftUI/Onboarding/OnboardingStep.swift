//
//  OnboardingStep.swift
//  LiveContainerSwiftUI
//

/// The steps of onboarding pushed over the welcome screen, in the order they come.
enum OnboardingStep: Hashable {
    case connect

    case checkSetup

    case addApps

    /// Where everything stands, and the way to the Home Screen.
    case done

    /// The step after this one, or nil after the last.
    var next: OnboardingStep? {
        switch self {
        case .connect: .checkSetup
        case .checkSetup: .addApps
        case .addApps: .done
        case .done: nil
        }
    }

    func nextWhenSkipped(hasCertificate: Bool) -> OnboardingStep? {
        self == .connect && !hasCertificate ? .addApps : next
    }
}

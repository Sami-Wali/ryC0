//
//  OnboardingModel.swift
//  LiveContainerSwiftUI
//

import SwiftUI

@MainActor
@Observable
final class OnboardingModel {
    /// Where finishing onboarding is remembered.
    private static let completedKey = "RYC0HasCompletedOnboarding"

    /// Whether onboarding shows over the Home Screen.
    private(set) var isPresented: Bool
    /// Whether onboarding still covers the Home Screen: from when it opens
    /// until it has faded away. The window keeps onboarding's appearance
    /// until then, rather than the Home Screen's black one.
    private(set) var coversHomeScreen: Bool
    private(set) var startsAtConnect = false

    let pendingInstalls: PendingInstallQueue

    init(coordinator: AppLaunchCoordinator) {
        let isNeeded = Self.isNeededAtLaunch(sharedModel: coordinator.sharedModel)
        pendingInstalls = PendingInstallQueue(coordinator: coordinator, holdsForOnboarding: isNeeded)
        isPresented = isNeeded
        coversHomeScreen = isNeeded
    }

    /// Whether onboarding shows when ryC0 opens: on the first launch,
    /// unless a certificate is stored and the last check of the setup
    /// passed. A second ryC0 signs with the first one's certificate
    /// and installs nothing itself, so it never shows there.
    private static func isNeededAtLaunch(sharedModel: SharedModel) -> Bool {
        guard sharedModel.multiLCStatus != 2,
              !UserDefaults.standard.bool(forKey: completedKey) else {
            return false
        }
        let hasCertificate = LCSharedUtils.certificatePassword() != nil
        return !(hasCertificate && SigningCertificate.lastCheckPassed == true)
    }

    func present() {
        guard !isPresented else { return }
        startsAtConnect = true
        coversHomeScreen = true
        pendingInstalls.holdForOnboarding()
        withAnimation(OnboardingDesign.coverFade) {
            isPresented = true
        }
    }

    /// Remembers that onboarding is done, so it doesn't come back, and fades
    /// it away over the Home Screen. Apps still on their way in carry on.
    func finish() {
        guard isPresented else { return }
        UserDefaults.standard.set(true, forKey: Self.completedKey)
        pendingInstalls.onboardingDidClose()
        withAnimation(OnboardingDesign.homeArrival) {
            isPresented = false
        } completion: {
            self.coversHomeScreen = false
        }
    }

    /// Starts every received install link in the durable queue. Downloads
    /// start immediately; imports respect onboarding and the shared install gate.
    func takeLink(_ link: AppLink) -> Bool {
        guard case .install(let address) = link else {
            return false
        }
        return pendingInstalls.receive(address: address)
    }
}

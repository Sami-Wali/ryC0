//
//  OnboardingDonePage.swift
//  LiveContainerSwiftUI
//

import SwiftUI

struct OnboardingDonePage: View {
    @Environment(OnboardingModel.self) private var onboarding
    @Environment(SigningStatus.self) private var connection
    @Environment(OnboardingFlow.self) private var flow

    var body: some View {
        OnboardingSetupForm {
            OnboardingHeader(title: "ryc0.onboarding.done.title".loc, message: message) {
                OnboardingDoneSymbol()
            }
        } content: {
            Section {
                OnboardingChecklistRow(systemImage: "bolt.fill", title: "ryc0.settings.signing".loc, isDone: connection.isReadyToSign) {
                    Text(connection.summary)
                }

                OnboardingChecklistRow(systemImage: "signature", title: "ryc0.settings.setup.signing".loc, isDone: isSigningChecked) {
                    Text(isSigningChecked ? "ryc0.onboarding.done.checked".loc : "ryc0.onboarding.done.notSetUp".loc)
                }

                OnboardingChecklistRow(systemImage: "square.grid.2x2.fill", title: "ryc0.onboarding.done.apps".loc, isDone: !installedNames.isEmpty) {
                    Text(appsDetail)
                }
            }

        }
        .onboardingBottomBar {
            OnboardingFooter {
                OnboardingPrimaryButton(title: "ryc0.onboarding.done.start".loc, action: finish)
            }
        }
        .navigationBarBackButtonHidden()
    }

    /// Whether signing passed Check Setup.
    private var isSigningChecked: Bool {
        connection.result(for: .signing) == .passed
    }

    private var installedNames: [String] {
        onboarding.pendingInstalls.installedNames
    }

    private var message: String {
        if connection.isReadyToSign && isSigningChecked {
            "ryc0.onboarding.done.ready".loc
        } else {
            "ryc0.onboarding.done.later".loc
        }
    }

    /// The apps that came in, or that some are still coming.
    private var appsDetail: String {
        if !installedNames.isEmpty {
            installedNames.formatted()
        } else if onboarding.pendingInstalls.hasUnfinishedItems {
            "ryc0.home.installing".loc
        } else {
            "ryc0.onboarding.done.noApps".loc
        }
    }

    private func finish() {
        flow.advance(from: .done)
    }
}

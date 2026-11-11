//
//  OnboardingCheckSetupPage.swift
//  LiveContainerSwiftUI
//

import SwiftUI

struct OnboardingCheckSetupPage: View {
    @Environment(SigningStatus.self) private var connection
    @Environment(OnboardingFlow.self) private var flow
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var isShowingDiagnosis = false

    var body: some View {
        OnboardingSetupForm {
            OnboardingHeader(systemImage: "checkmark.shield.fill", title: "ryc0.settings.setup.check".loc, message: message)
        } content: {
            Section {
                ForEach(SigningSetupCheck.allCases, id: \.self) { check in
                    OnboardingSetupCheckRow(check: check, result: connection.result(for: check))
                }
            } footer: {
                Text("ryc0.onboarding.check.footer".loc)
            }

            if hasFailed {
                Section {
                    Button("lc.settings.jitlessDiagnose".loc, action: showDiagnosis)
                }
            }
        }
        .onboardingBottomBar {
            OnboardingFooter {
                if hasFailed {
                    SigningImportCertificateButton(title: "ryc0.onboarding.connect.import".loc)
                        .buttonStyle(OnboardingPlainButtonStyle())
                    OnboardingSecondaryButton(title: "ryc0.onboarding.check.retry".loc, action: checkAgain)
                    OnboardingSecondaryButton(title: "ryc0.onboarding.setUpLater".loc, action: skip)
                } else {
                    OnboardingProgressButton(
                        title: "lc.common.continue".loc,
                        progressTitle: "ryc0.settings.setup.checking".loc,
                        isInProgress: !hasPassed,
                        action: continueTapped
                    )
                }
            }
        }
        .animation(reduceMotion ? nil : OnboardingDesign.spring, value: signing)
        .sensoryFeedback(.success, trigger: hasPassed) { _, hasPassed in
            hasPassed
        }
        .sensoryFeedback(.error, trigger: hasFailed) { _, hasFailed in
            hasFailed
        }
        .sheet(isPresented: $isShowingDiagnosis) {
            OnboardingDiagnosisSheet()
        }
        .task(id: connection.certificateVersion) {
            await checkIfNeeded()
        }
    }

    /// How signing stands, which decides the step.
    private var signing: SigningCheckResult {
        connection.result(for: .signing)
    }

    private var hasPassed: Bool {
        signing == .passed
    }

    private var hasFailed: Bool {
        signing.failure != nil
    }

    private var message: String {
        if hasPassed {
            "ryc0.onboarding.check.passed".loc
        } else if hasFailed {
            "ryc0.onboarding.check.failed".loc
        } else {
            "ryc0.onboarding.check.checking".loc
        }
    }

    /// Checks the setup as the step shows, and again for each different
    /// certificate stored while it does, unless it already passed, like when
    /// coming back to the step.
    private func checkIfNeeded() async {
        guard !hasPassed else { return }
        await connection.checkSetup()
    }

    private func checkAgain() {
        Task {
            await connection.checkSetup()
        }
    }

    private func showDiagnosis() {
        isShowingDiagnosis = true
    }

    private func continueTapped() {
        flow.advance(from: .checkSetup)
    }

    private func skip() {
        flow.skip(.checkSetup, hasCertificate: connection.hasCertificate)
    }
}

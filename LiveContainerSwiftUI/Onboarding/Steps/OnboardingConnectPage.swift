//
//  OnboardingConnectPage.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// Imports the signing certificate and checks that it belongs to ryC0's team.
struct OnboardingConnectPage: View {
    @Environment(SigningStatus.self) private var connection
    @Environment(OnboardingFlow.self) private var flow
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        OnboardingSetupForm {
            OnboardingHeader(systemImage: "bolt.fill", title: "ryc0.onboarding.connect.title".loc, message: message)
        } content: {
            Section {
                OnboardingChecklistRow(systemImage: "checkmark.seal.fill", title: "ryc0.settings.signing.certificate".loc, isDone: connection.isCertificateUsable) {
                    Text(certificateDetail)
                }

                OnboardingChecklistRow(systemImage: "person.2.fill", title: "ryc0.onboarding.connect.sameTeam".loc, isDone: connection.isSameTeam == true) {
                    Text(teamDetail)
                }
            } footer: {
                Text("ryc0.onboarding.connect.footer".loc)
            }
        }
        .onboardingBottomBar {
            OnboardingFooter {
                if connection.isReadyToSign {
                    OnboardingPrimaryButton(title: "lc.common.continue".loc, action: continueTapped)
                } else {
                    SigningImportCertificateButton(title: "ryc0.onboarding.connect.import".loc)
                        .buttonStyle(OnboardingPlainButtonStyle())

                    OnboardingSecondaryButton(title: "ryc0.onboarding.setUpLater".loc, action: skip)
                }
            }
        }
        .animation(reduceMotion ? nil : OnboardingDesign.spring, value: connection.isReadyToSign)
        // A tap for getting ready, not for losing it.
        .sensoryFeedback(.success, trigger: connection.isReadyToSign) { _, isReady in
            isReady
        }
        .onChange(of: scenePhase, initial: true, refresh)
        // Apple tells whether the certificate was revoked, and when an
        // imported one expires.
        .task(id: connection.certificateVersion) {
            await connection.checkCertificateIfNeeded()
        }
    }

    private var message: String {
        if connection.isReadyToSign {
            "ryc0.onboarding.connect.connected".loc
        } else if connection.validity == .revoked {
            "ryc0.settings.signing.revokedNotice".loc
        } else if connection.isExpired {
            "ryc0.settings.signing.expiredNotice".loc
        } else if connection.problem != nil || connection.isSameTeam == false {
            "ryc0.onboarding.connect.problem".loc
        } else if connection.hasCertificate {
            "ryc0.onboarding.connect.checking".loc
        } else {
            "ryc0.onboarding.connect.notConnected".loc
        }
    }

    /// The certificate's team and expiry, or what's wrong with it.
    private var certificateDetail: String {
        if let problem = connection.problem {
            problem
        } else if connection.validity == .revoked {
            "ryc0.settings.attention.revoked".loc
        } else if connection.hasCertificate {
            connection.summary
        } else {
            "ryc0.settings.signing.noCertificate".loc
        }
    }

    private var teamDetail: String {
        let unknown = "lc.common.unknown".loc
        switch connection.isSameTeam {
        case true?:
            return "ryc0.onboarding.connect.sameTeamMatch %@".localizeWithFormat(connection.teamID ?? unknown)
        case false?:
            let certificateTeam = connection.teamID ?? unknown
            return "ryc0.onboarding.connect.sameTeamMismatch %@ %@".localizeWithFormat(certificateTeam, connection.ownTeamID ?? unknown)
        case nil:
            return connection.hasCertificate
                ? "ryc0.onboarding.connect.sameTeamReading".loc
                : "ryc0.onboarding.connect.sameTeamUnknown".loc
        }
    }

    /// Reads the checklist again when ryC0 comes to the front.
    private func refresh() {
        guard scenePhase == .active else { return }
        connection.reload()
    }

    private func continueTapped() {
        flow.advance(from: .connect)
    }

    private func skip() {
        flow.skip(.connect, hasCertificate: connection.hasCertificate)
    }
}

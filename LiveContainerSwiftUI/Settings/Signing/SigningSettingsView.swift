//
//  SigningSettingsView.swift
//  LiveContainerSwiftUI
//

import SwiftUI

struct SigningSettingsView: View {
    @Environment(SigningStatus.self) private var connection

    var body: some View {
        List {
            Section {
                SigningHeader()
            }
            .listRowBackground(Color.clear)

            if let attention = connection.attention {
                SigningNoticeSection(attention: attention)
            }

            if connection.hasCertificate {
                SigningCertificateSection()
            }

            SigningSetupSection()

            if connection.isSecondary {
                Section {
                    Text("lc.settings.multiLCIsSecond".loc)
                        .foregroundStyle(.secondary)
                }
            } else {
                SigningCertificateActions()
            }
        }
        .listSectionSpacing(.compact)
        .navigationTitle("ryc0.settings.signing".loc)
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.success, trigger: connection.certificateVersion)
        .onAppear(perform: connection.reload)
        .task(id: connection.certificateVersion) {
            await connection.checkCertificateIfNeeded()
        }
    }
}

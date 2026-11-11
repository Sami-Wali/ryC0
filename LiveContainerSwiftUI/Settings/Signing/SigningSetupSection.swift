//
//  SigningSetupSection.swift
//  LiveContainerSwiftUI
//

import SwiftUI

struct SigningSetupSection: View {
    @Environment(SigningStatus.self) private var connection

    var body: some View {
        Section {
            ForEach(SigningSetupCheck.allCases, id: \.self) { check in
                SigningSetupRow(check: check, result: connection.result(for: check))
            }

            Button(action: checkSetup) {
                if connection.isCheckingSetup {
                    Label {
                        Text("ryc0.settings.setup.checking".loc)
                    } icon: {
                        ProgressView()
                    }
                } else {
                    Text("ryc0.settings.setup.check".loc)
                }
            }
            .disabled(connection.isCheckingSetup)
        } header: {
            Text("ryc0.settings.setup".loc)
        } footer: {
            Text("ryc0.settings.setup.footer".loc)
        }
    }

    private func checkSetup() {
        Task {
            await connection.checkSetup()
        }
    }
}

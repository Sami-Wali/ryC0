//
//  GeneralSettingsView.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// Settings > General, laid out like the General page of the Settings app:
/// plain rows for About ryC0 (the credits and licenses), the space the
/// apps take and the tools that tidy their data, and Reset.
struct GeneralSettingsView: View {
    @EnvironmentObject private var sharedModel: SharedModel

    var body: some View {
        List {
            Section {
                NavigationLink {
                    LCAboutView()
                } label: {
                    LabeledContent("ryc0.settings.about".loc, value: Self.version)
                }
            } footer: {
                Text("lc.settings.warning".loc)
            }

            Section {
                // A second ryC0 keeps no apps of its own to measure.
                if sharedModel.multiLCStatus != 2 {
                    NavigationLink {
                        LCStorageManagementView()
                    } label: {
                        Text("ryc0.settings.storage".loc)
                    }
                }

                NavigationLink {
                    LCDataManagementView()
                } label: {
                    Text("lc.settings.dataManagement".loc)
                }
            }

            Section {
                NavigationLink {
                    ResetSettingsView()
                } label: {
                    Text("lc.common.reset".loc)
                }
            }
        }
        .navigationTitle("ryc0.settings.general".loc)
        .navigationBarTitleDisplayMode(.inline)
    }

    /// ryC0's version, as About shows it in full.
    private static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }
}

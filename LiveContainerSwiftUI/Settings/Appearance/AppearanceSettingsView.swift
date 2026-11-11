//
//  AppearanceSettingsView.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// Settings for returning from apps and for the launcher’s icons.
struct AppearanceSettingsView: View {
    @AppStorage(HomeIconStyle.storageKey, store: LCUtils.appGroupUserDefault) private var iconStyle = HomeIconStyle.automatic
    @AppStorage(LCGuestHomeControlKey) private var homeControl = LCGuestHomeControl.bar

    var body: some View {
        List {
            Section {
                Picker("ryc0.homeReturn.title".loc, selection: $homeControl) {
                    Text("ryc0.homeReturn.bar".loc).tag(LCGuestHomeControl.bar)
                    Text("ryc0.homeReturn.floating".loc).tag(LCGuestHomeControl.floatingButton)
                    Text("ryc0.homeReturn.clock".loc).tag(LCGuestHomeControl.clock)
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } header: {
                Text("ryc0.homeReturn.title".loc)
            }

            if #available(iOS 18.0, *) {
                Section {
                    Picker("ryc0.settings.appearance.iconStyle".loc, selection: $iconStyle) {
                        ForEach(HomeIconStyle.allCases) { style in
                            Text(style.title)
                                .tag(style)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } header: {
                    Text("ryc0.settings.appearance.iconStyle".loc)
                } footer: {
                    Text("ryc0.settings.appearance.iconStyleFooter".loc)
                }
            }

            if UIApplication.shared.supportsAlternateIcons && DataManager.shared.model.multiLCStatus != 2 {
                Section {
                    AppIconPicker()
                } header: {
                    Text("ryc0.settings.appIcon".loc)
                } footer: {
                    Text("ryc0.settings.appIconFooter".loc)
                }
            }
        }
        .navigationTitle("ryc0.settings.appearance".loc)
        .navigationBarTitleDisplayMode(.inline)
    }
}

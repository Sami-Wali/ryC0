//
//  SettingsAddAppRow.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// Settings' Add App row, under Apps. It installs an app from an IPA in Files
/// or from a link, as the Home Screen's add button does, through the same
/// install. Settings closes first, so Files or the link question open over
/// the Home Screen, where the new app shows as it installs.
struct SettingsAddAppRow: View {
    @Environment(HomeScreenModel.self) private var model

    var body: some View {
        Menu {
            Button("lc.appList.installFromIpa".loc, systemImage: "doc.badge.plus", action: addFromFiles)
            Button("lc.appList.installFromUrl".loc, systemImage: "link.badge.plus", action: addFromLink)
        } label: {
            SettingsRow(title: "ryc0.home.addApp".loc, systemImage: "plus", color: .green)
        }
        // A menu's label takes the accent color; a Settings row's name doesn't.
        .tint(Color.primary)
        .disabled(model.coordinator.isInstalling)
    }

    private func addFromFiles() {
        model.addApp(.ipaFile)
    }

    private func addFromLink() {
        model.addApp(.link)
    }
}

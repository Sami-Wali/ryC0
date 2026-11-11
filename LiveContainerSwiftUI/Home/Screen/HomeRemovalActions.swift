//
//  HomeRemovalActions.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The choices before an app is deleted. An app with containers can be
/// deleted with its data, or with its data kept for when it comes back; one
/// without containers is simply deleted.
struct HomeRemovalActions: View {
    /// The app to delete.
    let app: LCAppModel

    @Environment(HomeScreenModel.self) private var model

    var body: some View {
        if app.uiContainers.isEmpty {
            Button("ryc0.home.deleteApp".loc, role: .destructive, action: deleteAppAndData)
        } else {
            Button("ryc0.home.deleteAppAndData".loc, role: .destructive, action: deleteAppAndData)
            Button("ryc0.home.deleteAppKeepData".loc, action: deleteAppKeepingData)
        }
        Button("lc.common.cancel".loc, role: .cancel) { }
    }

    private func deleteAppAndData() {
        model.removeApp(app, deletingData: true)
    }

    private func deleteAppKeepingData() {
        model.removeApp(app, deletingData: false)
    }
}

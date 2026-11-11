//
//  AddToHomeScreenButton.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// Add to Home Screen, in the toolbar of an app's settings: opens the sheet
/// that puts the app on the iPhone's own Home Screen, through
/// AppShortcutPresenter, its icon in the style ryC0's Home Screen shows
/// it in.
struct AddToHomeScreenButton: View {
    @ObservedObject var app: LCAppModel

    @Environment(\.prefersDarkAppIcons) private var darkModeIcon
    /// The app asked to go on the Home Screen, for AppShortcutPresenter.
    @State private var request: AppShortcutRequest?

    var body: some View {
        Button("lc.appBanner.addToHomeScreen".loc, systemImage: "plus.app", action: add)
            .appShortcutPresenter($request)
    }

    private func add() {
        request = AppShortcutRequest(app: app, style: darkModeIcon ? .Dark : .Light)
    }
}

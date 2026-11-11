//
//  AppShortcutPresenter.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// Puts the app a request names on the iPhone's own Home Screen, over the view
/// it's applied to, through Add to Home Screen's sheet: how the icon opens
/// the app, then the web clip's profile in Safari, which iOS has the person
/// allow and install in Settings. An app's settings and the Home Screen's
/// long-press menu both add apps through it.
struct AppShortcutPresenter: ViewModifier {
    /// The app asked to go on the Home Screen. It's taken as soon as it's set.
    @Binding var request: AppShortcutRequest?

    /// The request the sheet is showing.
    @State private var shownRequest: AppShortcutRequest?

    func body(content: Content) -> some View {
        content
            .onChange(of: request) { _, request in
                guard let request else {
                    return
                }
                self.request = nil
                shownRequest = request
            }
            .sheet(item: $shownRequest) { request in
                AddToHomeScreenSheet(request: request)
            }
    }
}

extension View {
    /// Puts the apps asked for through `request` on the iPhone's Home Screen,
    /// over this view.
    func appShortcutPresenter(_ request: Binding<AppShortcutRequest?>) -> some View {
        modifier(AppShortcutPresenter(request: request))
    }
}

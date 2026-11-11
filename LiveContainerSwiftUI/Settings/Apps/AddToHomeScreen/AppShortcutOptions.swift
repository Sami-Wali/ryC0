//
//  AppShortcutOptions.swift
//  LiveContainerSwiftUI
//

import Foundation

/// How an icon on the iPhone's own Home Screen opens its app, as Add to Home
/// Screen's sheet asks before it makes the web clip: the name under the icon,
/// the container the app opens in, and whether it opens with JIT.
struct AppShortcutOptions: Equatable {
    /// The name under the icon. When it's left empty, the icon has the app's
    /// own name.
    var name: String
    /// The container the app opens in, or nil for an app that has none yet,
    /// which gets one when it first opens.
    var containerFolderName: String?
    /// Whether the icon opens the app with JIT, as Open with JIT does. An app
    /// that always opens with JIT does so from the icon too, whatever this
    /// says.
    var opensWithJIT: Bool

    /// What the sheet starts from for an app: its own name, its default
    /// container, and JIT only as the app itself asks for it.
    init(app: LCAppModel) {
        name = app.appInfo.displayName() ?? ""
        containerFolderName = app.uiSelectedContainer?.folderName
        opensWithJIT = false
    }
}

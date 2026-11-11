//
//  AppReplaceOption.swift
//  LiveContainerSwiftUI
//

/// One way to finish installing an app when an app with the same bundle ID is
/// already installed: as a new app in a folder of its own, or in place of one
/// of the installed copies.
struct AppReplaceOption: Hashable, Identifiable {
    /// Whether the new app takes the place of `appToReplace`.
    let isReplace: Bool
    /// The folder the new app goes into, inside the Applications folder.
    let nameOfFolderToInstall: String
    /// The installed copy this option replaces, when it replaces one.
    var appToReplace: LCAppModel?

    /// Each option installs into a folder of its own, so the folder names it.
    var id: String { nameOfFolderToInstall }
}

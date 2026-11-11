//
//  AppLaunchCoordinator+GuestURLSchemes.swift
//  LiveContainerSwiftUI
//

import Foundation

/// The URL schemes of the apps on the Home Screen, which the guest hook reads
/// (`LCGuestURLSchemes`) to send links for them back to ryC0.
extension AppLaunchCoordinator {
    /// Writes the schemes down again from the apps on the Home Screen, the way
    /// launch does, after an app is installed, replaced, removed, hidden or
    /// shown. Hidden apps' schemes don't count. A secondary ryC0 leaves
    /// the list to the primary one.
    func refreshGuestURLSchemes() {
        guard sharedModel.multiLCStatus != 2 else {
            return
        }
        var schemes = Set<String>()
        for app in sharedModel.apps {
            schemes.formUnion(app.appInfo.urlSchemes() as? [String] ?? [])
        }
        UserDefaults.lcShared().set(Array(schemes), forKey: "LCGuestURLSchemes")
    }
}

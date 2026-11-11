//
//  AppInstallError.swift
//  LiveContainerSwiftUI
//

import Foundation

/// Why an install stopped before it changed anything.
enum AppInstallError: LocalizedError, Equatable {
    /// The app to replace is open, in ryC0, in a multitasking window or
    /// in another ryC0. Replacing it would pull its files from under it.
    case running(appName: String)
    case bundleMismatch(expected: String, found: String)
    /// The IPA's bundle ID can't name a folder: it's empty or too long, holds
    /// a slash, a colon or a NUL, or starts with a dot.
    case invalidBundleIdentifier

    var errorDescription: String? {
        switch self {
        case .running(let appName):
            "ryc0.update.running %@".localizeWithFormat(appName)
        case let .bundleMismatch(expected, found):
            "ryc0.install.bundleMismatch %@ %@".localizeWithFormat(expected, found)
        case .invalidBundleIdentifier:
            "lc.appList.infoPlistCannotReadError".loc
        }
    }
}

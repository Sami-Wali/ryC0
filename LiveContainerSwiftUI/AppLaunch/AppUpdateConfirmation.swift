//
//  AppUpdateConfirmation.swift
//  LiveContainerSwiftUI
//

import Foundation

struct AppUpdateConfirmation: Equatable {
    /// Whether the new copy is newer, older or the same version.
    let kind: AppUpdateConfirmationKind
    /// The installed app's name.
    let appName: String
    /// The installed version as the question names it, like "1.2", or
    /// "1.2 (5)" when only the builds tell the two copies apart.
    let installedVersion: String
    /// The new copy's version, named the same way.
    let incomingVersion: String

    /// Works out the question from the two copies' versions and builds
    /// (CFBundleVersion), a build being nil when the app has none.
    init(appName: String, installedVersion: String, installedBuild: String?, incomingVersion: String, incomingBuild: String?) {
        self.appName = appName
        kind = Self.kind(of: incomingVersion, build: incomingBuild, against: installedVersion, build: installedBuild)

        let sameVersion = AppVersionOrder.compare(version: incomingVersion, build: nil, with: installedVersion, build: nil) == .orderedSame
        if sameVersion, let installedBuild, let incomingBuild,
           AppVersionOrder.compare(version: incomingBuild, build: nil, with: installedBuild, build: nil) != .orderedSame {
            self.installedVersion = "\(installedVersion) (\(installedBuild))"
            self.incomingVersion = "\(incomingVersion) (\(incomingBuild))"
        } else {
            self.installedVersion = installedVersion
            self.incomingVersion = incomingVersion
        }
    }

    /// The question, like "Update Delta 1.2 to 1.3?".
    var title: String {
        switch kind {
        case .update:
            "ryc0.update.title %@ %@ %@".localizeWithFormat(appName, installedVersion, incomingVersion)
        case .downgrade:
            "ryc0.update.downgradeTitle %@ %@ %@".localizeWithFormat(appName, installedVersion, incomingVersion)
        case .reinstall:
            "ryc0.update.reinstallTitle %@ %@".localizeWithFormat(appName, incomingVersion)
        }
    }

    /// What the replacement keeps, and for a downgrade what it may cost.
    var message: String {
        switch kind {
        case .update, .reinstall:
            "ryc0.update.message %@".localizeWithFormat(appName)
        case .downgrade:
            "ryc0.update.downgradeMessage %@ %@".localizeWithFormat(incomingVersion, appName)
        }
    }

    /// The button that goes ahead: Update, Replace or Reinstall.
    var confirmTitle: String {
        switch kind {
        case .update:
            "ryc0.update.confirm".loc
        case .downgrade:
            "ryc0.update.downgradeConfirm".loc
        case .reinstall:
            "ryc0.update.reinstallConfirm".loc
        }
    }

    /// Whether going ahead can cost the app its data, as a downgrade can, so
    /// the button shows in red.
    var isDestructive: Bool {
        kind == .downgrade
    }

    /// Whether the new copy is an update, a downgrade or a reinstall.
    private static func kind(of incomingVersion: String, build incomingBuild: String?,
                             against installedVersion: String, build installedBuild: String?) -> AppUpdateConfirmationKind {
        switch AppVersionOrder.compare(version: incomingVersion, build: incomingBuild, with: installedVersion, build: installedBuild) {
        case .orderedDescending:
            .update
        case .orderedAscending:
            .downgrade
        case .orderedSame:
            .reinstall
        }
    }
}

//
//  AppShortcuts.swift
//  LiveContainerSwiftUI
//

import UIKit

/// Makes what puts an app inside ryC0 on the iPhone's own Home Screen:
/// a configuration profile with a web clip, whose icon opens the app in
/// ryC0 the way Add to Home Screen's sheet says. Icons have ryC0's
/// frame around them when Frame Shortcut Icons is on.
@MainActor
enum AppShortcuts {
    /// The profile as a data link Safari offers to download, which Settings
    /// then installs.
    static func webClipLink(for app: LCAppModel, options: AppShortcutOptions, style: GeneratedIconStyle) throws -> URL {
        let profile = try profile(for: app, options: options, style: style)
        let data = try PropertyListSerialization.data(fromPropertyList: profile, format: .xml, options: 0)
        guard let link = URL(string: "data:application/x-apple-aspen-config;base64,\(data.base64EncodedString())") else {
            throw CocoaError(.propertyListWriteInvalid)
        }
        return link
    }

    /// The link the icon opens, which ryC0 reads as an AppLink, as an
    /// app running in ryC0 does too: the app's folder, its container,
    /// and `jit=true` when the icon opens it with JIT.
    static func launchLink(for app: LCAppModel, options: AppShortcutOptions) throws -> URL {
        var items = [URLQueryItem(name: "bundle-name", value: app.appInfo.relativeBundlePath)]
        if let containerFolderName = options.containerFolderName {
            items.append(URLQueryItem(name: "container-folder-name", value: containerFolderName))
        }
        if options.opensWithJIT {
            items.append(URLQueryItem(name: "jit", value: "true"))
        }
        var components = URLComponents()
        components.scheme = LCSharedUtils.hostAppUrlScheme()
        components.host = "livecontainer-launch"
        components.queryItems = items
        guard let link = components.url else {
            throw CocoaError(.propertyListWriteInvalid)
        }
        return link
    }

    /// The profile: one full screen web clip, with the icon and the name the
    /// Home Screen shows. It has no consent text, which would add a page to
    /// the install in Settings.
    private static func profile(for app: LCAppModel, options: AppShortcutOptions, style: GeneratedIconStyle) throws -> [String: Any] {
        let appName = app.appInfo.displayName() ?? ""
        let trimmedName = options.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = trimmedName.isEmpty ? appName : trimmedName
        guard let icon = app.appInfo.generateLiveContainerWrappedIcon(with: style)?.pngData() else {
            throw CocoaError(.propertyListWriteInvalid)
        }
        let summaryKey = options.opensWithJIT ? "ryc0.shortcut.profileSummaryJIT %@" : "ryc0.shortcut.profileSummary %@"
        let summary = summaryKey.localizeWithFormat(appName)
        // Each way of opening an app gets a profile of its own, so adding an
        // app again the same way replaces its icon, while an icon that opens
        // it another way, such as with JIT, goes beside it.
        let identifier = [Bundle.main.bundleIdentifier, app.appInfo.bundleIdentifier() ?? "app", options.containerFolderName, options.opensWithJIT ? "jit" : nil]
            .compactMap { $0 }
            .joined(separator: ".")
        let webClip: [String: Any] = [
            "FullScreen": true,
            "Icon": icon,
            "IgnoreManifestScope": true,
            "IsRemovable": true,
            "Label": name,
            "PayloadDescription": summary,
            "PayloadDisplayName": name,
            "PayloadIdentifier": "\(identifier).webclip",
            "PayloadType": "com.apple.webClip.managed",
            "PayloadUUID": UUID().uuidString,
            "PayloadVersion": 1,
            "Precomposed": false,
            "URL": try launchLink(for: app, options: options).absoluteString,
        ]
        return [
            "PayloadContent": [webClip],
            "PayloadDescription": summary,
            "PayloadDisplayName": name,
            "PayloadIdentifier": identifier,
            "PayloadOrganization": "ryC0",
            "PayloadRemovalDisallowed": false,
            "PayloadType": "Configuration",
            "PayloadUUID": UUID().uuidString,
            "PayloadVersion": 1,
        ]
    }
}

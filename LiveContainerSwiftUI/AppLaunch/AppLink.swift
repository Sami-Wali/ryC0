//
//  AppLink.swift
//  LiveContainerSwiftUI
//

import Foundation

enum AppLink: Equatable {
    case install(String)

    /// Launches the app installed in the folder `bundleName`, from
    /// `ryc0://livecontainer-launch?bundle-name=<folder>`. The link may
    /// also name the container to use (`container-folder-name`), a URL for the
    /// app to open (`open-url`, Base64) and whether to wait for JIT (`jit`).
    case launch(bundleName: String, containerFolderName: String?, url: String?, forceJIT: Bool?)

    /// Opens a URL in the app that handles it, or a web page in the built-in
    /// browser, from `open-url` and `open-web-page` links. Their first query
    /// item holds the URL in Base64.
    case openURL(String)

    /// Reads the link from a URL ryC0 was opened with. Returns nil for
    /// links that aren't app links, for app links that ask for nothing, such
    /// as `livecontainer-launch?bundle-name=ui`, which only brings up
    /// ryC0, and for install links naming an address
    /// `InstallLinkPolicy` turns away.
    init?(url: URL) {
        if url.isFileURL {
            self = .install(url.absoluteString)
            return
        }
        let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        switch url.host?.lowercased() {
        case "open-web-page", "open-url":
            guard let encoded = queryItems.first?.value, !encoded.isEmpty,
                  let target = Self.decodeBase64(encoded) else {
                return nil
            }
            self = .openURL(target)
        case "livecontainer-launch":
            var bundleName: String?
            var containerFolderName: String?
            var target: String?
            var forceJIT: Bool?
            for item in queryItems {
                switch item.name {
                case "bundle-name":
                    bundleName = item.value ?? bundleName
                case "container-folder-name":
                    containerFolderName = item.value ?? containerFolderName
                case "jit":
                    forceJIT = switch item.value {
                    case "true": true
                    case "false": false
                    default: forceJIT
                    }
                case "open-url":
                    target = item.value.flatMap(Self.decodeBase64) ?? target
                default:
                    break
                }
            }
            guard let bundleName, !bundleName.isEmpty, bundleName != "ui" else {
                return nil
            }
            self = .launch(bundleName: bundleName, containerFolderName: containerFolderName, url: target, forceJIT: forceJIT)
        case "install":
            guard let source = LCSharedUtils.installSourceURL(from: url),
                  InstallLinkPolicy.accepts(installSource: source) else {
                return nil
            }
            self = .install(source.absoluteString)
        default:
            return nil
        }
    }

    /// The UTF-8 text a Base64 query value holds, or nil when it holds none.
    private static func decodeBase64(_ value: String) -> String? {
        guard let data = Data(base64Encoded: value) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
}

//
//  HomeRoute.swift
//  LiveContainerSwiftUI
//

import Foundation

/// Where a URL ryC0 was opened with goes. HomeRouter reads it with
/// `init(url:)` and sends it on; the root view can also follow it, for example
/// by showing the screen it concerns.
enum HomeRoute: Equatable {
    /// Brings up ryC0's own screens and nothing else, as
    /// `livecontainer-launch?bundle-name=ui` asks, or an app link that names
    /// nothing to do.
    case home

    /// Asks the user before scheduling a fixed local test notification for ryP0.
    case ryP0NotificationTest

    /// Installs, launches or opens something in an app, which
    /// AppLaunchCoordinator does.
    case app(AppLink)

    /// Stores a signing certificate, from `certificate?cert=&password=`, once
    /// the person says to use it.
    case certificate(CertificateLink)

    /// Stores the signing certificate in a .p12 (or .pfx) file ryC0 was
    /// asked to open, once the person types its password and says to use it.
    case certificateFile(URL)

    /// Reads the route from a URL ryC0 was opened with, either a link
    /// with its own scheme or a file it was asked to open. Returns nil for URLs
    /// ryC0 doesn't handle.
    init?(url: URL) {
        // Any other file ryC0 is asked to open is taken for an IPA.
        if url.isFileURL, Self.certificateFileExtensions.contains(url.pathExtension.lowercased()) {
            self = .certificateFile(url)
            return
        }
        if let link = AppLink(url: url) {
            self = .app(link)
            return
        }
        switch url.host?.lowercased() {
        case "ryp0-notification-test":
            guard url.scheme?.lowercased() == LCSharedUtils.hostAppUrlScheme().lowercased(),
                  url.user == nil, url.password == nil, url.port == nil,
                  url.path.isEmpty, url.query == nil, url.fragment == nil else { return nil }
            self = .ryP0NotificationTest
        case "livecontainer-launch", "install", "open-web-page", "open-url":
            self = .home
        case "certificate":
            guard let link = CertificateLink(url: url) else {
                return nil
            }
            self = .certificate(link)
        default:
            return nil
        }
    }

    /// The extensions of the PKCS #12 files a certificate comes in.
    private static let certificateFileExtensions: Set<String> = ["p12", "pfx"]

}

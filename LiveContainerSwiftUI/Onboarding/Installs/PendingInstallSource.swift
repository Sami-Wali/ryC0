//
//  PendingInstallSource.swift
//  LiveContainerSwiftUI
//

import Foundation

/// Where an app waiting in PendingInstallQueue came from.
enum PendingInstallSource: Equatable {
    case link(URL)

    /// An IPA opened with ryC0 or shared to it. It may need a bookmark
    /// or security-scoped access to read, which the install takes care of.
    case openedFile(URL)

    /// An IPA picked in Files, which Files copied for ryC0.
    case pickedFile(URL)


    var isOwnCopy: Bool {
        switch self {
        case .link, .pickedFile:
            true
        case .openedFile:
            false
        }
    }

    var name: String {
        switch self {
        case .link(let url):
            if Self.isIPA(url) {
                url.deletingPathExtension().lastPathComponent
            } else {
                url.host ?? url.absoluteString
            }
        case .openedFile(let url), .pickedFile(let url):
            url.deletingPathExtension().lastPathComponent
        }
    }

    /// The name to save a link's download under: its own when it names an
    /// IPA and can only name a file in the app's folder, or a stand-in,
    /// since the install reads the file whatever it's called. The address's
    /// last path component is percent-decoded, so `..%2F..%2Fx.ipa` reads as
    /// `../../x.ipa` and gets the stand-in.
    static func downloadName(for url: URL) -> String {
        let name = url.lastPathComponent
        return isFileName(name) && isIPA(url) ? name : "App.ipa"
    }

    /// Whether a name read from an address or a record names a file right
    /// inside a folder and nothing else: a single path component that isn't
    /// empty, doesn't start with a dot (which also rules out `.` and `..`),
    /// holds no NUL, and fits the file system's 255 bytes.
    static func isFileName(_ name: String) -> Bool {
        !name.isEmpty
            && !name.hasPrefix(".")
            && !name.contains("/")
            && !name.contains("\0")
            && name.utf8.count <= 255
    }

    private static func isIPA(_ url: URL) -> Bool {
        ["ipa", "tipa"].contains(url.pathExtension.lowercased())
    }

}

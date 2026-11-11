//
//  InstallLinkPolicy.swift
//  LiveContainerSwiftUI
//

import Foundation

/// Which addresses an install link may name. Any app or website can open an
/// install link, so a link may name a web address, which ryC0 downloads
/// into a folder of its own, but a file only when the person just shared it to
/// ryC0: the file the share extension bookmarked before it opened the
/// link, or a file iOS put in the Inbox. Any other file, and any other scheme,
/// is turned away, so a link can't install a file that just happens to be on
/// this iPhone.
enum InstallLinkPolicy {
    /// Whether an install link's `url` value names something ryC0 may
    /// install.
    static func accepts(installSource url: URL) -> Bool {
        // The shared link parser already checks the scheme and web host.
        guard url.isFileURL else {
            return true
        }
        let inbox = URL.documentsDirectory.appending(path: "Inbox", directoryHint: .isDirectory)
        return accepts(file: url, sharedFile: sharedFile(), inbox: inbox)
    }

    /// Whether a file URL names `sharedFile` or a file directly in `inbox`.
    static func accepts(file: URL, sharedFile: URL?, inbox: URL) -> Bool {
        guard let path = normalizedPath(of: file) else {
            return false
        }
        if let sharedFile, normalizedPath(of: sharedFile) == path {
            return true
        }
        let folder = URL(fileURLWithPath: path).deletingLastPathComponent()
        return normalizedPath(of: folder) == normalizedPath(of: inbox)
    }

    /// The share extension's bookmark, and the file it finds, when that's
    /// `file`. An IPA shared to ryC0 is read through it. Nil when
    /// there's none, or when it finds another file, such as one shared
    /// earlier, since only a guest app opening a shared file clears it.
    static func sharedFileBookmark(for file: URL) -> (bookmark: Data, url: URL)? {
        guard let bookmark = LCUtils.appGroupUserDefault.data(forKey: "LCLaunchExtensionFileBookmark"),
              let sharedFile = try? LCUtils.resolveSecurityScopedBookmark(bookmark),
              let path = normalizedPath(of: file),
              normalizedPath(of: sharedFile) == path else {
            return nil
        }
        return (bookmark, sharedFile)
    }

    /// The file the share extension bookmarked for ryC0 to install, as
    /// `installLocalIpa(_:policy:)` finds it, or nil when there's none.
    private static func sharedFile() -> URL? {
        guard let bookmark = LCUtils.appGroupUserDefault.data(forKey: "LCLaunchExtensionFileBookmark") else {
            return nil
        }
        return try? LCUtils.resolveSecurityScopedBookmark(bookmark)
    }

    /// A file URL's path with its percent escapes decoded, `.` and `..`
    /// resolved and "/private" taken off "/private/var", so the paths iOS
    /// hands out for one file compare equal. Nil for a path that isn't
    /// absolute or holds a NUL.
    private static func normalizedPath(of url: URL) -> String? {
        // Every escape decoded first, so an escaped slash, dot or NUL can't
        // hide a "..".
        let decoded = url.path(percentEncoded: false)
        guard decoded.hasPrefix("/"), !decoded.contains("\0") else {
            return nil
        }
        let path = URL(fileURLWithPath: decoded).standardizedFileURL.path(percentEncoded: false)
        if path.hasPrefix("/private/var/") {
            return String(path.dropFirst("/private".count))
        }
        return path
    }
}

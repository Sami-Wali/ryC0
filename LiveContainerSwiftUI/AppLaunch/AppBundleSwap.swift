//
//  AppBundleSwap.swift
//  LiveContainerSwiftUI
//

import Foundation

/// Replaces an installed app's folder in one step, so the folder always holds
/// one whole app with the settings that link it to its data.
///
/// The new app waits beside the old one as `FOLDER.ryc0new`, where it gets the
/// old app's settings and saves them. Then the two folders swap places
/// (`renamex_np` with `RENAME_SWAP`), and the `.ryc0new` folder, which now
/// holds the old app, moves to tmp and is deleted there in the background.
/// Whenever ryC0 stops, the folder holds either the old app or the new
/// one with its settings, and `recover(in:)` clears away what's left at the
/// next launch. No scan of the Applications folders takes a `.ryc0new` folder
/// for an app, since its name doesn't end in `.app`.
enum AppBundleSwap {
    /// What the name of a folder waiting to be swapped in ends in.
    static let stagedSuffix = ".ryc0new"

    /// Where the new app waits before it's swapped into `destination`.
    static func stagedURL(for destination: URL) -> URL {
        destination.deletingLastPathComponent()
            .appending(path: destination.lastPathComponent + stagedSuffix, directoryHint: .isDirectory)
    }

    /// Swaps the app waiting in `staged` into `destination`, then moves the
    /// old app, which the swap leaves in `staged`, to tmp and deletes it there
    /// in the background, without waiting for it. One that can't be moved is
    /// deleted where it is, off the main actor. When the swap fails, nothing
    /// has changed: the old app is still in `destination`, and the new one in
    /// `staged`.
    ///
    /// The swap itself runs on the caller's actor, so nothing the main actor
    /// does gets between a check the caller just made, such as that the app
    /// isn't open, and the swap.
    nonisolated(nonsending) static func swap(staged: URL, into destination: URL) async throws {
        let code = staged.withUnsafeFileSystemRepresentation { stagedPath in
            destination.withUnsafeFileSystemRepresentation { destinationPath -> Int32 in
                guard let stagedPath, let destinationPath else {
                    return EINVAL
                }
                return renamex_np(stagedPath, destinationPath, UInt32(RENAME_SWAP)) == 0 ? 0 : errno
            }
        }
        guard code == 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: code) ?? .EIO)
        }
        // The old app moves to tmp in one rename and is deleted in the
        // background, so the install doesn't wait for it. A copy left behind
        // takes space, nothing more: the next launch deletes it.
        if let removing = AppLaunchCoordinator.moveToTmp(staged) {
            Task.detached(priority: .utility) {
                try? FileManager().removeItem(at: removing)
            }
        } else {
            await remove(staged)
        }
    }

    /// Deletes a folder that waits to be swapped, off the main actor, since an
    /// app can hold thousands of files. One that can't be deleted stays, for
    /// `recover(in:)`.
    @concurrent
    static func remove(_ url: URL) async {
        try? FileManager().removeItem(at: url)
    }

    /// Clears away every folder in `folder` that waits to be swapped: a new
    /// app whose swap never happened, or an old app a swap left behind. Each
    /// moves to tmp in one rename, so launch doesn't wait for thousands of
    /// files, and one that can't be moved is deleted where it is. It's safe
    /// before and after a swap, so it runs at launch, before the apps are
    /// read.
    ///
    /// What moves to tmp is deleted by AppLaunchCoordinator, which
    /// LiveContainerSwiftUIApp.init creates after this runs, so this has to
    /// run before it.
    static func recover(in folder: URL) {
        let fileManager = FileManager.default
        guard let names = try? fileManager.contentsOfDirectory(atPath: folder.path) else {
            return
        }
        for name in names where name.hasSuffix(stagedSuffix) || name.hasSuffix(".zcnew") {
            let url = folder.appending(path: name)
            if AppLaunchCoordinator.moveToTmp(url) == nil {
                try? fileManager.removeItem(at: url)
            }
        }
    }
}

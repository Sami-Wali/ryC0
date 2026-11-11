//
//  PendingInstallQueue.swift
//  LiveContainerSwiftUI
//

import Combine
import Foundation

@MainActor
@Observable
final class PendingInstallQueue {
    /// The apps, in the order they arrived.
    private(set) var items: [PendingInstall] = []
    /// Whether installs wait, as they do until onboarding reaches Add Apps.
    /// Downloads never wait.
    private(set) var holdsInstalls: Bool

    /// Whether a failure shows as an alert, as it does while no list shows
    /// it: once onboarding has closed.
    @ObservationIgnored private var reportsFailures: Bool
    /// Whether one of the apps is installing.
    @ObservationIgnored private var isInstalling = false
    @ObservationIgnored private let coordinator: AppLaunchCoordinator

    /// Brings back the apps that were still on their way in when ryC0
    /// last closed. Downloads that hadn't finished start again; the rest
    /// install now, or once onboarding reaches Add Apps.
    /// - Parameter holdsForOnboarding: Whether onboarding shows from the
    ///   start, so installs wait for it.
    init(coordinator: AppLaunchCoordinator, holdsForOnboarding: Bool) {
        self.coordinator = coordinator
        holdsInstalls = holdsForOnboarding
        reportsFailures = !holdsForOnboarding
        items = PendingInstallStore.restore()
        for item in items where item.state == .downloading {
            switch item.source {
            case .link(let url):
                Task {
                    await download(item, from: url)
                }
            case .openedFile, .pickedFile:
                break
            }
        }
        installNext()
    }

    /// Whether any app is still on its way in.
    var hasUnfinishedItems: Bool {
        items.contains { !$0.state.isFinished }
    }

    /// The names of the apps that were installed.
    var installedNames: [String] {
        items.filter { $0.state == .installed }.map(\.name)
    }

    /// How many apps were installed, which goes up by one with each.
    var installedCount: Int {
        items.count(where: { $0.state == .installed })
    }

    // MARK: Receiving

    /// Takes the IPA an install link points at: a web address, which starts
    /// downloading now, or a file opened with ryC0. Returns false for
    /// any other kind of link, which AppLaunchCoordinator handles as usual.
    func receive(address: String) -> Bool {
        guard let url = URL(string: address) else {
            return false
        }
        if url.isFileURL {
            add(PendingInstall(source: .openedFile(url), bookmark: Self.bookmark(forOpenedFile: url)))
            return true
        }
        guard ["http", "https"].contains(url.scheme?.lowercased() ?? "") else {
            return false
        }
        let item = PendingInstall(source: .link(url))
        add(item)
        Task {
            await download(item, from: url)
        }
        return true
    }

    /// Takes an IPA picked in Files, which Files copied for ryC0.
    func add(pickedFile url: URL) {
        let id = UUID()
        // Files copies into the temporary folder, which iOS may empty while
        // ryC0 is closed, so the copy moves in beside the downloads.
        let file = (try? PendingInstallStore.moveIn(url, for: id)) ?? url
        add(PendingInstall(id: id, source: .pickedFile(file)))
    }

    private func add(_ item: PendingInstall) {
        // Once onboarding has closed, no list shows the apps that are done
        // coming in, so they're let go rather than kept until it opens again.
        if reportsFailures {
            items.removeAll { $0.state.isFinished }
        }
        items.append(item)
        saveItems()
        installNext()
    }

    /// A bookmark that finds an opened IPA again if ryC0 closes before
    /// it's installed, and that installing it reads it through. One shared
    /// to ryC0 may be reachable only through the share extension's
    /// bookmark, when it names this file, which the item keeps its own copy
    /// of, since the next file shared replaces it.
    private static func bookmark(forOpenedFile url: URL) -> Data? {
        let isAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if isAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        if FileManager.default.isReadableFile(atPath: url.path), let bookmark = LCUtils.bookmark(for: url) {
            return bookmark
        }
        return InstallLinkPolicy.sharedFileBookmark(for: url)?.bookmark
    }

    /// Where an opened IPA can be read: where it is, when ryC0 can
    /// read it there, as it can a file in the Inbox, or else where its own
    /// security-scoped bookmark finds it, rather than the share extension's,
    /// which names only the file shared last.
    private static func reachableFile(_ file: URL, bookmark: Data?) -> URL {
        guard !FileManager.default.isReadableFile(atPath: file.path), let bookmark else {
            return file
        }
        return (try? LCUtils.resolveSecurityScopedBookmark(bookmark)) ?? file
    }

    // MARK: Onboarding

    /// Makes installs wait, and keeps failures for the list, as onboarding
    /// opens. Apps that finished coming in since it last closed aren't
    /// listed again.
    func holdForOnboarding() {
        holdsInstalls = true
        reportsFailures = false
        items.removeAll { $0.state.isFinished }
    }

    /// Lets the apps install, as onboarding reaches Add Apps.
    func startInstalling() {
        holdsInstalls = false
        installNext()
    }

    /// Lets the apps still coming in carry on after onboarding closes, with
    /// failures shown as alerts from now on. The list stays as it is while
    /// the last step fades away; `holdForOnboarding()` clears it.
    func onboardingDidClose() {
        reportsFailures = true
        startInstalling()
    }

    // MARK: Downloading

    /// Downloads a link's IPA into the app's own folder, the way installing
    /// from a link always does, with the progress on the app's row.
    private func download(_ item: PendingInstall, from url: URL) async {
        let downloader = DownloadHelper()
        // DownloadHelper reports its progress on the main queue.
        let progress = downloader.$downloadProgress.sink { [weak item] fraction in
            MainActor.assumeIsolated {
                item?.downloadProgressed(Double(fraction))
            }
        }
        defer { progress.cancel() }

        do {
            let folder = try PendingInstallStore.makeFolder(for: item.id)
            let destination = folder.appending(path: PendingInstallSource.downloadName(for: url), directoryHint: .notDirectory)
            try await downloader.download(url: url, to: destination)
            item.downloaded(to: destination)
            saveItems()
        } catch {
            PendingInstallStore.removeFolder(for: item.id)
            fail(item, because: "ryc0.onboarding.apps.downloadFailed %@".localizeWithFormat(error.localizedDescription))
        }
        installNext()
    }

    // MARK: Installing

    /// Installs the first app that's ready, unless installs wait or one is
    /// installing, then the next, until none is ready.
    private func installNext() {
        guard !holdsInstalls, !isInstalling,
              let item = items.first(where: { $0.state == .waiting }) else {
            return
        }
        isInstalling = true
        Task {
            await install(item)
            isInstalling = false
            installNext()
        }
    }

    private func install(_ item: PendingInstall) async {
        guard let storedFile = item.file else {
            item.finishInstalling(adding: nil)
            saveItems()
            return
        }
        await coordinator.waitForInstallTurn()
        guard !holdsInstalls, isQueued(item) else {
            return
        }
        item.startInstalling()
        saveItems()

        // An opened IPA may lie outside ryC0, as one shared to it does,
        // and only opens with access granted. It's found through its own
        // bookmark, since the share extension's names only the file shared last.
        let file = item.source.isOwnCopy ? storedFile : Self.reachableFile(storedFile, bookmark: item.bookmark)
        let isAccessing = !item.source.isOwnCopy && file.startAccessingSecurityScopedResource()
        do {
            let outcome = try await coordinator.installReceivedIPA(
                at: file,
                isOwnCopy: item.source.isOwnCopy,
                policy: .ask
            )
            item.finishInstalling(adding: outcome.app)
            saveItems()
        } catch {
            fail(item, because: error.localizedDescription)
        }
        if isAccessing {
            file.stopAccessingSecurityScopedResource()
        }
        // Only once the app no longer counts as on its way in, so the next
        // launch can't find it written down without its IPA.
        removeCopy(of: item, at: file)
    }

    private func removeCopy(of item: PendingInstall, at file: URL) {
        switch item.source {
        case .link, .pickedFile:
            try? FileManager.default.removeItem(at: file)
            PendingInstallStore.removeFolder(for: item.id)
        case .openedFile:
            break
        }
    }

    /// Marks an app as failed, and says so in an alert when no list shows it.
    private func fail(_ item: PendingInstall, because reason: String) {
        item.fail(reason)
        saveItems()
        if reportsFailures {
            coordinator.errorMessage = "ryc0.onboarding.apps.failedAlert %@ %@".localizeWithFormat(item.name, reason)
        }
    }

    /// Whether an app is still in the queue, rather than let go of.
    private func isQueued(_ item: PendingInstall) -> Bool {
        items.contains { $0.id == item.id }
    }

    /// Writes down the apps still on their way in.
    private func saveItems() {
        PendingInstallStore.save(items)
    }
}

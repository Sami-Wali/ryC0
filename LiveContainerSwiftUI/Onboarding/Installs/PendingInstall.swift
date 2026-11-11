//
//  PendingInstall.swift
//  LiveContainerSwiftUI
//

import Foundation

@MainActor
@Observable
final class PendingInstall: Identifiable {
    /// Also names the folder its IPA goes in, and its record.
    let id: UUID
    /// Where the app came from.
    let source: PendingInstallSource
    /// What to call the app until it's installed and its own name is known.
    let placeholderName: String

    /// How far it has come.
    private(set) var state: PendingInstallState
    /// How much of the IPA has downloaded, from 0 to 1.
    private(set) var downloadProgress = 0.0
    private(set) var downloadedBytes: Int64 = 0
    private(set) var totalBytes: Int64 = 0
    private(set) var isVerifying = false
    private(set) var installWarning: String?
    /// The app, once installed.
    private(set) var app: LCAppModel?

    /// The IPA on this iPhone, once it's there.
    @ObservationIgnored private(set) var file: URL?
    /// For an opened IPA, the bookmark that finds it again if ryC0
    /// closes before it's installed.
    let bookmark: Data?

    init(
        id: UUID = UUID(),
        source: PendingInstallSource,
        name: String? = nil,
        downloadedFile: URL? = nil,
        bookmark: Data? = nil
    ) {
        self.id = id
        self.source = source
        self.placeholderName = name ?? source.name
        self.bookmark = bookmark
        switch source {
        case .link:
            file = downloadedFile
            state = downloadedFile == nil ? .downloading : .waiting
            downloadProgress = downloadedFile == nil ? 0 : 1
        case .openedFile(let url), .pickedFile(let url):
            file = url
            state = .waiting
        }
    }

    /// The app's name: its own once installed, until then what the source
    /// called it.
    var name: String {
        app?.appInfo.displayName() ?? placeholderName
    }

    /// Notes how much of the IPA has downloaded.
    func downloadProgressed(_ fraction: Double) {
        downloadProgress = fraction.isFinite ? min(max(fraction, 0), 1) : 0
    }

    func receivedBytes(_ count: Int64, total: Int64) {
        downloadedBytes = max(0, count)
        totalBytes = max(0, total)
    }

    func verifying(_ active: Bool) { isVerifying = active }

    /// Notes that the IPA has downloaded, or been copied and checked, to
    /// `file`, ready to install.
    func downloaded(to file: URL) {
        self.file = file
        downloadProgress = 1
        state = .waiting
    }

    /// Notes that the install has started.
    func startInstalling() {
        state = .installing
    }

    /// Notes how the install ended: with the app it added, or nil when it
    /// added none.
    func finishInstalling(adding app: LCAppModel?, warning: String? = nil) {
        self.app = app
        installWarning = warning
        state = app == nil ? .notInstalled : .installed
    }

    /// Notes that the app couldn't come in, for this reason.
    func fail(_ reason: String) {
        state = .failed(reason)
    }
}

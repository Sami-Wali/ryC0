//
//  PendingInstallStore.swift
//  LiveContainerSwiftUI
//

import Foundation

@MainActor
enum PendingInstallStore {
    private static let root = URL.applicationSupportDirectory.appending(path: "ReceivedApps", directoryHint: .isDirectory)
    private static let manifestName = "Manifest.json"

    private static var manifest: URL {
        root.appending(path: manifestName, directoryHint: .notDirectory)
    }

    /// The folder an app's IPA goes in.
    static func folder(for id: UUID) -> URL {
        root.appending(path: id.uuidString, directoryHint: .isDirectory)
    }

    /// Makes the folder an app's IPA goes in, and returns it.
    static func makeFolder(for id: UUID) throws -> URL {
        try makeRoot()
        let folder = folder(for: id)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    /// Moves an IPA into its app's folder, and returns where it went.
    static func moveIn(_ file: URL, for id: UUID) throws -> URL {
        let destination = try makeFolder(for: id).appending(path: file.lastPathComponent, directoryHint: .notDirectory)
        try FileManager.default.moveItem(at: file, to: destination)
        return destination
    }

    /// Deletes an app's folder, with its IPA.
    static func removeFolder(for id: UUID) {
        try? FileManager.default.removeItem(at: folder(for: id))
    }

    /// Writes down the apps still on their way in, in place of the last list.
    static func save(_ items: [PendingInstall]) {
        let records = items.compactMap(record(for:))
        guard !records.isEmpty else {
            try? FileManager.default.removeItem(at: manifest)
            return
        }
        do {
            try makeRoot()
            try JSONEncoder().encode(records).write(to: manifest, options: .atomic)
        } catch {
            NSLog("[LC] Couldn't write down the apps on their way in: \(error)")
        }
    }

    static func restore() -> [PendingInstall] {
        let data = try? Data(contentsOf: manifest)
        let rawRecords = data.flatMap { (try? JSONSerialization.jsonObject(with: $0)) as? [[String: Any]] } ?? []
        let records = rawRecords.compactMap { record -> PendingInstallRecord? in
            guard let encoded = try? JSONSerialization.data(withJSONObject: record) else { return nil }
            return try? JSONDecoder().decode(PendingInstallRecord.self, from: encoded)
        }
        // Retire downloads created by the former catalog instead of retrying
        // them as ordinary links after their identity checks were removed.
        let oldCatalogIDs: Set<UUID> = data.flatMap {
            (try? JSONSerialization.jsonObject(with: $0)) as? [[String: Any]]
        }.map { records in
            Set(records.compactMap { record in
                guard record["catalogRequest"] is [String: Any], let id = record["id"] as? String else { return nil }
                return UUID(uuidString: id)
            })
        } ?? []
        let items = records.filter { !oldCatalogIDs.contains($0.id) }.compactMap(item(from:))
        removeFolders(keeping: Set(items.map(\.id.uuidString)))
        save(items)
        return items
    }

    /// Makes ReceivedApps, kept out of backups, since what's in it is gone
    /// once installed.
    private static func makeRoot() throws {
        guard !FileManager.default.fileExists(atPath: root.path) else {
            return
        }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        var folder = root
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? folder.setResourceValues(values)
    }

    /// Deletes everything in ReceivedApps but the manifest and the folders
    /// with these names.
    private static func removeFolders(keeping names: Set<String>) {
        let contents = (try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? []
        for url in contents where url.lastPathComponent != manifestName && !names.contains(url.lastPathComponent) {
            try? FileManager.default.removeItem(at: url)
        }
    }

    /// What's written down for an app, or nil for one that's done coming in,
    /// or an opened IPA with no bookmark to find it again.
    private static func record(for item: PendingInstall) -> PendingInstallRecord? {
        guard !item.state.isFinished else {
            return nil
        }
        switch item.source {
        case .link(let url):
            return PendingInstallRecord(
                id: item.id,
                kind: .link,
                name: item.placeholderName,
                state: item.state,
                address: url.absoluteString,
                fileName: item.file?.lastPathComponent
            )
        case .pickedFile(let file):
            return PendingInstallRecord(
                id: item.id,
                kind: .pickedFile,
                name: item.placeholderName,
                state: item.state,
                fileName: file.lastPathComponent
            )
        case .openedFile:
            guard let bookmark = item.bookmark else {
                return nil
            }
            return PendingInstallRecord(
                id: item.id,
                kind: .openedFile,
                name: item.placeholderName,
                state: item.state,
                bookmark: bookmark
            )

        }
    }

    private static func item(from record: PendingInstallRecord) -> PendingInstall? {
        guard !record.state.isFinished else {
            return nil
        }
        switch record.kind {
        case .link:
            guard let address = record.address, let url = URL(string: address) else {
                return nil
            }
            // DownloadHelper moves the IPA in only once all of it has come,
            // so one that's there is whole, even when ryC0 closed
            // before noting that it had downloaded.
            let file = file(for: record, otherwise: PendingInstallSource.downloadName(for: url))
            let isDownloaded = FileManager.default.fileExists(atPath: file.path)
            return PendingInstall(id: record.id, source: .link(url), name: record.name, downloadedFile: isDownloaded ? file : nil)
        case .pickedFile:
            guard let fileName = record.fileName else {
                return nil
            }
            let file = folder(for: record.id).appending(path: fileName, directoryHint: .notDirectory)
            guard FileManager.default.fileExists(atPath: file.path) else {
                return nil
            }
            return PendingInstall(id: record.id, source: .pickedFile(file), name: record.name)
        case .openedFile:
            var isStale = false
            guard let bookmark = record.bookmark,
                  let file = try? URL(resolvingBookmarkData: bookmark, bookmarkDataIsStale: &isStale) else {
                return nil
            }
            return PendingInstall(id: record.id, source: .openedFile(file), name: record.name, bookmark: bookmark)

        }
    }

    /// Where a record's IPA is in its app's folder: under the name the record
    /// gives, when that names a file right inside the folder, or else under
    /// `fallback`.
    private static func file(for record: PendingInstallRecord, otherwise fallback: String) -> URL {
        let name = record.fileName.flatMap { PendingInstallSource.isFileName($0) ? $0 : nil } ?? fallback
        return folder(for: record.id).appending(path: name, directoryHint: .notDirectory)
    }
}

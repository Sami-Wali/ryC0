import XCTest
@testable import LiveContainerSwiftUI

@MainActor final class BrandingIntegrationTests: XCTestCase {
    func testLegacyPreferencesKeepExistingRyC0Values() {
        let defaults = UserDefaults.standard
        let keys = ["ZCHasCompletedOnboarding", "RYC0HasCompletedOnboarding",
                    "ZCWallpaperDimmed", "RYC0WallpaperDimmed", "LCJITEnablerType"]
        let saved = keys.map { defaults.object(forKey: $0) }
        defer {
            for (key, value) in zip(keys, saved) {
                if let value { defaults.set(value, forKey: key) }
                else { defaults.removeObject(forKey: key) }
            }
        }
        defaults.set(true, forKey: "ZCHasCompletedOnboarding")
        defaults.removeObject(forKey: "RYC0HasCompletedOnboarding")
        defaults.set(false, forKey: "ZCWallpaperDimmed")
        defaults.set(true, forKey: "RYC0WallpaperDimmed")
        defaults.set(7, forKey: "LCJITEnablerType")

        LCSharedUtils.migrateSharedDefaultsIfNeeded()

        XCTAssertTrue(defaults.bool(forKey: "RYC0HasCompletedOnboarding"))
        XCTAssertTrue(defaults.bool(forKey: "RYC0WallpaperDimmed"))
        XCTAssertNil(defaults.object(forKey: "ZCHasCompletedOnboarding"))
        XCTAssertNil(defaults.object(forKey: "ZCWallpaperDimmed"))
        XCTAssertEqual(defaults.integer(forKey: "LCJITEnablerType"), JITEnablerType.StikJIT.rawValue)
        LCSharedUtils.migrateSharedDefaultsIfNeeded()
        XCTAssertTrue(defaults.bool(forKey: "RYC0WallpaperDimmed"))
    }

    func testRemovedJITProviderFallsBackToSupportedProvider() {
        let defaults = LCUtils.appGroupUserDefault
        let key = JITEnablerType.storageKey
        let saved = defaults.object(forKey: key)
        defer {
            if let saved { defaults.set(saved, forKey: key) }
            else { defaults.removeObject(forKey: key) }
        }
        defaults.set(7, forKey: key)
        XCTAssertEqual(JITEnablerType.current, .StikJIT)
        defaults.set(JITEnablerType.SideJITServer.rawValue, forKey: key)
        XCTAssertEqual(JITEnablerType.current, .SideJITServer)
    }

    func testSupportedJITBackendStillHandlesItsRequest() async {
        let defaults = LCUtils.appGroupUserDefault
        let key = JITEnablerType.storageKey
        let saved = defaults.object(forKey: key)
        defer {
            if let saved { defaults.set(saved, forKey: key) }
            else { defaults.removeObject(forKey: key) }
        }
        defaults.set(JITEnablerType.StosDebug.rawValue, forKey: key)
        var messages: [String] = []
        let launched = await LCUtils.askForJIT(appName: nil) { messages.append($0) }
        XCTAssertFalse(launched)
        XCTAssertEqual(messages, ["Unable to get App Name, Please try again."])
    }

    func testRetiredQueueRecordDoesNotLoseFileAndLinkInstalls() throws {
        let files = FileManager.default
        let root = URL.applicationSupportDirectory.appending(path: "ReceivedApps", directoryHint: .isDirectory)
        let backup = root.appendingPathExtension(UUID().uuidString)
        let hadExisting = files.fileExists(atPath: root.path)
        if hadExisting { try files.moveItem(at: root, to: backup) }
        defer {
            try? files.removeItem(at: root)
            if hadExisting { try? files.moveItem(at: backup, to: root) }
        }

        let downloadID = UUID(), fileID = UUID(), retiredID = UUID()
        let folder = try PendingInstallStore.makeFolder(for: fileID)
        try Data("fixture".utf8).write(to: folder.appending(path: "Local.ipa"))
        _ = try PendingInstallStore.makeFolder(for: retiredID)
        let records = [
            PendingInstallRecord(id: downloadID, kind: .link, name: "Download", state: .downloading,
                                 address: "https://example.com/App.ipa"),
            PendingInstallRecord(id: fileID, kind: .pickedFile, name: "Local", state: .waiting,
                                 fileName: "Local.ipa")
        ]
        var raw = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(records)) as? [[String: Any]])
        raw.insert(["id": retiredID.uuidString, "kind": "retiredExternalRequest", "name": "Retired",
                    "state": ["downloading": [:]]], at: 1)
        try JSONSerialization.data(withJSONObject: raw).write(to: root.appending(path: "Manifest.json"))

        let restored = PendingInstallStore.restore()
        XCTAssertEqual(restored.map(\.id), [downloadID, fileID])
        XCTAssertEqual(restored.map(\.state), [.downloading, .waiting])
        XCTAssertFalse(files.fileExists(atPath: PendingInstallStore.folder(for: retiredID).path))
        XCTAssertTrue(files.fileExists(atPath: folder.appending(path: "Local.ipa").path))
        XCTAssertEqual(PendingInstallStore.restore().map(\.id), [downloadID, fileID])
    }

    func testLocalDownloadUsesItsFileName() throws {
        let url = try XCTUnwrap(URL(string: "http://127.0.0.1:1234/app.ipa"))
        XCTAssertEqual(PendingInstallSource.link(url).name, "app")
        XCTAssertEqual(PendingInstallSource.downloadName(for: url), "app.ipa")
    }
}

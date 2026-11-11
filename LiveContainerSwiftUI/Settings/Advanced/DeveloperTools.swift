//
//  DeveloperTools.swift
//  LiveContainerSwiftUI
//

import Foundation

/// What the buttons of Settings > Advanced > Developer do: copying files out
/// to ryC0's Documents folder, which Files shows, resetting the symbol
/// cache, and showing FLEX when a tweak has loaded it.
enum DeveloperTools {
    private static var documents: URL {
        URL.documentsDirectory
    }

    static func exportCertificate() throws -> [String] {
        var written: [String] = []
        if let profile = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision") {
            try copy(profile, named: "embedded.mobileprovision")
            written.append("embedded.mobileprovision")
        }
        if let certificate = LCUtils.certificateData() {
            try certificate.write(to: documents.appending(path: "cert.p12"), options: .atomic)
            written.append("cert.p12")
        }
        if let password = LCSharedUtils.certificatePassword() {
            try password.write(to: documents.appending(path: "pass.txt"), atomically: true, encoding: .utf8)
            written.append("pass.txt")
        }
        return written
    }

    /// Copies the system's dyld to Documents. Returns the name of the copy.
    static func exportDyld() throws -> [String] {
        try copy(URL(filePath: "/usr/lib/dyld"), named: "dyld")
        return ["dyld"]
    }

    static func exportMainBundle() throws -> [String] {
        let bundle = Bundle.main.bundleURL
        let name = bundle.lastPathComponent
        let destination = documents.appending(path: name)
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.createDirectory(at: destination, withIntermediateDirectories: false)
        for item in try fileManager.contentsOfDirectory(at: bundle, includingPropertiesForKeys: nil) {
            try fileManager.copyItem(at: item, to: destination.appending(path: item.lastPathComponent))
        }
        return [name]
    }

    /// Forgets the symbol offsets ryC0 found in the system's libraries,
    /// so they are looked up again on the next launch.
    static func resetSymbolOffsets() {
        LCUtils.appGroupUserDefault.removeObject(forKey: "symbolOffsetCache")
    }

    /// Whether FLEX is loaded, which a tweak in ryC0 itself can do.
    static var isFLEXAvailable: Bool {
        NSClassFromString("FLEXManager") != nil
    }

    /// Shows FLEX's explorer over ryC0.
    static func showFLEXOverlay() {
        let manager = (NSClassFromString("FLEXManager") as? NSObject.Type)?
            .perform(NSSelectorFromString("sharedManager"))?
            .takeUnretainedValue() as? NSObject
        manager?.perform(NSSelectorFromString("showExplorer"))
    }

    /// Copies a file into Documents, replacing an earlier copy.
    private static func copy(_ source: URL, named name: String) throws {
        let destination = documents.appending(path: name)
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.copyItem(at: source, to: destination)
    }
}

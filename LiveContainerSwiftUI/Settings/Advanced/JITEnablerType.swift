//
//  JITEnablerType.swift
//  LiveContainerSwiftUI
//

import Foundation

enum JITEnablerType: Int, CaseIterable, Identifiable {
    case SideJITServer = 0
    case StikJIT = 1
    case JITStreamerEBLegacy = 2
    case StikJITLC = 3
    case StosDebug = 5
    case StosDebugLC = 6

    var id: Int {
        rawValue
    }

    static var current: JITEnablerType {
        let defaults = LCUtils.appGroupUserDefault
        guard defaults.object(forKey: storageKey) != nil else {
            return .StikJIT
        }
        return JITEnablerType(rawValue: defaults.integer(forKey: storageKey)) ?? .StikJIT
    }

    /// The app group defaults key the choice is saved under.
    static let storageKey = "LCJITEnablerType"

    /// The tool's name.
    var displayName: String {
        switch self {
        case .StikJIT: "StikDebug"
        case .StikJITLC: "StikDebug (Another ryC0/Multitask)"
        case .StosDebug: "StosDebug"
        case .StosDebugLC: "StosDebug (Another ryC0/Multitask)"
        case .JITStreamerEBLegacy: "JitStreamer-EB (Relaunch)"
        case .SideJITServer: "SideJITServer/JITStreamer 2.0"
        }
    }

    /// Whether ryC0 reaches the tool at an address typed into Settings.
    var needsServerAddress: Bool {
        self == .SideJITServer || self == .JITStreamerEBLegacy
    }

    /// An example of the address the tool listens at, as the address field's
    /// placeholder.
    var addressPlaceholder: String {
        self == .SideJITServer ? "http://x.x.x.x:8080" : "http://[fd00::]:9172"
    }
}

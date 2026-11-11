//
//  AppIconChoice.swift
//  LiveContainerSwiftUI
//

import Foundation

enum AppIconChoice: CaseIterable, Identifiable {
    case ryC0
    case purple
    case blue
    case teal
    case green
    case orange
    case red
    case gold
    case mono
    case light

    var id: Self {
        self
    }

    /// The icon's name in Settings.
    var title: String {
        switch self {
        case .ryC0: "ryc0.appIcon.ryC0".loc
        case .purple: "ryc0.appIcon.purple".loc
        case .blue: "ryc0.appIcon.blue".loc
        case .teal: "ryc0.appIcon.teal".loc
        case .green: "ryc0.appIcon.green".loc
        case .orange: "ryc0.appIcon.orange".loc
        case .red: "ryc0.appIcon.red".loc
        case .gold: "ryc0.appIcon.gold".loc
        case .mono: "ryc0.appIcon.mono".loc
        case .light: "ryc0.appIcon.light".loc
        }
    }

    /// The name iOS knows the icon by, or nil for ryC0's own.
    var alternateIconName: String? {
        switch self {
        case .ryC0: nil
        case .purple: "Purple"
        case .blue: "Blue"
        case .teal: "Teal"
        case .green: "Green"
        case .orange: "Orange"
        case .red: "Red"
        case .gold: "Gold"
        case .mono: "Mono"
        case .light: "Light"
        }
    }

    /// The icon's picture in the app, which the picker shows: the files iOS
    /// uses for it, loose in the app.
    var previewImageName: String {
        alternateIconName.map { "AppIcon\($0)60x60" } ?? "AppIcon60x60"
    }

    /// The choice in use, from the name iOS gives the icon it shows, nil when
    /// it's ryC0's own.
    init(alternateIconName name: String?) {
        self = Self.allCases.first { $0.alternateIconName == name } ?? .ryC0
    }
}

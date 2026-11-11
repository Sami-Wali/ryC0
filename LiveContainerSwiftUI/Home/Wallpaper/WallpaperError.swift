//
//  WallpaperError.swift
//  LiveContainerSwiftUI
//

import Foundation

/// Why a photo couldn't become the wallpaper.
enum WallpaperError: LocalizedError {
    /// The photo isn't a picture iOS can read.
    case unreadable
    case unreadableTendies

    var errorDescription: String? {
        switch self {
        case .unreadableTendies:
            "ryc0.wallpaper.tendiesUnreadable".loc
        case .unreadable:
            "ryc0.wallpaper.unreadable".loc
        }
    }
}

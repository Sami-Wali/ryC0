//
//  WallpaperPreview.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The wallpaper as the Home Screen shows it, small and in the screen's
/// shape, with a spinner while a new one is being made. On iPad it follows
/// the window's shape as the window is rotated or resized, and has the
/// iPad's tighter corners.
struct WallpaperPreview: View {
    @Environment(WallpaperStore.self) private var wallpaper
    @Environment(HomeScreenModel.self) private var model
    @Environment(\.presentedScreenSize) private var presentedScreenSize

    var body: some View {
        let height = Self.height
        let screen = screenSize
        let width = screen.height > 0 ? height * screen.width / screen.height : height / 2

        HomeWallpaperImage()
            .frame(width: width, height: height)
            .overlay {
                if wallpaper.isPreparing {
                    ProgressView()
                        .tint(.white)
                }
            }
            .clipShape(.rect(cornerRadius: height * Self.cornerFraction))
            .overlay {
                RoundedRectangle(cornerRadius: height * Self.cornerFraction)
                    .strokeBorder(.separator, lineWidth: 1)
            }
            .padding(.vertical, 8)
            .accessibilityElement()
            .accessibilityLabel("ryc0.settings.wallpaper.preview".loc)
    }

    /// The size of the screen the preview copies. On iPhone, the Home
    /// Screen's, as it was when Settings opened. On iPad, the size Settings
    /// measured for itself, which is the window's: the Home Screen under it
    /// may not lay out while it's covered, so its size could be out of date.
    private var screenSize: CGSize {
        if SharedModel.isPhone {
            (model.metrics ?? .reference).size
        } else {
            presentedScreenSize ?? (model.padMetrics ?? model.metrics ?? .reference).size
        }
    }

    /// The preview's height. It's a picture, so it keeps its size whatever
    /// the text size.
    private static let height = 300.0

    /// The preview's corner radius as a fraction of its height, about the
    /// screen's own: an iPhone's rounder corners, or an iPad's tighter ones,
    /// a little rounder than the real ones so the preview still reads as a
    /// screen at this size.
    private static let cornerFraction = SharedModel.isPhone ? 0.058 : 0.025
}

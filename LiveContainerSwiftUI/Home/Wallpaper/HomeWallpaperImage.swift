//
//  HomeWallpaperImage.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// What the Home Screen shows behind everything: its wallpaper filling the
/// screen, on black until it has loaded. While Dark Mode is on a photo is
/// dimmed, unless that's turned off. As search comes in, the blurred copy
/// fades in over it.
struct HomeWallpaperImage: View {
    var isCovered = false
    @Environment(WallpaperStore.self) private var wallpaper
    @Environment(SystemAppearance.self) private var system
    @Environment(HomeScreenModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var guest = FullScreenGuestSession.shared

    var body: some View {
        let isDimmed = wallpaper.isCustom && wallpaper.dimsInDarkMode && system.isDark
        let showsMotion = scenePhase == .active && !isCovered && !reduceMotion && !model.isSearching
            && !model.showsAppSwitcher && !model.isCoveredByScreen && model.presentedScreen == nil
            && !guest.isGuestVisible

        Color.black
            .overlay {
                if let image = wallpaper.image {
                    ZStack {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()

                        if let movie = wallpaper.motion, !reduceMotion {
                            MotionWallpaperView(movie: movie, plays: showsMotion)
                                .id(movie)
                                .transition(.identity)
                                .accessibilityHidden(true)
                        }

                        if let blurred = wallpaper.blurredImage {
                            Image(uiImage: blurred)
                                .resizable()
                                .scaledToFill()
                                .opacity(model.searchPresence)
                        }

                        Color.black
                            .opacity(isDimmed ? HomeDesign.wallpaperDimming : 0)
                    }
                    .transition(.opacity)
                }
            }
            .clipped()
            .animation(HomeDesign.modeChange, value: wallpaper.image)
            .animation(HomeDesign.modeChange, value: model.isSearching)
            .animation(HomeDesign.modeChange, value: isDimmed)
            .ignoresSafeArea()
            .accessibilityHidden(true)
    }
}

//
//  HomeWallpaper.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The empty space behind the icons, which reacts as the iOS wallpaper does:
/// a long press starts edit mode and a tap ends it. Pulling down to open
/// search belongs to HomePagesView, so it works on the icons too. VoiceOver
/// reaches the same things through the icons' menus, Done and the search
/// pill, so this space stays out of its way.
struct HomeWallpaper: View {
    @Environment(HomeScreenModel.self) private var model

    var body: some View {
        Color.clear
            .contentShape(.rect)
            // A tap anywhere on the wallpaper has no button to belong to.
            .onTapGesture(perform: model.wallpaperTapped)
            .onLongPressGesture(perform: model.beginEditing)
            .accessibilityHidden(true)
    }
}

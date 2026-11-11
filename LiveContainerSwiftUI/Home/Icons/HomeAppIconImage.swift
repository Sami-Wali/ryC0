//
//  HomeAppIconImage.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// An app's icon as IconServices drew it for the Home Screen, without its
/// mask and border, filling the frame the view around it gives it, in its
/// dark version when asked. An icon drawn before shows at once, from memory
/// or from the file it was saved in. One that hasn't been, such as the first
/// time dark icons show, is drawn off the main thread, so the Home Screen
/// never waits for IconServices: until it's ready, the other version shows,
/// or a plain tile when neither has been drawn.
struct HomeAppIconImage: View {
    /// The app whose icon shows.
    @ObservedObject var app: LCAppModel
    /// Whether the icon shows in its dark version.
    let isDark: Bool

    var body: some View {
        ZStack {
            if let icon = app.homeScreenIcon(isDark: isDark) {
                Image(uiImage: icon)
                    .resizable()
                    .scaledToFill()
            } else {
                HomeDesign.iconPlaceholder
            }
        }
        .task(id: HomeAppIconKey(app: app, isDark: isDark, generation: app.iconGeneration)) {
            await app.drawHomeScreenIcon(isDark: isDark)
        }
    }
}

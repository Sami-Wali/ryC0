//
//  HomeLaunchZoomView.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// A tapped app opening: its icon grows from its place into a black screen,
/// the way iOS zooms an app open, just before ryC0 turns into the app.
/// With Reduce Motion on, the screen fades to black instead. It tells the
/// model once the screen is covered, which lets the launch go ahead. The
/// growing icon doesn't lift under a trackpad or mouse pointer the way the
/// icon it grows from does.
struct HomeLaunchZoomView: View {
    /// The app opening, the icon it opens from, and where it is.
    let zoom: HomeLaunchZoom
    /// Where things go on this screen.
    let metrics: HomeMetrics

    @Environment(HomeScreenModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.prefersDarkAppIcons) private var darkModeIcon
    @State private var isOpen = false

    var body: some View {
        let frame = isOpen || reduceMotion ? CGRect(origin: .zero, size: metrics.size) : zoom.iconFrame
        // On iPad the artwork is drawn at the pages' icon size, which a
        // shrunken dock icon starts smaller than. The iPhone keeps measuring
        // from the tapped icon, as it always has.
        let baseWidth = SharedModel.isPhone ? zoom.iconFrame.width : metrics.iconSize
        let iconScale = baseWidth > 0 ? frame.width / baseWidth : 1
        let startRadius = SharedModel.isPhone ? metrics.iconCornerRadius : zoom.iconFrame.width * HomeDesign.iconCornerFraction

        ZStack {
            Color.black
            HomeIconContent(item: zoom.item, app: zoom.app, metrics: metrics, showsLabel: false, darkModeIcon: darkModeIcon)
                .scaleEffect(reduceMotion ? 1 : iconScale)
                .opacity(isOpen || reduceMotion ? 0 : 1)
        }
        .frame(width: frame.width, height: frame.height)
        .clipShape(.rect(cornerRadius: isOpen ? 0 : startRadius))
        .position(x: frame.midX, y: frame.midY)
        .opacity(reduceMotion && !isOpen ? 0 : 1)
        .hoverEffectDisabled()
        .accessibilityHidden(true)
        .onAppear(perform: open)
    }

    private func open() {
        withAnimation(reduceMotion ? .easeOut(duration: 0.16) : HomeDesign.launchZoom) {
            isOpen = true
        } completion: {
            model.launchZoomDidFinish()
        }
    }
}

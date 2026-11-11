//
//  HomeScreenPresentation.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// Opens Settings or a hosted app over the Home Screen. On iOS 18 and
/// later the screen zooms out of its icon and covers the Home Screen, the way
/// an app opens, and swiping down closes it again. iOS 17 opens it as a sheet
/// on iPhone. On an iPad, iOS 17's sheet would be a narrow card too small for
/// Settings' sidebar, so there it covers the Home Screen too, without the zoom.
struct HomeScreenPresentation: ViewModifier {
    @Bindable var model: HomeScreenModel
    /// The namespace the icons are marked in as zoom sources.
    let zoomNamespace: Namespace.ID

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.fullScreenCover(item: $model.presentedScreen, onDismiss: model.presentedScreenDidClose) { screen in
                destination(for: screen)
                    .navigationTransition(.zoom(sourceID: screen.zoomSourceID, in: zoomNamespace))
            }
        } else if SharedModel.isPhone {
            content.sheet(item: $model.presentedScreen, onDismiss: model.presentedScreenDidClose) { screen in
                HomePresentedScreenView(screen: screen)
            }
        } else {
            content.fullScreenCover(item: $model.presentedScreen, onDismiss: model.presentedScreenDidClose) { screen in
                HomePresentedScreenView(screen: screen)
            }
        }
    }

    @available(iOS 18.0, *)
    @ViewBuilder private func destination(for screen: HomePresentedScreen) -> some View {
        if case .guest = screen {
            FullScreenGuestCover()
                .ignoresSafeArea()
        } else {
            HomePresentedScreenView(screen: screen)
        }
    }

    /// Whether a screen opened over the Home Screen covers it completely,
    /// which it does from iOS 18, and on iPad on iOS 17. The status bar then
    /// follows the screen while it's open.
    static var coversHomeScreen: Bool {
        if #available(iOS 18.0, *) {
            true
        } else {
            !SharedModel.isPhone
        }
    }
}

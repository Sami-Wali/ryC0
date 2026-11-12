//
//  HomeScreenView.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// ryC0's main screen: a Home Screen like the iPhone's, on the halo
/// wallpaper it comes with or a photo chosen for it, under the real status
/// bar. It shows the apps inside ryC0 on
/// pages of icons with a dock, opens them with a tap, and opens Settings, an
/// app's settings and search over itself. It is the main window's root, so it
/// also runs HomeRouter's launch checks and links.
struct HomeScreenView: View {
    @Environment(HomeScreenModel.self) private var model
    @EnvironmentObject private var sceneDelegate: SceneDelegate
    @Environment(HomeRouter.self) private var router
    @Environment(AppLaunchCoordinator.self) private var coordinator
    @Environment(OnboardingModel.self) private var onboarding
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showsNotifications = false
    let zoomNamespace: Namespace.ID

    var body: some View {
        let presence = model.searchPresence
        let canOpenNotifications = !showsNotifications && !model.isEditing && !model.isSearching
            && !model.isFolderShown && !model.showsAppSwitcher && model.presentedScreen == nil
            && !model.isCoveredByScreen && !onboarding.isPresented

        ZStack {
            // The Home Screen is laid out from the screen's top left corner,
            // as on iOS. A reader that covers the whole screen reads its safe
            // area as empty, so the outer reader stays in the safe area and
            // the insets are where the whole screen sits around it.
            GeometryReader { safeArea in
                GeometryReader { screen in
                    HomeSpringboard(
                        metrics: HomeMetrics(
                            size: screen.size,
                            safeArea: Self.insets(of: safeArea.size, within: screen.frame(in: .named(Self.safeAreaSpace))),
                            isPhone: SharedModel.isPhone
                        ),
                        zoomNamespace: zoomNamespace
                    )
                }
                .ignoresSafeArea()
            }
            .coordinateSpace(.named(Self.safeAreaSpace))
            // Search's keyboard leaves the Home Screen where it is.
            .ignoresSafeArea(.keyboard)
            // Search covers the Home Screen for touches and for VoiceOver alike.
            .opacity(showsNotifications ? 0 : 1)
            .allowsHitTesting(!model.isSearching && !showsNotifications)
            .accessibilityHidden(model.isSearching || showsNotifications)

            // Search's dimming covers the whole screen and only fades, so
            // it has no edge as search slides in.
            Color.black
                .opacity(HomeDesign.searchDimming * presence)
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .accessibilityHidden(true)

            if model.isSearching || model.searchPull > 0 {
                // Search slides down and fades in with the pull, and only
                // takes touches and the keyboard once it is open.
                HomeSearchView()
                    .opacity(presence)
                    .offset(y: -HomeDesign.searchPullOffset * (1 - presence))
                    .allowsHitTesting(model.isSearching)
                    .transition(.opacity)
            }
            if showsNotifications {
                HomeNotificationCenter { setNotifications(false) }
                    .transition(reduceMotion ? .opacity : .move(edge: .top))
                    .zIndex(2)
            } else if canOpenNotifications {
                GeometryReader { geometry in
                    HomeNotificationPull(height: max(44, geometry.safeAreaInsets.top + 20)) {
                        setNotifications(true)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .ignoresSafeArea(.container, edges: .top)
                }
            }
        }
        .background {
            HomeWallpaperImage(isCovered: showsNotifications)
        }
        .defersSystemGestures(on: canOpenNotifications ? .top : [])
        // The Home Screen is drawn for a dark wallpaper, whatever the
        // appearance setting. Screens opened over it keep the setting.
        .environment(\.colorScheme, .dark)
        .homeStatusBarHidden(model.isEditing || model.showsAppSwitcher || showsNotifications)
        // A screen over the Home Screen, or onboarding, keeps the setting.
        .preferredColorScheme(model.isCoveredByScreen || onboarding.coversHomeScreen ? nil : .dark)
        .homePresentations()
        .homeRouting(router, onRoute: model.handle)
        .onChange(of: router.opensAppSwitcher, initial: true) {
            if router.opensAppSwitcher && MainWindow.isMain(sceneDelegate.window?.windowScene) {
                router.opensAppSwitcher = false
                if !onboarding.isPresented { model.showAppSwitcher(from: .app) }
            }
        }
        .onReceive(MainWindow.homeRequests) { openingSwitcher in
            guard MainWindow.isMain(sceneDelegate.window?.windowScene) else { return }
            setNotifications(false)
            if openingSwitcher && !onboarding.isPresented { model.showAppSwitcher(from: .app) }
            else { model.showsAppSwitcher = false }
            model.showHomeScreen()
        }
        .onReceive(model.appsPublisher, perform: model.syncApps)
        .onChange(of: coordinator.appSettingsCloseRequests) {
            model.closeAppSettings()
        }
    }

    private func setNotifications(_ visible: Bool) {
        withAnimation(.easeOut(duration: reduceMotion ? 0.12 : 0.25)) {
            showsNotifications = visible
        }
    }

    /// The coordinate space of the safe area, which the whole screen is
    /// measured in to find the insets.
    private static let safeAreaSpace = "HomeSafeArea"

    /// The safe area's insets, from its size and the whole screen's frame in
    /// its coordinates, which starts above and before it by the top and
    /// leading insets.
    private static func insets(of safeArea: CGSize, within screen: CGRect) -> EdgeInsets {
        EdgeInsets(
            top: max(-screen.minY, 0),
            leading: max(-screen.minX, 0),
            bottom: max(screen.maxY - safeArea.height, 0),
            trailing: max(screen.maxX - safeArea.width, 0)
        )
    }
}

//
//  AppRootView.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The main window's root: the Home Screen, with onboarding over it while it
/// shows. Onboarding sits in the same view tree rather than being presented,
/// so the questions and errors installs raise from the Home Screen still show
/// over it. When onboarding finishes it fades away while the Home Screen
/// fades in and its icons settle from a little closer, as after unlocking.
struct AppRootView: View {
    @Environment(OnboardingModel.self) private var onboarding
    @Environment(HomeScreenModel.self) private var home
    @Environment(AppLaunchCoordinator.self) private var coordinator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isOpeningFromSwitcher = false
    @Namespace private var zoomNamespace

    var body: some View {
        ZStack {
            HomeScreenView(zoomNamespace: zoomNamespace)
                .scaleEffect(onboarding.isPresented && !reduceMotion ? OnboardingDesign.homeArrivalScale : 1)
                .opacity(onboarding.isPresented ? 0 : 1)
                // Hidden under onboarding for touches and VoiceOver alike.
                .allowsHitTesting(!onboarding.isPresented && !home.showsAppSwitcher)
                .accessibilityHidden(onboarding.isPresented || home.showsAppSwitcher)

            if home.showsAppSwitcher {
                AppSwitcherView(zoomNamespace: zoomNamespace, open: openSwitcherSelection, goHome: dismissSwitcher)
                    .id(home.switcherPresentationID)
                    .transition(.identity)
                    .zIndex(1)
            }

            if onboarding.isPresented {
                OnboardingView(startsAtConnect: onboarding.startsAtConnect)
                    .transition(.opacity)
                    .zIndex(2)
            }

            if #available(iOS 16.0, *) {
                FullScreenGuestStage()
                    .ignoresSafeArea()
                    .zIndex(3)
            }
        }
        .modifier(HomeScreenPresentation(model: home, zoomNamespace: zoomNamespace))
        .onChange(of: onboarding.isPresented, onboardingChanged)
        .onReceive(MainWindow.guestErrors) { coordinator.errorMessage = $0 }
        .onReceive(FullScreenGuestSession.shared.$isGuestVisible) { visible in
            if #available(iOS 18.0, *) { return }
            if visible && home.showsAppSwitcher { dismissSwitcher() }
        }
        .appIconAppearance()
    }

    private func dismissSwitcher() {
        home.showsAppSwitcher = false
    }

    private func openSwitcherSelection(_ app: LCAppModel, container: String?, frame: CGRect) {
        guard home.showsAppSwitcher, !isOpeningFromSwitcher, let key = app.homeKey,
              home.apps[key] === app, !app.appInfo.isHidden else { return }
        isOpeningFromSwitcher = true
        Task {
            defer { isOpeningFromSwitcher = false }
            await coordinator.open(app, containerFolderName: container, zoomOrigin: GuestZoomOrigin(cardFrame: frame)) {
                await withCheckedContinuation { continuation in
                    withAnimation(.easeOut(duration: 0.16)) {
                        dismissSwitcher()
                    } completion: {
                        continuation.resume()
                    }
                }
                home.prepareClassicReturn(page: home.page ?? 0, iconFrame: home.iconFrame(of: .app(key)))
            }
            // A native/virtual window can come forward without using the full-screen stage.
            if #available(iOS 18.0, *), FullScreenGuestSession.shared.isPresenting(bundle: app.appInfo.relativeBundlePath) { return }
            if home.showsAppSwitcher { dismissSwitcher() }
        }
    }

    /// Closes what's open over the Home Screen, like Settings, when
    /// onboarding opens from it, since onboarding shows under presented
    /// screens.
    private func onboardingChanged() {
        if onboarding.isPresented {
            dismissSwitcher()
            home.showHomeScreen()
        }
    }
}

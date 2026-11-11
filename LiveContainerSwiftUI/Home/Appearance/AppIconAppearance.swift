//
//  AppIconAppearance.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// Works out whether apps' icons show in their dark versions, for every view
/// under it, and follows the system's appearance from the scene it shows in.
/// The answer is also saved as LiveContainer's dark icon setting, which its
/// multitasking windows read.
struct AppIconAppearance: ViewModifier {
    @AppStorage(HomeIconStyle.storageKey, store: LCUtils.appGroupUserDefault) private var style = HomeIconStyle.automatic
    @Environment(SystemAppearance.self) private var system
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var sceneDelegate: SceneDelegate

    func body(content: Content) -> some View {
        let prefersDark = style.prefersDarkIcons(systemIsDark: system.isDark)

        content
            .environment(\.prefersDarkAppIcons, prefersDark)
            .onAppear(perform: followScene)
            .onChange(of: scenePhase) {
                if scenePhase == .active {
                    followScene()
                }
            }
            .onChange(of: prefersDark, initial: true) {
                LCUtils.appGroupUserDefault.set(prefersDark, forKey: Self.liveContainerKey)
            }
    }

    /// LiveContainer's own dark icon setting.
    private static let liveContainerKey = "darkModeIcon"

    /// Has the system appearance follow this view's own scene, when it's the
    /// main window's. On iPad other scenes can be connected too, and a second
    /// window that opens only to close again mustn't take it over. Coming to
    /// the front follows again, which picks up a scene iPadOS reconnected.
    private func followScene() {
        let scene = sceneDelegate.window?.windowScene
            ?? UIApplication.shared.connectedScenes.lazy.compactMap { $0 as? UIWindowScene }.first
        if let scene, MainWindow.isMain(scene) {
            system.follow(scene)
        }
    }
}

extension View {
    /// Picks the light or dark versions of apps' icons for this view and the
    /// views under it. Apply it once, to the main window's root.
    func appIconAppearance() -> some View {
        modifier(AppIconAppearance())
    }
}

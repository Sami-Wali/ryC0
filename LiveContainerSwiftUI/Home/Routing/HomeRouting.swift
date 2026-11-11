//
//  HomeRouting.swift
//  LiveContainerSwiftUI
//

import SwiftUI

struct HomeRouting: ViewModifier {
    let router: HomeRouter
    let onRoute: @MainActor (HomeRoute) -> Void

    @EnvironmentObject private var sceneDelegate: SceneDelegate
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var guest = FullScreenGuestSession.shared

    func body(content: Content) -> some View {
        @Bindable var router = router

        content
            .appLaunchPresentations(router.coordinator)
            .alert(
                "lc.common.error".loc,
                isPresented: Binding<Bool>.isPresented(for: $router.launchProblem),
                presenting: router.launchProblem
            ) { problem in
                Button("lc.common.ok".loc) { }
                Button("lc.common.copy".loc) {
                    UIPasteboard.general.string = problem
                }
            } message: { problem in
                Text(problem)
            }
            .alert("ryc0.notifications.test.confirmTitle".loc, isPresented: Binding(
                get: { router.notificationTestApp != nil && !guest.isGuestVisible },
                set: { if !$0 { router.notificationTestApp = nil } }
            ), presenting: router.notificationTestApp) { app in
                Button("ryc0.notifications.test.send".loc) {
                    Task { await router.scheduleNotificationTest(for: app) }
                }
                Button("lc.common.cancel".loc, role: .cancel) { }
            } message: { _ in
                Text("ryc0.notifications.test.confirmBody".loc)
            }
            .certificateImportPresentation(router)
            .sheet(isPresented: $router.isShowingCrashReport) {
                LaunchErrorReportView(report: router.crashReport)
            }
            .task {
                await router.start(in: sceneDelegate.window?.windowScene)
            }
            .onChange(of: scenePhase, scenePhaseChanged(from:to:))
            .onReceive(NotificationCenter.default.publisher(for: UIScene.didDisconnectNotification)) { notification in
                if let scene = notification.object as? UIScene {
                    router.sceneDidDisconnect(scene)
                }
            }
            .onOpenURL { url in
                if let route = router.dispatchURL(url) {
                    onRoute(route)
                }
            }
    }

    private func scenePhaseChanged(from oldPhase: ScenePhase, to newPhase: ScenePhase) {
        switch newPhase {
        case .active:
            Task {
                await router.sceneBecameActive(onRoute: onRoute)
            }
        default:
            break
        }
    }
}

extension View {
    /// Makes this view the main window's root for the router. Apply it once.
    func homeRouting(_ router: HomeRouter, onRoute: @escaping @MainActor (HomeRoute) -> Void = { _ in }) -> some View {
        modifier(HomeRouting(router: router, onRoute: onRoute))
    }
}

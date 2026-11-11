//
//  HomeRouter.swift
//  LiveContainerSwiftUI
//

import SwiftUI
import UserNotifications

@MainActor
@Observable
final class HomeRouter {
    /// Carries out the app links.
    @ObservationIgnored let coordinator: AppLaunchCoordinator
    /// The app state the launch checks read, the coordinator's own.
    @ObservationIgnored let sharedModel: SharedModel
    @ObservationIgnored let onboarding: OnboardingModel

    /// A .p12 file ryC0 was asked to open, while its password is
    /// asked for.
    var lockedCertificate: LockedCertificate?
    /// A certificate sent to ryC0, while the person is asked whether
    /// to use it.
    var certificateOffer: CertificateOffer?
    var storedCertificateTeam: String?
    /// Goes up by one whenever a certificate sent to ryC0 is stored,
    /// so onboarding reads the certificate again.
    var certificatesStored = 0

    var launchProblem: String?
    /// Why the last app launch failed, in full: the error it left, or a crash
    /// while signing.
    var crashReport = ""
    /// Whether `crashReport` is on screen.
    var isShowingCrashReport = false
    var opensAppSwitcher = false
    var notificationTestApp: LCAppModel?
    @ObservationIgnored private var isSchedulingNotificationTest = false

    init(coordinator: AppLaunchCoordinator, onboarding: OnboardingModel) {
        self.coordinator = coordinator
        self.sharedModel = coordinator.sharedModel
        self.onboarding = onboarding
        coordinator.onAppsChanged = {
            GuestNotificationMonitor.shared.refresh()
        }
    }

    /// Sends a URL ryC0 was opened with where it goes, and returns that
    /// route, or nil when ryC0 doesn't handle the URL.
    @discardableResult
    func dispatchURL(_ url: URL) -> HomeRoute? {
        guard let route = HomeRoute(url: url) else {
            return nil
        }
        switch route {
        case .home:
            if #available(iOS 16.0, *) { FullScreenGuestSession.shared.returnHome(openSwitcher: false) }
        case .ryP0NotificationTest:
            guard !onboarding.isPresented, notificationTestApp == nil, !isSchedulingNotificationTest else { return nil }
            let candidates = sharedModel.apps.filter {
                $0.appInfo.bundleIdentifier() == BundledStore.bundleIdentifier && !$0.appInfo.isLocked && !$0.appInfo.isHidden
            }
            let session = FullScreenGuestSession.shared
            let runningApp = session.runningBundlePath.flatMap { path in
                candidates.first { $0.appInfo.relativeBundlePath == path }
            }
            let app = runningApp ?? candidates.first
            guard let app else { return nil }
            session.returnHome(openSwitcher: false)
            MainWindow.showHome(openingSwitcher: false)
            notificationTestApp = app
        case .app(let link):
            if case .install = link {
                if #available(iOS 16.0, *) { FullScreenGuestSession.shared.returnHome(openSwitcher: false) }
                MainWindow.showHome(openingSwitcher: false)
            }
            send(link)
        case .certificate(let link):
            Task { await review(link) }
        case .certificateFile(let url):
            openCertificateFile(url)
        }
        return route
    }

    func scheduleNotificationTest(for app: LCAppModel) async {
        guard !isSchedulingNotificationTest, sharedModel.apps.contains(where: { $0 === app }),
              !app.appInfo.isLocked, !app.appInfo.isHidden, let bundlePath = app.appInfo.relativeBundlePath else { return }
        isSchedulingNotificationTest = true
        defer { isSchedulingNotificationTest = false }

        let center = UNUserNotificationCenter.current()
        do {
            guard try await center.requestAuthorization(options: [.alert, .sound]) else {
                launchProblem = "ryc0.notifications.test.permissionRequired".loc
                return
            }
            let content = UNMutableNotificationContent()
            content.title = "ryc0.notifications.test.notificationTitle".loc
            content.body = "ryc0.notifications.test.notificationBody".loc
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
            let request = UNNotificationRequest(identifier: BundledStore.notificationTestIdentifier(for: bundlePath),
                                                content: content, trigger: trigger)
            try await center.add(request)
            LCSharedUtils.recordGuestNotification(request, forApp: bundlePath, container: BundledStore.notificationTestContainer)
        } catch {
            launchProblem = error.localizedDescription
        }
    }

    /// Hands launches to the coordinator and downloads to the shared queue.
    private func send(_ link: AppLink) {
        if onboarding.takeLink(link) {
            return
        }
        coordinator.handle(link)
    }

    func start(in scene: UIWindowScene?) async {
        guard acceptMainWindow(scene) || SharedModel.isPhone else {
            return
        }
        if let link = LCSharedUtils.takePendingInstallLink() {
            dispatchURL(link)
        }
        GuestActivityMonitor.shared.start()
        GuestNotificationMonitor.shared.start()
        checkLastLaunchError()
        checkTeamId()
        checkAndSaveBundleId()
        checkGetTaskAllow()
        checkPrivateContainerBookmark()
        openWebPageForThisLaunch()
        await coordinator.installBundledStoreIfNeeded()
        opensAppSwitcher = LCSharedUtils.takeAppSwitcherRequest()
    }

    func sceneBecameActive(onRoute: @MainActor (HomeRoute) -> Void) async {
        GuestActivityMonitor.shared.refresh()
        GuestNotificationMonitor.shared.refresh()
    }

    /// Notes that a window closed. When it was the main window, the next one
    /// to open becomes the main window.
    func sceneDidDisconnect(_ scene: UIScene) {
        guard let mainScene = MainWindow.scene, mainScene === scene else {
            return
        }
        MainWindow.scene = nil
        sharedModel.mainWindowOpened = false
    }

    /// Records this window as the main window and returns true. When the main
    /// window is already open, it asks iOS to close this one instead and
    /// returns false.
    ///
    /// On iPad it also returns false for the main window itself, so running
    /// again there leaves it open. An iPhone keeps the old path, where a
    /// second run asks to close its only window, as it always has.
    private func acceptMainWindow(_ scene: UIWindowScene?) -> Bool {
        defer {
            sharedModel.mainWindowOpened = true
        }
        if !SharedModel.isPhone, let scene, let mainScene = MainWindow.scene, mainScene === scene {
            return false
        }
        if let session = scene?.session, sharedModel.mainWindowOpened {
            UIApplication.shared.requestSceneSessionDestruction(session, options: nil) { error in
                print(error)
            }
            return false
        }
        MainWindow.scene = scene
        return true
    }

    /// Opens the page an app asked ryC0 to show, through
    /// `LCSharedUtils.setWebPageUrlForNextLaunch`, in the built-in browser.
    private func openWebPageForThisLaunch() {
        guard let webPage = UserDefaults.standard.string(forKey: "webPageToOpen") else {
            return
        }
        UserDefaults.standard.removeObject(forKey: "webPageToOpen")
        Task { await coordinator.openWebView(urlString: webPage) }
    }
}

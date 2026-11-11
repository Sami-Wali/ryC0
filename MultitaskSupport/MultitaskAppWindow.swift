//
//  MultitaskAppWindow.swift
//  LiveContainer
//
//  Created by s s on 2025/5/17.
//
import SwiftUI

@available(iOS 16.1, *)
struct MultitaskAppInfo {
    var displayName: String
    var dataUUID: String
    var bundleId: String
    // new for every launch, so a window that goes away late changes only its own entry, never the one a newer launch of the same container made
    let launchID = UUID()
    // the window's session once iOS disconnected it; iOS can bring a disconnected window back, so the entry stays until that session is gone
    var disconnectedSessionID: String? = nil

    init(displayName: String, dataUUID: String, bundleId: String) {
        self.displayName = displayName
        self.dataUUID = dataUUID
        self.bundleId = bundleId
    }
}

@available(iOS 16.1, *)
@objc class MultitaskWindowManager: NSObject {
    @Environment(\.openWindow) static var openWindow
    static var appDict: [String: MultitaskAppInfo] = [:]
    
    @objc class func openAppWindow(displayName: String, dataUUID: String, bundleId: String, pidCallback: ((NSNumber, Error?) -> Void)?) {
        DataManager.shared.model.pidCallback = pidCallback
        appDict[dataUUID] = MultitaskAppInfo(displayName: displayName, dataUUID: dataUUID, bundleId: bundleId)
        openWindow(id: "appView", value: dataUUID)
    }
    
    @objc class func openExistingAppWindow(dataUUID: String) -> Bool {
        guard let info = appDict[dataUUID] else { return false }
        // the window was closed, so the app launches again the full way: signing, JIT and the launch date
        if let sessionID = info.disconnectedSessionID,
           !UIApplication.shared.openSessions.contains(where: { $0.persistentIdentifier == sessionID }) {
            appDict[dataUUID] = nil
            return false
        }
        openWindow(id: "appView", value: dataUUID)
        return true
    }

    // records the session of a disconnected window on the entry of that window's launch only
    class func recordDisconnectedSession(_ sessionID: String, for info: MultitaskAppInfo) {
        guard appDict[info.dataUUID]?.launchID == info.launchID else { return }
        appDict[info.dataUUID]?.disconnectedSessionID = sessionID
    }

    // removes the entry of a closing window's launch only, so a newer launch of the same container keeps its own
    class func removeAppInfo(_ info: MultitaskAppInfo) {
        guard appDict[info.dataUUID]?.launchID == info.launchID else { return }
        appDict[info.dataUUID] = nil
    }
}

@available(iOS 16.1, *)
struct AppSceneViewSwiftUI: UIViewControllerRepresentable {
    @Binding var show: Bool
    let bundleId: String
    let dataUUID: String
    let initSize: CGSize
    let onAppInitialize: (Int32, Error?) -> Void
    let onReturnHome: () -> Void
    
    class Coordinator: NSObject, AppSceneViewControllerDelegate {
        let onExit: () -> Void
        let onReturnHome: () -> Void
        let onAppInitialize: (Int32, Error?) -> Void
        init(onAppInitialize: @escaping (Int32, Error?) -> Void, onReturnHome: @escaping () -> Void, onExit: @escaping () -> Void) {
            self.onAppInitialize = onAppInitialize
            self.onExit = onExit
            self.onReturnHome = onReturnHome
        }
        
        func appSceneVCAppDidExit(_: AppSceneViewController!) {
            onExit()
        }
        
        func appSceneVC(_ vc: AppSceneViewController!, didInitializeWithError error: (any Error)!) {
            DispatchQueue.main.async {
                (vc.view.window?.windowScene?.statusBarManager as? LCStatusBarManager)?.nativeWindowViewController = vc
            }
            onAppInitialize(vc.pid, error)
        }
        
        func appSceneVCRequestedHome(_ vc: AppSceneViewController!) {
            guard vc.viewIfLoaded?.window?.windowScene?.activationState == .foregroundActive else { return }
            onReturnHome()
        }

        func appSceneVCWillActivateScene(_ vc: AppSceneViewController!) {
            vc.updateSettings { settings in
                guard let settings else { return }
                let defaultInsets = vc.view.window?.safeAreaInsets ?? .zero
                settings.peripheryInsets = defaultInsets
                settings.safeAreaInsetsPortrait = defaultInsets
                settings.deviceOrientation = UIDevice.current.orientation
                settings.setInterfaceOrientation(UIApplication.shared.statusBarOrientation)
                if(settings.interfaceOrientation().isLandscape) {
                    settings.setFrame(CGRect(x: 0, y: 0, width: vc.view.frame.size.height, height: vc.view.frame.size.width))
                } else {
                    settings.setFrame(CGRect(x: 0, y: 0, width: vc.view.frame.size.width, height: vc.view.frame.size.height))
                }
            }
            // fix live resize
            vc.contentView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        }
        
        func appSceneVC(_ vc: AppSceneViewController!, didUpdateFrom settings: UIMutableApplicationSceneSettings!, transitionContext context: Any!, lifecycleActionType actionType: UInt32) {
            settings.interruptionPolicy = 0
            //settings.peripheryInsets = vc.view.window?.safeAreaInsets ?? .zero
            vc.presenter.scene.updateSettings(settings, withTransitionContext: context, completion: nil)
            // Not sure what actionType 2 is, but it's only set when this scene enters foreground, so we can pass URL scheme here
            if actionType == 2, let launchUrl = UserDefaults.standard.string(forKey: "launchAppUrlScheme") {
                UserDefaults.standard.removeObject(forKey: "launchAppUrlScheme")
                vc.openURLScheme(launchUrl)
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onAppInitialize: onAppInitialize, onReturnHome: onReturnHome, onExit: {
            show = false
        })
    }
    
    func makeUIViewController(context: Context) -> UIViewController {
        guard let controller = AppSceneViewController(bundleId: bundleId, dataUUID: dataUUID, delegate: context.coordinator) else {
            return UIViewController()
        }
        return controller
    }
    
    func updateUIViewController(_ vc: UIViewController, context _: Context) {
        if let vc = vc as? AppSceneViewController {
            if !show {
                vc.terminate()
            }
        }
    }
}

@available(iOS 16.1, *)
struct MultitaskAppWindow: View {
    @State var show = true
    @State var pid = 0
    @State var appInfo: MultitaskAppInfo? = nil
    @State var errorMessage: String? = nil
    @State private var hasScheduledAutoClose = false
    @State private var didRequestManualClose = false
    @EnvironmentObject var sceneDelegate: SceneDelegate
    @Environment(\.openWindow) var openWindow
    @AppStorage("LCMultitaskMode", store: LCUtils.appGroupUserDefault) var multitaskMode: MultitaskMode = .virtualWindow
    @AppStorage("LCSkipTerminatedScreen", store: LCUtils.appGroupUserDefault) var skipTerminatedScreen = false
    let pub = NotificationCenter.default.publisher(for: UIScene.didDisconnectNotification)
    init(id: String) {
        guard let appInfo = MultitaskWindowManager.appDict[id] else {
            return
        }
        _appInfo = State(initialValue: appInfo)
    }
    
    var body: some View {
        let isVirtualWindowMode = multitaskMode == .virtualWindow
        Group {
            if show, let appInfo {
                ZStack(alignment: .topTrailing) {
                    GeometryReader { geometry in
                        AppSceneViewSwiftUI(show: $show, bundleId: appInfo.bundleId, dataUUID: appInfo.dataUUID, initSize: geometry.size,
                                            onAppInitialize: { pid, error in
                            DispatchQueue.main.async {
                                if error == nil {
                                    self.pid = Int(pid)
                                } else {
                                    self.errorMessage = error?.localizedDescription
                                }
                                DataManager.shared.model.pidCallback?(NSNumber(value: pid), error)
                                DataManager.shared.model.pidCallback = nil
                            }
                        }, onReturnHome: {
                            returnToLibrary(openingSwitcher: false)
                        })
                        .background(.black)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .ignoresSafeArea(.all, edges: .all)
                    .navigationTitle(Text("\(appInfo.displayName) - \(String(pid))"))
                    Menu {
                        Button("ryc0.switcher.home".loc, systemImage: "house") {
                            returnToLibrary(openingSwitcher: false)
                        }
                        Button("ryc0.switcher.title".loc, systemImage: "rectangle.stack") {
                            returnToLibrary(openingSwitcher: true)
                        }
                    } label: {
                        Image(systemName: "rectangle.stack")
                            .frame(width: 44, height: 44)
                            .background(.regularMaterial, in: Circle())
                    }
                    .accessibilityLabel("ryc0.switcher.controls".loc)
                    .padding(8)
                }
                
            } else if skipTerminatedScreen && isVirtualWindowMode, appInfo != nil {
                Color.clear
                    .ignoresSafeArea(.all, edges: .all)
                    .onAppear {
                        guard !didRequestManualClose else { return }
                        if let appInfo {
                            MultitaskRelaunchManager.scheduleRelaunchIfNeeded(bundleId: appInfo.bundleId, dataUUID: appInfo.dataUUID, isManualTermination: false)
                        }
                        if !hasScheduledAutoClose {
                            hasScheduledAutoClose = true
                            DispatchQueue.main.async {
                                requestSceneDestruction(isManual: false)
                            }
                        }
                    }
            } else {
                VStack {
                    Text("lc.multitaskAppWindow.appTerminated".loc)
                        .font(.largeTitle)
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(.body, design: .monospaced))
                        Button("lc.common.copy".loc) {
                            UIPasteboard.general.string = errorMessage
                            requestSceneDestruction(isManual: true)
                        }
                        .buttonStyle(.bordered)
                    }
                    Button("lc.common.close".loc) {
                        requestSceneDestruction(isManual: true)
                    }
                    .buttonStyle(.bordered)
                }.onAppear {
                    // appInfo == nil indicates this is the first scene opened in this launch. We don't want this so we open lc's main scene and close this view
                    // however lc's main view may already be starting in another scene so we wait a bit before opening the main view
                    // also we have to keep the view open for a little bit otherwise lc will be killed by iOS
                    if appInfo == nil {
                        if DataManager.shared.model.mainWindowOpened {
                            requestSceneDestruction()
                        } else {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                if !DataManager.shared.model.mainWindowOpened {
                                    openWindow(id: "Main")
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    requestSceneDestruction()
                                }
                            }
                        }
                    }
                }
            }
        }
        .onReceive(pub) { out in
            if let scene1 = sceneDelegate.window?.windowScene, let scene2 = out.object as? UIWindowScene, scene1 == scene2 {
                // recorded on every screen, so a later launch knows this window is gone once its session is
                if let appInfo {
                    MultitaskWindowManager.recordDisconnectedSession(scene2.session.persistentIdentifier, for: appInfo)
                }
                show = false
            }
        }
    }
    
    private func returnToLibrary(openingSwitcher: Bool) {
        if let session = MainWindow.scene?.session {
            MainWindow.showHome(openingSwitcher: openingSwitcher)
            UIApplication.shared.requestSceneSessionActivation(session, userActivity: nil, options: nil)
        } else {
            LCSharedUtils.setAppSwitcherRequested(openingSwitcher)
            openWindow(id: "Main")
        }
    }

    private func requestSceneDestruction(isManual: Bool = false) {
        if isManual {
            didRequestManualClose = true
        }
        guard let session = sceneDelegate.window?.windowScene?.session else { return }
        // this window is going away, so the next launch takes the full way
        if let appInfo { MultitaskWindowManager.removeAppInfo(appInfo) }
        UIApplication.shared.requestSceneSessionDestruction(session, options: nil) { error in
            print(error)
        }
    }
}

@objcMembers
class MultitaskRelaunchManager: NSObject {
    private static var pendingKeys: Set<String> = []
    private static let pendingLock = NSLock()
    
    static func scheduleRelaunchIfNeeded(bundleId: String, dataUUID: String, isManualTermination: Bool) {
        let defaults = LCUtils.appGroupUserDefault
        let multitaskMode = MultitaskMode(rawValue: defaults.integer(forKey: "LCMultitaskMode")) ?? .virtualWindow
        guard defaults.bool(forKey: "LCSkipTerminatedScreen"),
              defaults.bool(forKey: "LCRestartTerminatedApp"),
              multitaskMode == .virtualWindow,
              !isManualTermination else { return }
        
        let key = "\(bundleId)#\(dataUUID)"
        guard markPendingIfNeeded(key: key) else { return }
        
        Task {
            defer { clearPending(key: key) }
            try? await Task.sleep(nanoseconds: 500_000_000)
            await relaunchApp(bundleId: bundleId, dataUUID: dataUUID)
        }
    }
    
    private static func markPendingIfNeeded(key: String) -> Bool {
        pendingLock.lock()
        defer { pendingLock.unlock() }
        if pendingKeys.contains(key) {
            return false
        }
        pendingKeys.insert(key)
        return true
    }
    
    private static func clearPending(key: String) {
        pendingLock.lock()
        pendingKeys.remove(key)
        pendingLock.unlock()
    }
    
    private static func relaunchApp(bundleId: String, dataUUID: String) async {
        guard let appModel = await MainActor.run(body: { lookupAppModel(bundleId: bundleId) }),
              appModel.appInfo.lastLaunched.distance(to: .now) > 2
        else {
            return
        }
        
        do {
            try await appModel.runApp(multitask: true, containerFolderName: dataUUID)
        } catch {
            print("Failed to restart \(bundleId): \(error)")
        }
    }
    
    @MainActor private static func lookupAppModel(bundleId: String) -> LCAppModel? {
        let sharedModel = DataManager.shared.model
        if let app = sharedModel.apps.first(where: { $0.appInfo.relativeBundlePath == bundleId }) {
            return app
        }
        return sharedModel.hiddenApps.first(where: { $0.appInfo.relativeBundlePath == bundleId })
    }
}

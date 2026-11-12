import SwiftUI
import UIKit

struct GuestZoomOrigin {
    let frame: CGRect
    let cornerRadius: CGFloat
    let isSwitcher: Bool

    init(iconFrame: CGRect) {
        frame = iconFrame
        cornerRadius = iconFrame.width * HomeDesign.iconCornerFraction
        isSwitcher = false
    }

    init(cardFrame: CGRect) {
        frame = cardFrame
        cornerRadius = min(cardFrame.width, cardFrame.height) * 0.16
        isSwitcher = true
    }
}

@MainActor
final class RYClockTapAction {
    private var pending: Task<Void, Never>?

    deinit { pending?.cancel() }

    func tap(home: @escaping @MainActor () -> Void, switcher: @escaping @MainActor () -> Void) {
        if pending != nil {
            cancel()
            switcher()
            return
        }
        pending = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(280)) }
            catch { return }
            guard let self else { return }
            self.pending = nil
            home()
        }
    }

    func cancel() {
        pending?.cancel()
        pending = nil
    }
}

/// A UIKit-owned surface above Home. Empty space passes touches through to Home.
@available(iOS 16.0, *)
struct FullScreenGuestStage: View {
    @ObservedObject private var session = FullScreenGuestSession.shared
    @Environment(HomeScreenModel.self) private var home

    var body: some View {
        Stage(homeOrigin: { bundle in
            guard let item = item(for: bundle), let frame = home.iconFrame(of: item) else { return nil }
            return GuestZoomOrigin(iconFrame: frame)
        }, presentGuest: { bundle in
            home.present(.guest(sourceID: item(for: bundle)?.id ?? bundle))
        }, dismissGuest: {
            if case .guest = home.presentedScreen { home.presentedScreen = nil }
        })
        .allowsHitTesting(session.isGuestVisible)
        .accessibilityHidden(!session.isGuestVisible)
    }

    private func item(for bundle: String) -> HomeItem? {
        home.apps.first { $0.value.appInfo.relativeBundlePath == bundle }.map { .app($0.key) }
    }

    private struct Stage: UIViewControllerRepresentable {
        let homeOrigin: (String) -> GuestZoomOrigin?
        let presentGuest: (String) -> Void
        let dismissGuest: () -> Void

        func makeUIViewController(context: Context) -> GuestStageController {
            let stage = GuestStageController()
            FullScreenGuestSession.shared.stage = stage
            return stage
        }

        func updateUIViewController(_ controller: GuestStageController, context: Context) {
            controller.homeOrigin = homeOrigin
            controller.presentGuest = presentGuest
            controller.dismissGuest = dismissGuest
        }
    }
}

final class GuestStageController: UIViewController {
    var homeOrigin: ((String) -> GuestZoomOrigin?)?
    var presentGuest: ((String) -> Void)?
    var dismissGuest: (() -> Void)?

    override func loadView() { view = GuestStageView() }

    private final class GuestStageView: UIView {
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            let hit = super.hitTest(point, with: event)
            return hit === self ? nil : hit
        }
    }
}

/// The cover owns the guest view only while it is on screen. The session keeps
/// the same guest controller and process when the cover is dismissed.
@available(iOS 18.0, *)
struct FullScreenGuestCover: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> Controller {
        let controller = Controller()
        FullScreenGuestSession.shared.attachToNativeCover(controller)
        return controller
    }

    func updateUIViewController(_ controller: Controller, context: Context) {}

    final class Controller: UIViewController {
        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            FullScreenGuestSession.shared.nativeCoverWillDisappear(self)
        }
    }
}

/// Holds the last ordinary, full-screen guest in its own process while Home
/// stays mounted. The window-mode manager handles explicitly windowed guests.
@available(iOS 16.0, *)
@MainActor
final class FullScreenGuestSession: NSObject, ObservableObject, @preconcurrency AppSceneViewControllerDelegate {
    static let shared = FullScreenGuestSession()
    weak var stage: GuestStageController?
    @Published private(set) var container: String?
    @Published private(set) var isGuestVisible = false
    @Published private(set) var previews: [String: UIImage] = [:]

    private var guest: AppSceneViewController?
    private var retiringGuest: AppSceneViewController?
    private var surface: GuestZoomSurface?
    private var launchOrigin: GuestZoomOrigin?
    private var starting = false
    private var pendingLaunch: CheckedContinuation<Int32, Error>?
    private var launchTimeout: Task<Void, Never>?
    private var firstFrameTimeout: Task<Void, Never>?
    private var presentationID = UUID()
    private var returning = false
    private var reopensAfterReturn = false
    private let clockTap = RYClockTapAction()
    private let clockFeedback = UIImpactFeedbackGenerator(style: .light)

    var runningBundlePath: String? {
        guard let guest, guest.isAppRunning else { return nil }
        return guest.bundleId
    }

    func isPresenting(bundle: String?) -> Bool {
        guest?.bundleId == bundle && (isGuestVisible || firstFrameTimeout != nil)
    }

    func resume(bundle: String, container: String, url: String?, from origin: GuestZoomOrigin? = nil) -> Bool {
        guard let guest, guest.bundleId == bundle, guest.dataUUID == container,
              guest.isAppRunning, pendingLaunch == nil else { return false }
        if let url { guest.openURLScheme(url) }
        if #available(iOS 18.0, *), returning {
            reopensAfterReturn = true
        } else if !isGuestVisible && firstFrameTimeout == nil {
            showGuest(from: origin)
        }
        return true
    }

    func launch(bundle: String, container: String, url: String?, from origin: GuestZoomOrigin? = nil) async throws -> Int32 {
        guard !starting else { throw "A guest is already opening." }
        guard let stage, let stageView = stage.viewIfLoaded, stageView.window != nil else {
            throw "The guest stage is unavailable. Return to Home and try again."
        }
        guard LCUtils.liveProcessBundleIdentifier() != nil else {
            throw "LiveProcess is required to open apps without restarting ryC0. Reinstall with Keep Extensions enabled."
        }

        starting = true
        defer { starting = false }
        if let previous = guest { removeGuest(previous) }
        if let previous = retiringGuest {
            let clock = ContinuousClock()
            // Allow time for the forced termination to take effect after the grace period.
            let deadline = clock.now + .seconds(previous.terminationGracePeriod + 1)
            while previous.isAppRunning && clock.now < deadline {
                try await Task.sleep(for: .milliseconds(75))
            }
            guard !previous.isAppRunning else { throw "The previous guest is still closing." }
            retiringGuest = nil
        }
        try Task.checkCancellation()

        return try await withCheckedThrowingContinuation { continuation in
            pendingLaunch = continuation
            launchOrigin = origin
            guard let controller = AppSceneViewController(bundleId: bundle, dataUUID: container,
                                                          fullScreenDelegate: self, launchURL: url) else {
                finishLaunch(.failure("LiveProcess could not open the guest."))
                return
            }

            guest = controller
            self.container = container
            MultitaskManager.shared.fullScreenContainer = container

            let surface = GuestZoomSurface(frame: stageView.bounds)
            surface.isHidden = true
            surface.accessibilityElementsHidden = true
            surface.accessibilityIdentifier = "ryc0.guest.host"
            mount(controller, surface: surface, in: stage)
            self.surface = surface

            launchTimeout = Task { [weak self, weak controller] in
                try? await Task.sleep(for: .seconds(12))
                guard !Task.isCancelled, let self, let controller, self.guest === controller else { return }
                self.finishLaunch(.failure("LiveProcess did not finish opening the guest."))
                self.removeGuest(controller)
            }
        }
    }

    func close(container: String) {
        guard let guest, guest.dataUUID == container else { return }
        removeGuest(guest)
    }

    private func showGuest(from origin: GuestZoomOrigin?) {
        guard let guest, let surface, let stage else { return }
        launchOrigin = nil
        configureReturnControl(for: guest, on: surface)
        if #available(iOS 18.0, *) {
            guard let bundle = guest.bundleId else { return }
            returning = false
            isGuestVisible = true
            guest.setHostedGuestVisible(true)
            if origin?.isSwitcher == true {
                var transaction = Transaction(animation: nil)
                transaction.disablesAnimations = true
                withTransaction(transaction) { stage.presentGuest?(bundle) }
            } else {
                stage.presentGuest?(bundle)
            }
            return
        }
        let bounds = stage.view.bounds
        if origin?.isSwitcher == true {
            surface.reset(in: bounds)
            surface.alpha = 1
            surface.isHidden = false
            surface.isUserInteractionEnabled = true
            surface.accessibilityElementsHidden = false
            isGuestVisible = true
            guest.setHostedGuestVisible(true)
            return
        }
        let id = UUID()
        presentationID = id
        returning = false
        let origin = UIAccessibility.isReduceMotionEnabled ? nil : origin.flatMap { bounds.intersects($0.frame) ? $0 : nil }
        surface.autoresizesSubviews = false
        if surface.isHidden {
            surface.move(to: origin, in: bounds)
            surface.alpha = origin == nil ? 0 : 1
        }
        surface.isHidden = false
        surface.isUserInteractionEnabled = true
        surface.accessibilityElementsHidden = false
        surface.accessibilityViewIsModal = true
        isGuestVisible = true
        guest.setHostedGuestVisible(true)
        animateZoom(fadeOnly: origin == nil) {
            surface.alpha = 1
            surface.returnControl?.alpha = 1
            surface.move(to: nil, in: bounds)
        } completion: { [weak self, weak stage] in
            guard self?.presentationID == id, let stage else { return }
            surface.reset(in: stage.view.bounds)
        }
    }

    private func mount(_ guest: AppSceneViewController, surface: GuestZoomSurface, in parent: UIViewController) {
        if guest.parent != nil { unmount(guest, surface: surface) }
        parent.addChild(guest)
        parent.view.addSubview(surface)
        surface.reset(in: parent.view.bounds)
        if guest.view.superview == nil {
            surface.content.addSubview(guest.view)
            guest.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        }
        guest.view.frame = surface.content.bounds
        guest.didMove(toParent: parent)
        surface.attachFloatingControl(to: parent)
    }

    private func unmount(_ guest: AppSceneViewController, surface: GuestZoomSurface) {
        guest.willMove(toParent: nil)
        surface.detachFloatingControl()
        surface.removeFromSuperview()
        guest.removeFromParent()
    }

    func attachToNativeCover(_ cover: UIViewController) {
        guard let guest, let surface, isGuestVisible else { return }
        surface.isHidden = false
        surface.accessibilityElementsHidden = false
        mount(guest, surface: surface, in: cover)
    }

    func nativeCoverWillDisappear(_ cover: UIViewController) {
        guard let guest, guest.parent === cover, !returning else { return }
        clockTap.cancel()
        capturePreview(of: guest)
    }

    func nativeCoverDidClose() {
        guard isGuestVisible, let guest, let surface else { return }
        isGuestVisible = false
        returning = false
        surface.isHidden = true
        surface.accessibilityElementsHidden = true
        guest.setHostedGuestVisible(false)
        unmount(guest, surface: surface)
        if reopensAfterReturn {
            reopensAfterReturn = false
            Task { [weak self, weak guest] in
                guard let self, let guest, self.guest === guest, !self.isGuestVisible else { return }
                self.showGuest(from: nil)
            }
        }
    }

    private func animateZoom(fadeOnly: Bool, animations: @escaping () -> Void, completion: @escaping () -> Void) {
        UIView.animate(withDuration: fadeOnly ? 0.16 : 0.42, delay: 0,
                       usingSpringWithDamping: 0.88, initialSpringVelocity: 0,
                       options: [.beginFromCurrentState, .allowUserInteraction],
                       animations: animations) { _ in completion() }
    }

    private func removeGuest(_ controller: AppSceneViewController, terminate: Bool = true) {
        guard guest === controller else { return }
        clockTap.cancel()
        if #available(iOS 18.0, *), isGuestVisible { stage?.dismissGuest?() }
        firstFrameTimeout?.cancel()
        firstFrameTimeout = nil
        reopensAfterReturn = false
        finishLaunch(.failure("The guest closed while opening."))
        if terminate {
            retiringGuest = controller
            controller.terminate()
            controller.appTerminationCleanUp()
        }
        controller.willMove(toParent: nil)
        controller.view.removeFromSuperview()
        controller.removeFromParent()
        surface?.detachFloatingControl()
        surface?.removeFromSuperview()
        surface = nil
        if let container { previews.removeValue(forKey: container) }
        guest = nil
        container = nil
        isGuestVisible = false
        MultitaskManager.shared.fullScreenContainer = nil
        returning = false
    }

    private func finishLaunch(_ result: Result<Int32, Error>) {
        launchTimeout?.cancel()
        launchTimeout = nil
        if case .failure = result { launchOrigin = nil }
        let continuation = pendingLaunch
        pendingLaunch = nil
        continuation?.resume(with: result)
    }

    func appSceneVC(_ vc: AppSceneViewController!, didInitializeWithError error: (any Error)!) {
        // Initializer errors can be delivered before the controller is attached.
        if let error {
            guard guest == nil || guest === vc else { return }
            if pendingLaunch == nil, guest != nil { MainWindow.guestErrors.send(error.localizedDescription) }
            finishLaunch(.failure(error))
            if let vc, guest === vc { removeGuest(vc, terminate: false) }
            return
        }
        guard guest === vc, pendingLaunch != nil else { return }
        if #available(iOS 18.0, *), !vc.hostedGuestHasDrawn {
            // JIT may need the PID before the guest can draw. Keep Home
            // visible until the guest has a frame or the short wait expires.
            firstFrameTimeout = Task { [weak self, weak vc] in
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled, let vc else { return }
                self?.appSceneVCGuestDidDraw(vc)
            }
        } else {
            showGuest(from: launchOrigin)
        }
        finishLaunch(.success(vc.pid))
    }

    func appSceneVCGuestDidDraw(_ vc: AppSceneViewController!) {
        guard guest === vc, firstFrameTimeout != nil else { return }
        firstFrameTimeout?.cancel()
        firstFrameTimeout = nil
        showGuest(from: launchOrigin)
    }

    func appSceneVCAppDidExit(_ vc: AppSceneViewController!) {
        guard let vc else { return }
        removeGuest(vc, terminate: false)
    }

    func appSceneVCRequestedHome(_ vc: AppSceneViewController!) {
        guard guest === vc, surface?.returnMode == .bar else { return }
        returnHome(openSwitcher: false)
    }

    func returnFromClockTap() -> Bool {
        guard isGuestVisible, surface?.returnMode == .clock, !returning,
              surface?.window?.windowScene?.activationState == .foregroundActive else { return false }
        clockFeedback.impactOccurred()
        clockFeedback.prepare()
        // Both the system status bar and the transparent overlay use this path.
        clockTap.tap(home: { [weak self] in self?.returnHome(openSwitcher: false) },
                     switcher: { [weak self] in self?.returnHome(openSwitcher: true) })
        return true
    }

    func appSceneVCWillActivateScene(_ vc: AppSceneViewController!) {
        vc.shouldSkipDebounceOnce = true
        vc.updateFrame(settingsBlock: nil)
    }

    private func configureReturnControl(for guest: AppSceneViewController, on surface: GuestZoomSurface) {
        var mode = LCSharedUtils.guestHomeControl()
        if mode == .floatingButton, let bundle = guest.bundleId {
            let model = DataManager.shared.model
            if (model.apps + model.hiddenApps).first(where: { $0.appInfo.relativeBundlePath == bundle })?.appInfo.hideHomeButton == true {
                mode = .bar
            }
        }
        guard surface.returnMode != mode else { return }
        surface.detachFloatingControl()
        surface.returnControl?.removeFromSuperview()
        surface.floatingControl = nil
        surface.returnMode = mode

        if mode == .floatingButton {
            let button = UIHostingController(rootView: GuestFloatingHomeButton(
                goHome: { [weak self] in self?.returnHome(openSwitcher: false) },
                openSwitcher: { [weak self] in self?.returnHome(openSwitcher: true) }
            ))
            surface.addFloatingControl(button, to: guest.parent)
            button.view.addGestureRecognizer(UILongPressGestureRecognizer(target: self, action: #selector(homeHeld(_:))))
        } else {
            surface.returnControl = addReturnButton(to: surface.content, mode: mode)
        }
    }

    private func addReturnButton(to surface: UIView, mode: LCGuestHomeControl) -> UIButton {
        let button = UIButton(type: .custom)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.accessibilityIdentifier = "ryc0.guest.home"
        button.accessibilityLabel = "ryc0.home.homeButton".loc
        button.addAction(UIAction { [weak self] _ in
            if mode == .clock { _ = self?.returnFromClockTap() }
            else { self?.returnHome(openSwitcher: false) }
        }, for: .touchUpInside)
        button.accessibilityCustomActions = [
            UIAccessibilityCustomAction(name: "ryc0.switcher.title".loc) { [weak self] _ in
                self?.returnHome(openSwitcher: true)
                return true
            }
        ]
        surface.addSubview(button)

        if mode == .clock {
            clockFeedback.prepare()
            button.addAction(UIAction { [weak self] _ in self?.clockFeedback.prepare() }, for: .touchDown)
            let safeTop = button.bottomAnchor.constraint(equalTo: surface.safeAreaLayoutGuide.topAnchor)
            safeTop.priority = .defaultHigh
            NSLayoutConstraint.activate([
                button.topAnchor.constraint(equalTo: surface.topAnchor),
                button.leadingAnchor.constraint(equalTo: surface.leadingAnchor),
                button.widthAnchor.constraint(equalToConstant: 112),
                button.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
                safeTop
            ])
            return button
        }

        button.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        button.layer.cornerRadius = 15
        let bar = UIView()
        bar.translatesAutoresizingMaskIntoConstraints = false
        bar.backgroundColor = UIColor.white.withAlphaComponent(0.92)
        bar.layer.cornerRadius = 2.5
        bar.isUserInteractionEnabled = false
        button.addSubview(bar)
        NSLayoutConstraint.activate([
            bar.centerXAnchor.constraint(equalTo: button.centerXAnchor),
            bar.centerYAnchor.constraint(equalTo: button.centerYAnchor),
            bar.widthAnchor.constraint(equalToConstant: 42),
            bar.heightAnchor.constraint(equalToConstant: 5)
        ])
        button.addGestureRecognizer(UILongPressGestureRecognizer(target: self, action: #selector(homeHeld(_:))))
        button.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(homeDragged(_:))))
        let bottom = button.bottomAnchor.constraint(equalTo: surface.safeAreaLayoutGuide.bottomAnchor, constant: -5)
        bottom.priority = .defaultHigh
        NSLayoutConstraint.activate([
            button.centerXAnchor.constraint(equalTo: surface.centerXAnchor),
            button.bottomAnchor.constraint(lessThanOrEqualTo: surface.bottomAnchor, constant: -27),
            bottom,
            button.widthAnchor.constraint(equalToConstant: 84),
            button.heightAnchor.constraint(equalToConstant: 34)
        ])
        return button
    }

    @objc private func homeHeld(_ gesture: UILongPressGestureRecognizer) {
        if gesture.state == .began { returnHome(openSwitcher: true) }
    }

    @objc private func homeDragged(_ gesture: UIPanGestureRecognizer) {
        let movement = gesture.translation(in: gesture.view)
        if gesture.state == .ended, -movement.y > max(28, abs(movement.x)) {
            returnHome(openSwitcher: false)
        }
    }

    func returnHome(openSwitcher: Bool) {
        clockTap.cancel()
        if #available(iOS 18.0, *) {
            if firstFrameTimeout != nil, let guest, let surface {
                firstFrameTimeout?.cancel()
                firstFrameTimeout = nil
                guest.setHostedGuestVisible(false)
                unmount(guest, surface: surface)
                MainWindow.homeRequests.send(openSwitcher)
                return
            }
            guard let guest, isGuestVisible, !returning else { return }
            returning = true
            if openSwitcher {
                prepareSwitcherEntry(from: guest) {
                    var transaction = Transaction(animation: nil)
                    transaction.disablesAnimations = true
                    withTransaction(transaction) { MainWindow.homeRequests.send(true) }
                }
            } else {
                capturePreview(of: guest)
                MainWindow.homeRequests.send(false)
            }
            return
        }
        guard let guest, let surface, let stage, !surface.isHidden, !returning else { return }
        returning = true
        if openSwitcher {
            prepareSwitcherEntry(from: guest) {
                surface.isHidden = true
                surface.accessibilityElementsHidden = true
                self.isGuestVisible = false
                guest.setHostedGuestVisible(false)
                MainWindow.homeRequests.send(true)
                self.returning = false
            }
            return
        }
        let bounds = stage.view.bounds
        let id = UUID()
        presentationID = id
        capturePreview(of: guest)
        surface.isUserInteractionEnabled = false
        surface.accessibilityElementsHidden = true
        surface.accessibilityViewIsModal = false
        isGuestVisible = false
        MainWindow.homeRequests.send(openSwitcher)

        let origin: GuestZoomOrigin?
        if UIAccessibility.isReduceMotionEnabled {
            origin = nil
        } else {
            origin = guest.bundleId.flatMap { stage.homeOrigin?($0) }
        }

        surface.autoresizesSubviews = false
        let button = surface.returnControl
        UIView.animate(withDuration: 0.12) { button?.alpha = 0 }
        let privatePreview = openSwitcher && !canShowPreview(for: guest.bundleId)
        if origin != nil && !privatePreview && !openSwitcher {
            UIView.animate(withDuration: 0.16, delay: 0.14, options: [.beginFromCurrentState, .allowUserInteraction]) {
                surface.alpha = 0
            }
        }
        animateZoom(fadeOnly: origin == nil) {
            surface.move(to: origin, in: bounds)
            if origin == nil || privatePreview { surface.alpha = 0 }
        } completion: { [weak self, weak guest, weak stage] in
            guard let self, self.presentationID == id, let guest, self.guest === guest, let stage else { return }
            surface.isHidden = true
            surface.reset(in: stage.view.bounds)
            button?.alpha = 1
            guest.setHostedGuestVisible(false)
            self.returning = false
        }
    }

    private func canShowPreview(for bundle: String?) -> Bool {
        guard let bundle else { return false }
        return DataManager.shared.model.apps.contains {
            $0.appInfo.relativeBundlePath == bundle && !$0.appInfo.isLocked && !$0.appInfo.isHidden
        }
    }

    private func prepareSwitcherEntry(from guest: AppSceneViewController, ready: @escaping @MainActor () -> Void) {
        var finished = false
        let complete = { [weak self, weak guest] in
            guard !finished, let self, let guest, self.guest === guest else { return }
            finished = true
            ready()
        }
        capturePreview(of: guest, completion: complete)
        // The current scene stays visible until its preview arrives. A guest
        // that cannot supply an image still gets a bounded, responsive return.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18, execute: complete)
    }

    private func capturePreview(of guest: AppSceneViewController, completion: (() -> Void)? = nil) {
        guard let bundle = guest.bundleId, canShowPreview(for: bundle) else { completion?(); return }
        guest.requestHostedGuestPreview { [weak self, weak guest] image in
            defer { completion?() }
            guard let self, let guest, self.guest === guest, let image, let container = guest.dataUUID,
                  self.canShowPreview(for: bundle) else { return }
            self.previews[container] = image
            MainWindow.saveSwitcherPreview(image, for: bundle)
        }
    }
}

private struct GuestFloatingHomeButton: View {
    let goHome: () -> Void
    let openSwitcher: () -> Void

    var body: some View {
        HomeButton(action: goHome)
            .accessibilityIdentifier("ryc0.guest.floating-home")
            .accessibilityAction(named: Text("ryc0.switcher.title".loc), openSwitcher)
    }
}

/// Keep the hosted scene at its native size while the visible viewport zooms.
/// The contents keep their aspect ratio as the rounded mask shrinks to an icon.
private final class GuestZoomSurface: UIView {
    let content = UIView()
    weak var returnControl: UIView?
    var returnMode: LCGuestHomeControl?
    var floatingControl: UIHostingController<GuestFloatingHomeButton>?
    private var isDraggingControl = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        autoresizingMask = [.flexibleWidth, .flexibleHeight]
        backgroundColor = .black
        layer.cornerCurve = .continuous
        clipsToBounds = true
        content.frame = bounds
        content.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(content)
    }

    required init?(coder: NSCoder) { nil }

    override func layoutSubviews() {
        super.layoutSubviews()
        if !isDraggingControl, let control = floatingControl?.view {
            control.center = savedButtonCenter(in: floatingArea)
        }
    }

    func addFloatingControl(_ controller: UIHostingController<GuestFloatingHomeButton>, to parent: UIViewController?) {
        floatingControl = controller
        let size = HomeDesign.homeButtonSize
        let control = controller.view!
        control.backgroundColor = .clear
        control.frame = CGRect(x: 0, y: 0, width: size, height: size)
        control.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(dragFloatingControl(_:))))
        if let parent { parent.addChild(controller) }
        content.addSubview(control)
        if let parent { controller.didMove(toParent: parent) }
        returnControl = control
        setNeedsLayout()
    }

    func attachFloatingControl(to parent: UIViewController) {
        guard let floatingControl, floatingControl.parent == nil else { return }
        parent.addChild(floatingControl)
        floatingControl.didMove(toParent: parent)
    }

    func detachFloatingControl() {
        guard let floatingControl, floatingControl.parent != nil else { return }
        floatingControl.willMove(toParent: nil)
        floatingControl.removeFromParent()
    }

    private var floatingArea: CGRect {
        let inset = HomeDesign.homeButtonSize / 2 + 6
        let area = content.bounds.inset(by: content.safeAreaInsets).insetBy(dx: inset, dy: inset)
        return area.isEmpty ? CGRect(x: content.bounds.midX, y: content.bounds.midY, width: 0, height: 0) : area
    }

    private func savedButtonCenter(in area: CGRect) -> CGPoint {
        let saved = UserDefaults.standard.dictionary(forKey: "RYC0HomeButtonPlacement")
        let storedFraction = saved?["fraction"] as? Double ?? 0.62
        let fraction = storedFraction.isFinite ? min(max(storedFraction, 0), 1) : 0.62
        let x = area.minX + fraction * area.width
        let y = area.minY + fraction * area.height
        switch saved?["edge"] as? Int {
        case 0: return CGPoint(x: area.minX, y: y)
        case 2: return CGPoint(x: x, y: area.minY)
        case 3: return CGPoint(x: x, y: area.maxY)
        default: return CGPoint(x: area.maxX, y: y)
        }
    }

    @objc private func dragFloatingControl(_ gesture: UIPanGestureRecognizer) {
        guard let control = gesture.view else { return }
        let area = floatingArea
        switch gesture.state {
        case .began: isDraggingControl = true
        case .changed:
            let delta = gesture.translation(in: content)
            control.center.x = min(max(control.center.x + delta.x, area.minX), area.maxX)
            control.center.y = min(max(control.center.y + delta.y, area.minY), area.maxY)
            gesture.setTranslation(.zero, in: content)
        case .ended, .cancelled:
            isDraggingControl = false
            let point = control.center
            let distances = [point.x - area.minX, area.maxX - point.x,
                             3 * (point.y - area.minY), 3 * (area.maxY - point.y)]
            let edge = distances.indices.min { distances[$0] < distances[$1] } ?? 1
            let fraction = edge < 2 ? (point.y - area.minY) / max(1, area.height) : (point.x - area.minX) / max(1, area.width)
            UserDefaults.standard.set(["edge": edge, "fraction": fraction], forKey: "RYC0HomeButtonPlacement")
            UIView.animate(withDuration: 0.24) { control.center = self.savedButtonCenter(in: area) }
        default: break
        }
    }

    func move(to origin: GuestZoomOrigin?, in fullBounds: CGRect) {
        let frame = origin?.frame ?? fullBounds
        let scale = max(frame.width / max(1, fullBounds.width), frame.height / max(1, fullBounds.height))
        bounds.size = frame.size
        center = CGPoint(x: frame.midX, y: frame.midY)
        content.center = CGPoint(x: bounds.midX, y: bounds.midY)
        content.transform = CGAffineTransform(scaleX: scale, y: scale)
        layer.cornerRadius = origin?.cornerRadius ?? 0
    }

    func reset(in fullBounds: CGRect) {
        move(to: nil, in: fullBounds)
        content.frame = bounds
        autoresizesSubviews = true
    }
}

//
//  MainWindow.swift
//  LiveContainerSwiftUI
//

import Combine
import UIKit

/// Finds ryC0's main window, the one showing the Home Screen, for the
/// code that adds views to it or presents over it: multitasking's virtual
/// windows and their dock, and app windows launched from Objective-C. On iPad
/// several scenes can be connected at once, such as an app's own window or a
/// second ryC0 window about to close, so the first connected scene could
/// be any of them. HomeRouter records the scene it accepts as the main window.
@objc final class MainWindow: NSObject {
    /// The scene HomeRouter accepted as the main window, until it disconnects.
    static weak var scene: UIWindowScene?
    static let homeRequests = PassthroughSubject<Bool, Never>()
    static let guestErrors = PassthroughSubject<String, Never>()
    static private(set) var switcherPreviews: [String: UIImage] = [:]
    private static let previewCache = DispatchQueue(label: "ryc0.switcher.previews", qos: .utility)
    private static let decodedPreviews: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.totalCostLimit = 24 * 1024 * 1024
        return cache
    }()

    static func saveSwitcherPreview(_ image: UIImage?, for bundle: String) {
        cachePreview(image, for: bundle)
        previewCache.async {
            LCSharedUtils.setSwitcherPreview(image, forBundlePath: bundle)
            cachePreview(image, for: bundle)
        }
    }

    static func loadSwitcherPreview(for bundle: String) async -> UIImage? {
        if let image = decodedPreviews.object(forKey: bundle as NSString) { return image }
        return await withCheckedContinuation { continuation in
            previewCache.async {
                let source = LCSharedUtils.switcherPreview(forBundlePath: bundle)
                let image = source?.preparingForDisplay() ?? source
                cachePreview(image, for: bundle)
                continuation.resume(returning: image)
            }
        }
    }

    private static func cachePreview(_ image: UIImage?, for bundle: String) {
        guard let image else {
            decodedPreviews.removeObject(forKey: bundle as NSString)
            return
        }
        let pixels = image.cgImage
        decodedPreviews.setObject(image, forKey: bundle as NSString,
                                  cost: (pixels?.bytesPerRow ?? 0) * (pixels?.height ?? 0))
    }

    static func removeSwitcherPreview(for container: String) {
        switcherPreviews.removeValue(forKey: container)
    }

    @objc static func showHome(openingSwitcher: Bool) {
        captureSwitcherPreviews()
        MultitaskDockManager.shared.minimizeAllWindows()
        homeRequests.send(openingSwitcher)
    }

    @MainActor @objc static func returnFromGuestClockTap() -> Bool {
        if #available(iOS 16.0, *) {
            return FullScreenGuestSession.shared.returnFromClockTap()
        }
        return false
    }

    private static func captureSwitcherPreviews() {
        let windows = MultitaskManager.shared.windows
        switcherPreviews = switcherPreviews.filter { windows[$0.key]?.controller != nil }
        for (folder, window) in windows {
            guard let controller = window.controller,
                  let view = controller.viewIfLoaded, view.window != nil, !view.isHidden,
                  controller.parent?.viewIfLoaded?.isHidden != true,
                  !view.bounds.isEmpty,
                  DataManager.shared.model.apps.contains(where: {
                      $0.appInfo.relativeBundlePath == controller.bundleId && !$0.appInfo.isHidden && !$0.appInfo.isLocked
                  }) else { continue }
            let format = UIGraphicsImageRendererFormat()
            format.scale = min(1, 520 / max(view.bounds.width, view.bounds.height))
            var drawn = false
            let image = UIGraphicsImageRenderer(bounds: view.bounds, format: format).image { _ in
                drawn = view.drawHierarchy(in: view.bounds, afterScreenUpdates: false)
            }
            if drawn { switcherPreviews[folder] = image }
        }
    }

    /// The main window. Before HomeRouter has accepted one, it's the window of
    /// the scene in the foreground, or of any scene, which on iPhone is always
    /// the only one.
    @objc static var window: UIWindow? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let fallback = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        guard let found = scene ?? fallback else {
            return nil
        }
        return found.keyWindow ?? found.windows.first
    }

    /// Whether a scene is the main window's, or could be: before HomeRouter
    /// has accepted a scene, any scene counts, so the first window to open
    /// isn't left out while it lays out.
    static func isMain(_ candidate: UIWindowScene?) -> Bool {
        guard let scene else {
            return true
        }
        return scene === candidate
    }
}

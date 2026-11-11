//
//  MultitaskManager.swift
//  LiveContainer
//
//  Created by s s on 2026/3/20.
//

import SwiftUI

enum MultitaskMode : Int {
    case virtualWindow = 0
    case nativeWindow = 1
}

@objc class MultitaskManager: NSObject, ObservableObject {
    static let shared = MultitaskManager()

    struct RunningWindow {
        weak var controller: AppSceneViewController?
    }

    // The extension lifecycle updates this only on the main thread.
    @Published private(set) var windows: [String: RunningWindow] = [:]
    // Reserve the ordinary full-screen guest's data without listing it as a window.
    var fullScreenContainer: String?

    @objc class func register(_ controller: AppSceneViewController) {
        guard let folder = controller.dataUUID else { return }
        shared.windows[folder] = RunningWindow(controller: controller)
    }

    @objc class func unregister(_ controller: AppSceneViewController) {
        guard let folder = controller.dataUUID else { return }
        // A callback from an older launch must not remove a newer window.
        if shared.windows[folder]?.controller === controller {
            shared.windows.removeValue(forKey: folder)
        }
    }

    @objc class func isUsing(container: String) -> Bool {
        shared.windows[container]?.controller != nil || shared.fullScreenContainer == container
    }

    @objc class func ownsWindowProcess(_ pid: Int32) -> Bool {
        shared.windows.values.contains { $0.controller?.pid == pid }
    }

    @objc class func isMultitasking() -> Bool {
        shared.windows.values.contains { $0.controller != nil }
    }

    func close(container: String) {
        guard let controller = windows[container]?.controller else { return }
        if !controller.isNativeWindow {
            (controller.parent as? DecoratedAppSceneViewController)?.closeWindow()
            return
        }
        if let info = MultitaskWindowManager.appDict[container] {
            MultitaskWindowManager.removeAppInfo(info)
        }
        controller.terminate()
        if let scene = controller.viewIfLoaded?.window?.windowScene, scene !== MainWindow.scene {
            UIApplication.shared.requestSceneSessionDestruction(scene.session, options: nil)
        }
    }
}

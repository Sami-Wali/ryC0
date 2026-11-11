import Foundation

enum BundledStore {
    static let bundleIdentifier = "com.ry0.ryP0"
    static let provisionedKey = "RYC0ProvisionedRyP0"
    static let notificationTestContainer = "ryp0-notification-test"

    static func notificationTestIdentifier(for bundlePath: String) -> String {
        "ryc0.ryp0.test.\(bundlePath)"
    }
}

extension AppLaunchCoordinator {
    var hasBundledStore: Bool {
        (sharedModel.apps + sharedModel.hiddenApps).contains {
            $0.appInfo.bundleIdentifier() == BundledStore.bundleIdentifier
        }
    }

    func installBundledStoreIfNeeded() async {
        guard sharedModel.multiLCStatus != 2,
              !UserDefaults.standard.bool(forKey: BundledStore.provisionedKey),
              let package = Bundle.main.url(forResource: "ryP0", withExtension: "ipa") else { return }
        do {
            if !hasBundledStore {
                _ = try await installReceivedIPA(at: package, isOwnCopy: true, policy: .bundledStore)
            }
            if hasBundledStore {
                UserDefaults.standard.set(true, forKey: BundledStore.provisionedKey)
            }
        } catch {
            errorMessage = "ryP0: \(error.localizedDescription)"
        }
    }
}

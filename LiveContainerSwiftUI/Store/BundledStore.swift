import Foundation

enum BundledStore {
    static let bundleIdentifier = "com.ry0.ryP0"
    static let sdkMigrationKey = "RYC0RyP0SDKVersionMigrated"
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
        guard sharedModel.multiLCStatus != 2 else { return }
        // Upgrade existing copies once, before the provisioning early return.
        // A later manual change in App Settings remains the user's choice.
        if !UserDefaults.standard.bool(forKey: BundledStore.sdkMigrationKey) {
            let stores = (sharedModel.apps + sharedModel.hiddenApps).filter {
                $0.appInfo.bundleIdentifier() == BundledStore.bundleIdentifier
            }
            for app in stores { app.uiSpoofSDKVersion = true }
            if !stores.isEmpty && stores.allSatisfy({ $0.appInfo.spoofSDKVersion }) {
                UserDefaults.standard.set(true, forKey: BundledStore.sdkMigrationKey)
            }
        }
        guard !UserDefaults.standard.bool(forKey: BundledStore.provisionedKey),
              let package = Bundle.main.url(forResource: "ryP0", withExtension: "ipa") else { return }
        do {
            if !hasBundledStore {
                _ = try await installReceivedIPA(at: package, isOwnCopy: true, policy: .bundledStore)
            }
            if hasBundledStore {
                UserDefaults.standard.set(true, forKey: BundledStore.provisionedKey)
                // Fresh installs already use the shared SDK default.
                UserDefaults.standard.set(true, forKey: BundledStore.sdkMigrationKey)
            }
        } catch {
            errorMessage = "ryP0: \(error.localizedDescription)"
        }
    }
}

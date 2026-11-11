import Foundation

/// Validation state for the certificate imported into ryC0.
enum SigningCertificate {
    static var lastCheckPassed: Bool? {
        get { UserDefaults.standard.object(forKey: "RYC0LastSetupCheckPassed") as? Bool }
        set {
            if let newValue {
                UserDefaults.standard.set(newValue, forKey: "RYC0LastSetupCheckPassed")
            } else {
                UserDefaults.standard.removeObject(forKey: "RYC0LastSetupCheckPassed")
            }
        }
    }

    @MainActor
    static func validateJITLessSetup() async -> (Bool, Error?) {
        let previous = runningCheck
        let check = Task { @MainActor in
            _ = await previous?.value
            return await signTestLibrary()
        }
        runningCheck = check
        return await check.value
    }

    /// The last JIT-less check started, which the next one waits for.
    @MainActor private static var runningCheck: Task<(Bool, Error?), Never>?

    /// LCUtils.validateJITLessSetup waits for ZSign on the calling thread, so
    /// it runs off the main thread here; it reports back on the main queue.
    private static func signTestLibrary() async -> (Bool, Error?) {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                LCUtils.validateJITLessSetup { success, error in
                    continuation.resume(returning: (success, error))
                }
            }
        }
    }
}

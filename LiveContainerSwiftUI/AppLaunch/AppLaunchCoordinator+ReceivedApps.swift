//
//  AppLaunchCoordinator+ReceivedApps.swift
//  LiveContainerSwiftUI
//

import Foundation

extension AppLaunchCoordinator {
    func installReceivedIPA(at file: URL, isOwnCopy: Bool, policy: AppInstallPolicy = .ask) async throws -> AppInstallOutcome {
        await waitForInstallTurn()
        isInstalling = true
        defer { isInstalling = false }

        if isOwnCopy {
            return try await installIpaFile(file, policy: policy)
        }
        return await installLocalIpa(file, policy: policy)
    }
}

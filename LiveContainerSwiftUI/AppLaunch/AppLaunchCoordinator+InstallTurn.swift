//
//  AppLaunchCoordinator+InstallTurn.swift
//  LiveContainerSwiftUI
//

import Observation

/// Installing one app at a time. Each install unpacks, moves and signs on its
/// own, and the questions it asks share one alert, so an install that would
/// start while another runs waits for its turn.
extension AppLaunchCoordinator {
    /// Waits while another install runs. It returns on the main actor with
    /// `isInstalling` false, so the caller can set it before anything else
    /// starts.
    func waitForInstallTurn() async {
        while isInstalling {
            await withCheckedContinuation { continuation in
                withObservationTracking {
                    _ = isInstalling
                } onChange: {
                    continuation.resume()
                }
            }
        }
    }
}

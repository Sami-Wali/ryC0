//
//  HomeHiddenApps.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The Hidden section at the end of search, like the Hidden folder of the
/// iOS App Library: it is always there, so it gives nothing away, and shows
/// the hidden apps once Face ID unlocks them. An app's menu there can stop
/// requiring Face ID, which brings it back to the Home Screen.
struct HomeHiddenApps: View {
    /// Where things go on this screen, for the icons' size.
    let metrics: HomeMetrics

    @EnvironmentObject private var sharedModel: SharedModel
    @Environment(AppLaunchCoordinator.self) private var coordinator

    var body: some View {
        VStack(spacing: HomeDesign.searchSpacing) {
            Button(action: unlock) {
                Label("ryc0.home.hidden".loc, systemImage: sharedModel.isHiddenAppUnlocked ? "eye.slash" : "lock.fill")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: HomeDesign.searchFieldHeight, alignment: .leading)
                    .padding(.horizontal, HomeDesign.searchPanelPadding)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .disabled(sharedModel.isHiddenAppUnlocked)

            if sharedModel.isHiddenAppUnlocked {
                if sharedModel.hiddenApps.isEmpty {
                    Text("ryc0.home.noHiddenApps".loc)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, HomeDesign.searchPanelPadding)
                } else {
                    HomeAppGrid(apps: sharedModel.hiddenApps, metrics: metrics)
                        .padding(.bottom, HomeDesign.searchPanelPadding)
                }
            }
        }
        .homeGlass(.rounded(HomeDesign.searchPanelCornerRadius))
    }

    /// Asks for Face ID, which shows the hidden apps until ryC0 quits.
    private func unlock() {
        Task {
            do {
                _ = try await LCUtils.authenticateUser()
            } catch {
                coordinator.errorMessage = error.localizedDescription
            }
        }
    }
}

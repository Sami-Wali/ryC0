//
//  OnboardingPendingInstallRow.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// One app on its way in, on Add Apps' checklist: its name, how far it has
/// come with a progress bar while it downloads or installs, and a check once
/// it's on the Home Screen.
struct OnboardingPendingInstallRow: View {
    let item: PendingInstall

    @Environment(AppLaunchCoordinator.self) private var coordinator

    var body: some View {
        OnboardingChecklistRow(systemImage: "arrow.down.app.fill", title: item.name, isDone: item.state == .installed) {
            VStack(alignment: .leading, spacing: OnboardingDesign.rowTextSpacing) {
                Text(status)
                    .foregroundStyle(isFailed ? Color.red : Color.secondary)

                if let progress {
                    ProgressView(value: progress)
                        .tint(OnboardingDesign.accent)
                }
            }
        }
    }

    private var isFailed: Bool {
        if case .failed = item.state {
            true
        } else {
            false
        }
    }

    private var status: String {
        switch item.state {
        case .downloading:
            "ryc0.onboarding.apps.downloading".loc
        case .waiting:
            "ryc0.onboarding.apps.waiting".loc
        case .installing:
            "ryc0.home.installing".loc
        case .installed:
            "ryc0.onboarding.apps.installed".loc
        case .notInstalled:
            "ryc0.onboarding.apps.notInstalled".loc
        case .failed(let reason):
            reason
        }
    }

    /// How far the download or the install has come, from 0 to 1, or nil
    /// while neither runs. The install's progress is the coordinator's,
    /// since it installs one app at a time.
    private var progress: Double? {
        switch item.state {
        case .downloading:
            item.downloadProgress
        case .installing:
            Double(coordinator.installProgress)
        case .waiting, .installed, .notInstalled, .failed:
            nil
        }
    }
}

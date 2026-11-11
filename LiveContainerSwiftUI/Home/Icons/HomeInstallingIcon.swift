//
//  HomeInstallingIcon.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The icon that holds a new app's place while it downloads and installs, as
/// iOS shows one: a dimmed tile with the progress pie, named "Loading…" while
/// the IPA downloads and "Installing…" while it is unpacked and signed.
struct HomeInstallingIcon: View {
    /// Where things go on this screen, for the icon's size.
    let metrics: HomeMetrics
    /// The download, while there is one.
    @ObservedObject var download: DownloadHelper

    @Environment(AppLaunchCoordinator.self) private var coordinator

    var body: some View {
        VStack(spacing: HomeDesign.labelSpacing) {
            RoundedRectangle(cornerRadius: metrics.iconCornerRadius)
                .fill(HomeDesign.iconPlaceholder)
                .frame(width: metrics.iconSize, height: metrics.iconSize)
                .overlay {
                    HomeProgressPie(progress: progress, cornerRadius: metrics.iconCornerRadius)
                }
            HomeIconLabel(title: title)
        }
        .frame(width: metrics.cellWidth, height: metrics.cellHeight, alignment: .top)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(Text(progress, format: .percent.precision(.fractionLength(0))))
    }

    private var progress: Double {
        download.isDownloading ? Double(download.downloadProgress) : Double(coordinator.installProgress)
    }

    private var title: String {
        download.isDownloading ? "lc.common.loading".loc : "ryc0.home.installing".loc
    }
}

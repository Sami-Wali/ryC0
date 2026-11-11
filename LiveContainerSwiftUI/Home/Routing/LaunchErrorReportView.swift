//
//  LaunchErrorReportView.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The full text of why the last app launch failed, to read, select and share.
/// When the 32-bit translation layer left a log, Share sends the log instead.
struct LaunchErrorReportView: View {
    /// The error the last launch left.
    let report: String

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(report)
                    .font(.caption.monospaced())
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
            }
            .navigationTitle("lc.common.error".loc)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if let log = UserDefaults.lcShared().url(forKey: "LC32BitTranslationLayerLogFile") {
                        ShareLink(item: log)
                    } else {
                        ShareLink(item: report)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("lc.common.ok".loc) {
                        dismiss()
                    }
                }
            }
        }
    }
}

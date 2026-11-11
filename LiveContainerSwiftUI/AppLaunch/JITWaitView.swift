//
//  JITWaitView.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The sheet shown while a JIT enabler attaches to an app: what to do, the
/// enabler's log, Cancel, and Launch Now to launch the app once JIT is on.
struct JITWaitView: View {
    /// What the JIT enabler has reported so far.
    let log: String
    /// The question the sheet answers: whether to launch the app.
    let prompt: AppLaunchPrompt<Bool>

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("lc.appBanner.waitForJitMsg".loc)
                    Text(log)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
            .navigationTitle("lc.appBanner.waitForJitTitle".loc)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("lc.common.cancel".loc, role: .cancel) {
                        prompt.answer(false)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("lc.appBanner.jitLaunchNow".loc) {
                        prompt.answer(true)
                    }
                }
            }
        }
    }
}

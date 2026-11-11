//
//  SigningCheckStatus.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// How one part of the setup stands, on the trailing side of its row: a
/// dashed circle until Check Setup looks at it, a spinner while it does, then
/// a check, an exclamation mark for an optional part that's missing, or a
/// cross. Each has its own symbol
/// as well as its color, and VoiceOver reads what it means.
struct SigningCheckStatus: View {
    let result: SigningCheckResult

    var body: some View {
        switch result {
        case .notChecked:
            Image(systemName: "circle.dashed")
                .imageScale(.large)
                .foregroundStyle(.tertiary)
                .accessibilityLabel("ryc0.settings.setup.notChecked".loc)
        case .checking:
            ProgressView()
                .controlSize(.small)
                .accessibilityLabel("lc.jitlessDiag.checking".loc)
        case .passed:
            Image(systemName: "checkmark.circle.fill")
                .imageScale(.large)
                .foregroundStyle(.green)
                .accessibilityLabel("ryc0.settings.setup.passed".loc)
        case .missing:
            Image(systemName: "exclamationmark.circle.fill")
                .imageScale(.large)
                .foregroundStyle(.orange)
                .accessibilityLabel("ryc0.settings.setup.missing".loc)
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .imageScale(.large)
                .foregroundStyle(.red)
                .accessibilityLabel("ryc0.settings.setup.failed".loc)
        }
    }
}

//
//  OnboardingSetupCheckRow.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// One part of the setup on Check Setup's checklist: what it is and does,
/// ticked off once it passed. Beside it is a spinner while it's checked, or
/// "Optional" when an optional part is missing, with what that costs under
/// its name. When it failed, why is under its name, in red.
struct OnboardingSetupCheckRow: View {
    let check: SigningSetupCheck
    let result: SigningCheckResult

    var body: some View {
        OnboardingChecklistRow(systemImage: check.systemImage, title: check.title, isDone: result == .passed) {
            Text(detail)
                .foregroundStyle(result.failure == nil ? Color.secondary : Color.red)
        } accessory: {
            switch result {
            case .notChecked, .checking:
                ProgressView()
                    .accessibilityLabel("lc.jitlessDiag.checking".loc)
            case .missing:
                Text("ryc0.onboarding.check.optional".loc)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            case .failed, .passed:
                EmptyView()
            }
        }
    }

    private var detail: String {
        switch result {
        case .failed(let reason):
            reason
        case .missing:
            check.missingDetail
        case .notChecked, .checking, .passed:
            check.detail
        }
    }
}

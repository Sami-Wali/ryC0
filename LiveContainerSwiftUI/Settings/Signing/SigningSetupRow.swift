//
//  SigningSetupRow.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// One part of the setup in Check Setup's list: its icon and name, with how
/// it stands on the trailing side. A line under the name says why when it
/// failed, in red, or what's lost when an optional part is missing. What the
/// part does is VoiceOver's hint.
struct SigningSetupRow: View {
    let check: SigningSetupCheck
    let result: SigningCheckResult

    var body: some View {
        // A stack rather than LabeledContent, which moves the status under
        // the name once a note makes the name's side two lines tall.
        HStack {
            Label {
                VStack(alignment: .leading, spacing: SettingsDesign.subtitleSpacing) {
                    Text(check.title)

                    if let note {
                        Text(note)
                            .font(.footnote)
                            .foregroundStyle(result.failure == nil ? Color.secondary : Color.red)
                    }
                }
            } icon: {
                SettingsIcon(systemImage: check.systemImage, color: check.color)
            }

            Spacer(minLength: 8)

            SigningCheckStatus(result: result)
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint(check.detail)
    }

    /// Why it failed, or what's lost while it's missing, or nil when there's
    /// nothing wrong.
    private var note: String? {
        result.failure ?? (result == .missing ? check.missingDetail : nil)
    }
}

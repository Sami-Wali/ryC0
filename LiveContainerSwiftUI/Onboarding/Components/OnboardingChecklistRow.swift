//
//  OnboardingChecklistRow.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// A checklist row for one thing onboarding sets up: a squircle icon that
/// becomes a check when the thing is in place, its name, a line on how it
/// stands, and until then an accessory at the trailing edge, such as a
/// spinner while it's being checked.
///
/// At the largest text sizes the accessory moves under the text, so neither
/// gets squeezed.
struct OnboardingChecklistRow<Detail: View, Accessory: View>: View {
    let systemImage: String
    /// The row's name, already localized.
    let title: String
    let isDone: Bool
    @ViewBuilder let detail: Detail
    @ViewBuilder let accessory: Accessory

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: OnboardingDesign.rowSpacing))
            : AnyLayout(HStackLayout(spacing: OnboardingDesign.rowSpacing))

        layout {
            HStack(spacing: OnboardingDesign.rowSpacing) {
                OnboardingIcon(systemImage: systemImage, isDone: isDone)

                VStack(alignment: .leading, spacing: OnboardingDesign.rowTextSpacing) {
                    Text(title)
                        .font(.headline)

                    detail
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityElement(children: .combine)
            .accessibilityValue(isDone ? Text("ryc0.onboarding.doneValue".loc) : Text(verbatim: ""))

            if !isDone {
                accessory
            }
        }
        .padding(.vertical, OnboardingDesign.rowPadding)
    }
}

extension OnboardingChecklistRow where Accessory == EmptyView {
    /// A row with nothing beside it, for a part that's done somewhere else.
    init(systemImage: String, title: String, isDone: Bool, @ViewBuilder detail: () -> Detail) {
        self.init(systemImage: systemImage, title: title, isDone: isDone, detail: detail) {
            EmptyView()
        }
    }
}

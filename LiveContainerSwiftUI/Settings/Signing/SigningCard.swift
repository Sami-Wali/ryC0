//
//  SigningCard.swift
//  LiveContainerSwiftUI
//

import SwiftUI

struct SigningCard: View {
    @Environment(SigningStatus.self) private var connection
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: SettingsDesign.headerSpacing))
            : AnyLayout(HStackLayout(spacing: SettingsDesign.cardSpacing))

        layout {
            SigningMark(size: SettingsDesign.cardMarkSize)
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)

            VStack(alignment: .leading, spacing: SettingsDesign.subtitleSpacing) {
                Text("ryc0.settings.signing".loc)
                    .font(.title2)
                    .bold()
                    .foregroundStyle(.primary)

                Text(connection.summary)
                    .font(.subheadline)
                    .foregroundStyle(connection.isExpired ? Color.red : Color.secondary)
            }
        }
        .padding(.vertical, SettingsDesign.cardPadding)
        .accessibilityElement(children: .combine)
    }
}

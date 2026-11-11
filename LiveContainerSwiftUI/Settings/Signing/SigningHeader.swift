//
//  SigningHeader.swift
//  LiveContainerSwiftUI
//

import SwiftUI

struct SigningHeader: View {
    var body: some View {
        VStack(spacing: SettingsDesign.headerSpacing) {
            SigningMark(size: SettingsDesign.headerMarkSize)
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)

            VStack(spacing: SettingsDesign.subtitleSpacing) {
                Text("ryc0.settings.signing".loc)
                    .font(.title2)
                    .bold()

                Text("ryc0.settings.signing.headerDetail".loc)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

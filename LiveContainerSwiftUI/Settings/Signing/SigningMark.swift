//
//  SigningMark.swift
//  LiveContainerSwiftUI
//

import SwiftUI

struct SigningMark: View {
    @ScaledMetric private var size: Double

    /// - Parameter size: The tile's width and height at the default text size.
    init(size: Double) {
        _size = ScaledMetric(wrappedValue: size, relativeTo: .title2)
    }

    var body: some View {
        Image(systemName: "signature")
            .resizable()
            .scaledToFit()
            .foregroundStyle(.white)
            .frame(width: size * SettingsDesign.signingGlyphRatio, height: size * SettingsDesign.signingGlyphRatio)
            .frame(width: size, height: size)
            .background(SettingsDesign.signingTile, in: .rect(cornerRadius: size * SettingsDesign.iconCornerRatio))
            .overlay {
                RoundedRectangle(cornerRadius: size * SettingsDesign.iconCornerRatio)
                    .strokeBorder(.separator, lineWidth: SettingsDesign.iconOutlineWidth)
            }
            .accessibilityHidden(true)
    }
}

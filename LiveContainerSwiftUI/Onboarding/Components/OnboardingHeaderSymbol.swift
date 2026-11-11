//
//  OnboardingHeaderSymbol.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The symbol at the top of a step: white, on a tile of ryC0's pink in
/// the shape of an app icon.
struct OnboardingHeaderSymbol: View {
    let systemImage: String

    private let size = OnboardingDesign.headerSymbolSize

    var body: some View {
        Image(systemName: systemImage)
            .resizable()
            .scaledToFit()
            .foregroundStyle(.white)
            .frame(width: size * OnboardingDesign.headerGlyphRatio, height: size * OnboardingDesign.headerGlyphRatio)
            .frame(width: size, height: size)
            .background(OnboardingDesign.accent, in: .rect(cornerRadius: size * OnboardingDesign.iconCornerRatio))
            .accessibilityHidden(true)
    }
}

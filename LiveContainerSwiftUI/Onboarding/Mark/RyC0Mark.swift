//
//  RyC0Mark.swift
//  LiveContainerSwiftUI
//

import SwiftUI

struct RyC0Mark: View {
    /// How much of the icon shows.
    var stage = RyC0MarkStage.apps
    /// The icon's width and height.
    var size = OnboardingDesign.markSize

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The icon's art is 1024 points across. Its apps start this far in along
    /// either axis, one row or column at each, and are this big and this
    /// rounded.
    private static let artSize = 1024.0
    private static let appStarts = [196.0, 363.0, 530.0, 697.0]
    private static let appSize = 131.0
    private static let appCornerRadius = 34.0

    var body: some View {
        let tile = RoundedRectangle(cornerRadius: size * OnboardingDesign.iconCornerRatio)
        let scale = size / Self.artSize

        ZStack(alignment: .topLeading) {
            tile
                .fill(
                    LinearGradient(
                        colors: [OnboardingDesign.markGradientStart, OnboardingDesign.markGradientEnd],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    tile.strokeBorder(.separator, lineWidth: OnboardingDesign.markOutlineWidth)
                }
                .scaleEffect(reduceMotion || stage >= .tile ? 1 : 0.8)
                .opacity(stage >= .tile ? 1 : 0)

            ForEach(0..<16, id: \.self) { index in
                let row = index / 4
                let column = index % 4

                RoundedRectangle(cornerRadius: Self.appCornerRadius * scale)
                    // Fading from the top left, as on the icon.
                    .fill(.white.opacity(0.95 - 0.07 * Double(row + column)))
                    .frame(width: Self.appSize * scale, height: Self.appSize * scale)
                    .scaleEffect(reduceMotion || stage >= .apps ? 1 : 0.4)
                    .opacity(stage >= .apps ? 1 : 0)
                    .animation(appArrival(diagonal: row + column), value: stage)
                    .offset(x: Self.appStarts[column] * scale, y: Self.appStarts[row] * scale)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    /// How an app on the `diagonal`th diagonal from the top left comes in:
    /// after the diagonals before it, or with Reduce Motion, fading in with
    /// the rest.
    private func appArrival(diagonal: Int) -> Animation {
        if reduceMotion {
            OnboardingDesign.markFade
        } else {
            OnboardingDesign.markAppArrival.delay(Double(diagonal) * OnboardingDesign.markAppStagger)
        }
    }
}

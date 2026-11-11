//
//  HomeProgressPie.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The progress iOS draws over an app that is downloading or installing: the
/// icon dims, and a clear ring in its middle fills with a clear wedge as the
/// work goes on, letting the icon show through.
struct HomeProgressPie: View {
    /// How far the work has come, from 0 to 1.
    let progress: Double
    /// The icon's corner radius, so the dimming follows its shape.
    let cornerRadius: Double

    var body: some View {
        Canvas { context, size in
            let bounds = CGRect(origin: .zero, size: size)
            context.fill(Path(roundedRect: bounds, cornerRadius: cornerRadius), with: .color(.black.opacity(0.55)))

            // The ring and the wedge are cut out of the dimming.
            context.blendMode = .clear
            let center = CGPoint(x: bounds.midX, y: bounds.midY)
            let ringRadius = size.width * 0.27
            let ringWidth = max(size.width * 0.035, 1.5)
            var ring = Path()
            ring.addArc(center: center, radius: ringRadius, startAngle: .zero, endAngle: .degrees(360), clockwise: false)
            context.stroke(ring, with: .color(.black), lineWidth: ringWidth)

            let wedgeRadius = ringRadius - ringWidth / 2 - size.width * 0.03
            let fraction = min(max(progress, 0), 1)
            if fraction > 0 {
                var wedge = Path()
                wedge.move(to: center)
                wedge.addArc(center: center, radius: wedgeRadius, startAngle: .degrees(-90), endAngle: .degrees(-90 + 360 * fraction), clockwise: false)
                wedge.closeSubpath()
                context.fill(wedge, with: .color(.black))
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

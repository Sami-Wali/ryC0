//
//  HomeButtonGlyph.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The rings on the Home button, drawn like AssistiveTouch's: white circles
/// stacked from a faint halo to a bright dot in the middle.
struct HomeButtonGlyph: View {
    var body: some View {
        ZStack {
            ForEach(HomeDesign.homeButtonRings, id: \.size) { ring in
                Circle()
                    .fill(.white.opacity(ring.opacity))
                    .frame(width: ring.size, height: ring.size)
            }
        }
        .accessibilityHidden(true)
    }
}

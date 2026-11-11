//
//  HomeGlass.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The glass behind the dock, the search pill and the Home Screen's buttons:
/// Liquid Glass on iOS 26 and later, and before that a dark fill with a light
/// rim, which is how the glass looks over a dark wallpaper. Glass that runs
/// to the screen's edges gets a hairline along its top instead of the rim.
struct HomeGlass: ViewModifier {
    /// The glass's outline.
    let shape: HomeGlassShape
    /// Whether the glass reacts to touches, as a button's does.
    var isInteractive = false
    var isClear = false

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *), SharedModel.isLiquidGlassEnabled {
            let glass = isClear ? Glass.clear : Glass.regular
            content.glassEffect(glass.interactive(isInteractive), in: shape.liquidGlassShape)
        } else {
            content.background {
                shape.fallbackShape
                    .fill(HomeDesign.fallbackGlassFill)
                    .stroke(shape.hasFullRim ? AnyShapeStyle(HomeDesign.fallbackGlassRim) : AnyShapeStyle(.clear), lineWidth: 1)
                    .overlay(alignment: .top) {
                        Rectangle()
                            .fill(HomeDesign.fallbackGlassHairline)
                            .frame(height: shape.hasFullRim ? 0 : 1)
                    }
            }
        }
    }
}

extension View {
    /// Puts the Home Screen's glass behind this view, in the given shape.
    func homeGlass(_ shape: HomeGlassShape, isInteractive: Bool = false, isClear: Bool = false) -> some View {
        modifier(HomeGlass(shape: shape, isInteractive: isInteractive, isClear: isClear))
    }
}

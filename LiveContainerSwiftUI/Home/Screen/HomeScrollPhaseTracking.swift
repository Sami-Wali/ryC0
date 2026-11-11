//
//  HomeScrollPhaseTracking.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// Tells the model when the pages move, so the search pill can show the page
/// dots and the pages the scroll passes keep their icons. iOS 18 and later
/// report scrolling as it starts and stops; iOS 17 only reports the page once
/// it changes.
struct HomeScrollPhaseTracking: ViewModifier {
    let model: HomeScreenModel

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content
                .onScrollPhaseChange { _, phase in
                    model.scrollPhaseChanged(isScrolling: phase.isScrolling)
                }
                .onChange(of: model.page, model.pageChanged)
        } else {
            content.onChange(of: model.page) { oldPage, newPage in
                model.pageChanged(from: oldPage, to: newPage)
                model.pageDidChange()
            }
        }
    }
}

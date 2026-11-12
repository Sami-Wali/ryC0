//
//  HomePillRow.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The row above the dock. On the first page it holds the "Search" pill, as
/// on iOS. When there is more than one page, the page dots take it while the
/// pages move and in edit mode, and a finger dragged along it scrubs through
/// the pages. The dock fills the bottom of the screen, so the Home button
/// takes this row instead whenever pressing it would do something: on the
/// other pages, and in edit mode when there is only one page.
struct HomePillRow: View {
    /// How much the Home button shrinks to fit the row, 1 where it has room.
    let homeButtonScale: Double

    @Environment(HomeScreenModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @GestureState private var isScrubbing = false

    var body: some View {
        HStack(spacing: 8) {
            Color.clear
                .frame(width: 44, height: 1)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            pill
            Button {
                model.showAppSwitcher(from: .home)
            } label: {
                Image(systemName: "rectangle.stack")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("ryc0.switcher.title".loc)
            .accessibilityIdentifier("ryc0.app-switcher")
        }
    }

    private var pill: some View {
        let content = model.pillContent

        return ZStack {
            if content == .homeButton {
                HomeButton(action: model.goHome)
                    .scaleEffect(homeButtonScale)
                    .transition(transition)
            } else {
                HomeSearchPill(
                    pageCount: model.pageCount,
                    currentPage: model.page ?? 0,
                    showsPageDots: content == .pageDots,
                    action: model.openSearch
                )
                .transition(transition)
            }
        }
        .animation(HomeDesign.modeChange, value: content)
        // Over the pill and the Home button alike. A tap still reaches the
        // button underneath; once the finger moves, the scrub takes over.
        .highPriorityGesture(scrub, including: model.pageCount > 1 ? .all : .subviews)
        .onChange(of: isScrubbing, scrubbingChanged)
        .sensoryFeedback(.selection, trigger: model.page) { _, _ in
            isScrubbing
        }
    }

    private var scrub: some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .named(HomeDesign.coordinateSpace))
            .updating($isScrubbing) { _, isScrubbing, _ in
                isScrubbing = true
            }
            .onChanged(scrubChanged)
    }

    private func scrubChanged(_ value: DragGesture.Value) {
        model.scrubPages(atX: value.location.x)
    }

    /// Lets the dots go once the finger lifts, or the scrub is cancelled.
    private func scrubbingChanged(from wasScrubbing: Bool, to isScrubbing: Bool) {
        if wasScrubbing && !isScrubbing {
            model.scrubEnded()
        }
    }

    /// The button and the pill grow out of each other, or only fade with
    /// Reduce Motion on.
    private var transition: AnyTransition {
        reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.8))
    }
}

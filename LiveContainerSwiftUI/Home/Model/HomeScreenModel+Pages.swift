//
//  HomeScreenModel+Pages.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// Moving between pages: the page dots that show while the pages move, the
/// pages whose icons are built, and scrubbing along the dots.
extension HomeScreenModel {
    // MARK: Turning pages

    /// Shows another page. The icons of every page the scroll passes on the
    /// way are built first, so none vanish while the pages fly by.
    func showPage(_ newPage: Int, animation: Animation? = HomeDesign.reflow) {
        includeInBuiltPages(page ?? 0, newPage)
        withAnimation(animation) {
            page = newPage
        }
    }

    /// Notes a new page from the paging scroll view, building the icons of
    /// the page it left and the page it reached until the pages stop.
    func pageChanged(from oldPage: Int?, to newPage: Int?) {
        includeInBuiltPages(oldPage ?? 0, newPage ?? 0)
    }

    /// Keeps the page showing within the pages there are, after pages went
    /// away: the last page shows instead of one that is gone.
    func clampPage() {
        let lastPage = max(pageCount - 1, 0)
        if let current = page, current > lastPage {
            withAnimation(HomeDesign.reflow) {
                page = lastPage
            }
        }
    }

    /// Widens the built pages to cover `pages` and their neighbors.
    private func includeInBuiltPages(_ pages: Int...) {
        let lower = min(builtPages.lowerBound, (pages.min() ?? 0) - 1)
        let upper = max(builtPages.upperBound, (pages.max() ?? 0) + 1)
        if lower != builtPages.lowerBound || upper != builtPages.upperBound {
            builtPages = lower...upper
        }
    }

    /// Lets go of the icons of the pages away from the one showing, once the
    /// pages have stopped.
    private func narrowBuiltPages() {
        let current = page ?? 0
        let narrowed = (current - 1)...(current + 1)
        if narrowed != builtPages {
            builtPages = narrowed
        }
    }

    // MARK: Page dots

    /// Shows the page dots while the pages move, and "Search" again shortly
    /// after they stop, unless a finger is still scrubbing along them. iOS 18
    /// and later report the scrolling directly.
    func scrollPhaseChanged(isScrolling: Bool) {
        guard pageCount > 1, isScrolling || !isScrubbingPages else {
            return
        }
        if isScrolling {
            pageDotsTask?.cancel()
            if !showsPageDots {
                withAnimation(HomeDesign.modeChange) {
                    showsPageDots = true
                }
            }
        } else {
            hidePageDotsSoon()
        }
    }

    /// Shows the page dots for a moment after the page changes. iOS 17 can't
    /// report scrolling, so it shows them only once a new page has settled.
    func pageDidChange() {
        scrollPhaseChanged(isScrolling: true)
        scrollPhaseChanged(isScrolling: false)
    }

    /// Hides the dots once the pages have been still for a moment, and lets
    /// go of the pages the scroll passed. Waiting covers a jump of several
    /// pages too, which iOS 17 reports as soon as it starts.
    private func hidePageDotsSoon() {
        pageDotsTask?.cancel()
        pageDotsTask = Task { [weak self] in
            try? await Task.sleep(for: HomeDesign.pageDotsLinger)
            guard !Task.isCancelled, let self else {
                return
            }
            withAnimation(HomeDesign.modeChange) {
                self.showsPageDots = false
            }
            self.narrowBuiltPages()
        }
    }

    // MARK: Scrubbing

    /// Follows a finger dragged along the row above the dock: the dots show,
    /// and the page under the finger, counting the dots from the middle of
    /// the row, comes up.
    func scrubPages(atX x: Double) {
        guard pageCount > 1, let metrics else {
            return
        }
        isScrubbingPages = true
        pageDotsTask?.cancel()
        if !showsPageDots {
            withAnimation(HomeDesign.modeChange) {
                showsPageDots = true
            }
        }
        let step = HomeDesign.pageScrubStep
        let firstDot = metrics.pillCenter.x - Double(pageCount - 1) / 2 * step
        let target = min(max(Int(((x - firstDot) / step).rounded()), 0), pageCount - 1)
        if target != (page ?? 0) {
            showPage(target)
        }
    }

    /// Ends scrubbing: the dots go away shortly, as after a swipe.
    func scrubEnded() {
        isScrubbingPages = false
        scrollPhaseChanged(isScrolling: false)
    }
}

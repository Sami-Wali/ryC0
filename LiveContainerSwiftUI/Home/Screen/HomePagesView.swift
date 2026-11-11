//
//  HomePagesView.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The pages of icons, swiped through one screen at a time. Each page is a
/// screen-wide stop for the paging scroll view; the icons of every page sit in
/// one layer over the stops, so an icon dragged onto another page stays the
/// same view and its drag goes on. Pulling down anywhere on the pages, on an
/// icon too, brings search in under the finger, as on iOS.
struct HomePagesView: View {
    /// Where things go on this screen.
    let metrics: HomeMetrics
    /// The namespace Settings and app settings zoom out of icons in.
    let zoomNamespace: Namespace.ID

    @Environment(HomeScreenModel.self) private var model
    /// How far the pull down in progress has brought search in.
    @GestureState private var pull = 0.0

    var body: some View {
        @Bindable var model = model
        let pageCount = model.pageCount

        ScrollView(.horizontal) {
            HStack(spacing: 0) {
                ForEach(0..<pageCount, id: \.self) { _ in
                    Color.clear
                        .frame(width: metrics.size.width, height: metrics.size.height)
                }
            }
            .scrollTargetLayout()
            .background {
                HomeWallpaper()
            }
            .overlay(alignment: .topLeading) {
                HomePageIcons(metrics: metrics, pageCount: pageCount, zoomNamespace: zoomNamespace)
            }
        }
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $model.page)
        .scrollDisabled(model.drag != nil)
        .modifier(HomeScrollPhaseTracking(model: model))
        // A page held for an app being installed goes again when the install
        // fails, and the last page shows instead, as when other pages go.
        .onChange(of: pageCount) {
            model.clampPage()
        }
        // On the scroll view, which holds the icons as well as the wallpaper,
        // so a pull that starts on an icon counts too. Edit mode leaves the
        // pages to dragging icons.
        .simultaneousGesture(pullDown, including: model.isEditing ? .subviews : .all)
        .onChange(of: pull, pullChanged)
        // HomeMetrics places the icons from the screen's top left corner, so
        // the pages fill the screen without the usual safe area margins.
        .ignoresSafeArea()
    }

    /// Search follows the finger down, as on iOS, and opens if the pull went
    /// far enough or was flicked. A pull that turns into a page swipe brings
    /// nothing in, and one the scroll view takes over goes back away.
    ///
    /// The finger is measured on the screen, not on the pages: the Home
    /// Screen shrinks as search comes in, and measuring on it would move the
    /// finger with it.
    private var pullDown: some Gesture {
        DragGesture(minimumDistance: 24, coordinateSpace: .global)
            .updating($pull) { value, pull, _ in
                pull = Self.progress(of: value.translation, isPulling: pull > 0)
            }
            .onEnded(pullEnded)
    }

    /// How far a pull has brought search in, all of it once it has gone down
    /// the whole way. A pull must start mostly straight down; once it has, it
    /// keeps going however much it wanders sideways.
    private static func progress(of translation: CGSize, isPulling: Bool) -> Double {
        guard translation.height > 0, isPulling || abs(translation.width) < translation.height * 0.6 else {
            return 0
        }
        return min(translation.height / HomeDesign.searchPullRange, 1)
    }

    private func pullEnded(_ value: DragGesture.Value) {
        let pulledFar = value.translation.height > HomeDesign.pullToSearchDistance
        let flicked = value.predictedEndTranslation.height > HomeDesign.searchPullRange
        model.searchPullEnded(opens: pulledFar || flicked)
    }

    private func pullChanged(from oldValue: Double, to newValue: Double) {
        if newValue == 0 {
            // The pull ended or was taken over by a page swipe.
            model.searchPullEnded(opens: false)
        } else {
            model.searchPullChanged(newValue)
        }
    }
}

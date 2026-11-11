import SwiftUI

struct HomeDock: View {
    let metrics: HomeMetrics
    let zoomNamespace: Namespace.ID

    @Environment(HomeScreenModel.self) private var model
    @Environment(\.prefersDarkAppIcons) private var darkModeIcon

    var body: some View {
        let count = model.displayedLayout.dockRange(on: model.visibleDockPage).count
        let glass = metrics.dockFrame(holding: count)
        let iconMetrics = metrics.dockIconMetrics(count: count)
        let shape: HomeGlassShape = metrics.isDockFlush ? .edgeToEdge : .screenConcentric(fallbackRadius: metrics.dockCornerRadius)

        ZStack(alignment: .topLeading) {
            Color.clear
                .frame(width: glass.width, height: glass.height)
                .homeGlass(shape, isClear: true)
                .contentShape(.rect)
                .position(x: glass.midX, y: glass.midY)
                .accessibilityHidden(true)

            ForEach(model.dockPlacements) { placement in
                HomeIconCell(
                    item: placement.item,
                    app: app(for: placement.item),
                    metrics: iconMetrics,
                    showsLabel: false,
                    isLifted: placement.isLifted,
                    isOnScreen: true,
                    darkModeIcon: darkModeIcon,
                    zoomNamespace: zoomNamespace
                )
                .position(position(of: placement.slot, count: count))
            }

            if model.dockPageCount > 1 {
                pageControl
                    .position(
                        x: metrics.isDockVertical ? glass.maxX - 12 : glass.midX,
                        y: metrics.isDockVertical ? glass.midY : glass.maxY - 10
                    )
            }
        }
        .frame(width: metrics.size.width, height: metrics.size.height, alignment: .topLeading)
        .simultaneousGesture(
            DragGesture(minimumDistance: 20, coordinateSpace: .local).onEnded { value in
                guard !model.isEditing, model.dockPageCount > 1, glass.contains(value.startLocation) else { return }
                let along = metrics.isDockVertical ? value.translation.height : value.translation.width
                let across = metrics.isDockVertical ? value.translation.width : value.translation.height
                guard abs(along) > max(32, abs(across)) else { return }
                model.showDockPage(model.visibleDockPage + (along < 0 ? 1 : -1))
            },
            including: model.isEditing ? .none : .all
        )
    }

    private var pageControl: some View {
        Button {
            model.showDockPage((model.visibleDockPage + 1) % model.dockPageCount)
        } label: {
            let stack = metrics.isDockVertical ? AnyLayout(VStackLayout(spacing: 4)) : AnyLayout(HStackLayout(spacing: 4))
            stack {
                ForEach(0..<model.dockPageCount, id: \.self) { page in
                    Circle()
                        .fill(.white.opacity(page == model.visibleDockPage ? 0.95 : 0.4))
                        .frame(width: 4, height: 4)
                }
            }
            .padding(metrics.isDockVertical ? .vertical : .horizontal, 10)
            .frame(minWidth: metrics.isDockVertical ? 24 : 44, minHeight: metrics.isDockVertical ? 44 : 20)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("ryc0.dock.pages")
        .accessibilityLabel("ryc0.dock.pages".loc)
        .accessibilityValue("\(model.visibleDockPage + 1) / \(model.dockPageCount)")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: model.showDockPage(model.visibleDockPage + 1)
            case .decrement: model.showDockPage(model.visibleDockPage - 1)
            @unknown default: break
            }
        }
    }

    private func app(for item: HomeItem) -> LCAppModel? {
        guard case .app(let key) = item else { return nil }
        return model.apps[key]
    }

    private func position(of slot: HomeSlot, count: Int) -> CGPoint {
        guard case .dock(let index) = slot else {
            return CGPoint(x: metrics.dockFrame.midX, y: metrics.dockFrame.midY)
        }
        return metrics.dockIconCenter(at: index % HomeLayout.dockIconsPerPage, count: count)
    }
}

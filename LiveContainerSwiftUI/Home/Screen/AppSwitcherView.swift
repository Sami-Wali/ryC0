import SwiftUI
import UIKit

enum RYSwitcherEntry {
    case home
    case app

}

struct AppSwitcherView: View {
    let zoomNamespace: Namespace.ID
    let open: (LCAppModel, String?, CGRect) -> Void
    let didFinishOpening: () -> Void
    let goHome: () -> Void

    @Environment(HomeScreenModel.self) private var home
    @ObservedObject private var windows = MultitaskManager.shared
    @ObservedObject private var hosted = FullScreenGuestSession.shared
    @State private var dismissed = UserDefaults.standard.dictionary(forKey: "ryc0.switcher.dismissed") as? [String: Date] ?? [:]
    @State private var closing: Set<String> = []
    @State private var previews: [String: UIImage] = [:]

    var body: some View {
        let cards = sessions
        NativeDeck(items: cards.map(nativeItem), entry: home.switcherEntry == .app ? cards.first?.id : nil,
                   open: { id, frame in
                       guard let session = cards.first(where: { $0.id == id }) else { return }
                       open(session.app, session.container, frame)
                   }, close: { id in
                       if let session = cards.first(where: { $0.id == id }) { closeSession(session) }
                   }, didFinishOpening: didFinishOpening, goHome: goHome)
            .ignoresSafeArea()
            .accessibilityAction(.escape, goHome)
            .task(id: cards.map(\.id)) {
                for session in cards {
                    guard !Task.isCancelled else { return }
                    let app = session.app
                    await app.drawHomeScreenIcon(isDark: true)
                    if !app.appInfo.isLocked && !app.appInfo.isHidden,
                       let bundle = app.appInfo.relativeBundlePath,
                       let image = await MainWindow.loadSwitcherPreview(for: bundle) {
                        previews[session.id] = image
                    }
                }
            }
    }

    private func nativeItem(_ session: SwitcherSession) -> RYNativeSwitcherItem {
        let item = RYNativeSwitcherItem()
        item.identifier = session.id
        item.bundleIdentifier = session.app.appInfo.bundleIdentifier() ?? session.key
        item.name = session.name
        item.icon = session.app.homeScreenIcon(isDark: true) ?? UIImage(systemName: "app.fill")
        let locked = session.app.appInfo.isLocked || session.app.appInfo.isHidden
        item.snapshot = locked ? placeholder(for: item, locked: true)
            : session.container.flatMap { hosted.previews[$0] ?? MainWindow.switcherPreviews[$0] }
                ?? previews[session.id] ?? placeholder(for: item, locked: false)
        return item
    }

    private func placeholder(for item: RYNativeSwitcherItem, locked: Bool) -> UIImage {
        let size = CGSize(width: 240, height: 522)
        return UIGraphicsImageRenderer(size: size).image { context in
            UIColor(white: 0.07, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            let image = locked ? UIImage(systemName: "lock.fill")?.withTintColor(.white, renderingMode: .alwaysOriginal) : item.icon
            image?.draw(in: CGRect(x: 96, y: 237, width: 48, height: 48))
        }
    }

    private var sessions: [SwitcherSession] {
        home.apps.flatMap { key, app -> [SwitcherSession] in
            guard !app.appInfo.isHidden else { return [] }
            let date = app.appInfo.lastLaunched ?? .distantPast
            let live = app.uiContainers.compactMap { entry -> SwitcherSession? in
                let folder = entry.folderName
                guard !closing.contains(folder),
                      hosted.container == folder || windows.windows[folder]?.controller != nil else { return nil }
                return SwitcherSession(key: key, app: app, container: folder, date: date)
            }
            if !live.isEmpty { return live }
            guard date != .distantPast, dismissed[key] != date else { return [] }
            return [SwitcherSession(key: key, app: app, container: nil, date: date)]
        }
        .sorted {
            let active = hosted.container
            if let active, ($0.container == active) != ($1.container == active) { return $0.container == active }
            return $0.date == $1.date ? $0.id < $1.id : $0.date > $1.date
        }
    }

    private func closeSession(_ session: SwitcherSession) {
        dismissed[session.key] = session.date
        if let container = session.container { closing.insert(container) }

        // The deck has finished the upward swipe before touching the guest
        // process. Preview writes and deletes share a separate serial queue.
        DispatchQueue.main.async {
            UserDefaults.standard.set(dismissed, forKey: "ryc0.switcher.dismissed")
            if let container = session.container {
                MainWindow.removeSwitcherPreview(for: container)
                if hosted.container == container { hosted.close(container: container) }
                else { windows.close(container: container) }
            }
            if let bundle = session.app.appInfo.relativeBundlePath {
                MainWindow.saveSwitcherPreview(nil, for: bundle)
            }
        }
    }
}

private struct SwitcherSession: Identifiable {
    let key: String
    let app: LCAppModel
    let container: String?
    let date: Date

    var id: String { container ?? key }
    var name: String { app.displayName }
}

private struct NativeDeck: UIViewControllerRepresentable {
    let items: [RYNativeSwitcherItem]
    let entry: String?
    let open: (String, CGRect) -> Void
    let close: (String) -> Void
    let didFinishOpening: () -> Void
    let goHome: () -> Void

    func makeUIViewController(context: Context) -> RYNativeAppSwitcher {
        let controller = RYNativeAppSwitcher()
        controller.items = items
        controller.entryIdentifier = entry
        controller.openHandler = open
        controller.didFinishOpeningHandler = didFinishOpening
        controller.closeHandler = close
        controller.homeHandler = goHome
        return controller
    }

    func updateUIViewController(_ controller: RYNativeAppSwitcher, context: Context) {
        controller.items = items
        controller.openHandler = open
        controller.didFinishOpeningHandler = didFinishOpening
        controller.closeHandler = close
        controller.homeHandler = goHome
        controller.refreshItems()
    }

    static func dismantleUIViewController(_ controller: RYNativeAppSwitcher, coordinator: ()) {
        controller.invalidate()
    }
}

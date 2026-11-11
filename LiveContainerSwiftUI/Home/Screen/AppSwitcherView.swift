import SwiftUI
import UIKit

enum RYSwitcherLayout {
    static let headerHeight: CGFloat = 28
    static let headerGap: CGFloat = 8

    static func cardFrame(in bounds: CGRect) -> CGRect {
        let size = CGSize(width: bounds.width * 0.685, height: bounds.height * 0.685)
        return CGRect(x: bounds.midX - size.width / 2,
                      y: bounds.minY + bounds.height * 0.49 - size.height / 2,
                      width: size.width, height: size.height)
    }

    static func cornerRadius(for frame: CGRect) -> CGFloat {
        min(frame.width, frame.height) * 0.16
    }

    static func stride(in bounds: CGRect) -> CGFloat { max(1, bounds.width * 0.53) }

    static func cardFrame(at index: Int, position: CGFloat, in bounds: CGRect) -> CGRect {
        let distance = CGFloat(index) - position
        // The first app rests in the center. The stack opens up as older apps
        // come forward, leaving part of the more recent app on the right.
        let spread = min(max(position, 0), 1)
        let offset = bounds.width * (bounds.width > bounds.height ? 0.03 : 0.075) * spread
        let frame = cardFrame(in: bounds).offsetBy(dx: offset, dy: 0)
        guard distance > 0 else { return frame.offsetBy(dx: -distance * stride(in: bounds), dy: 0) }

        let depth = min(distance, 4)
        let peek = 0.135 + spread * 0.045
        let inset = (min(distance, 1) * peek + max(0, distance - 1) * 0.048) * bounds.width
        return frame.insetBy(dx: frame.width * depth * 0.004, dy: frame.height * depth * 0.008)
            .offsetBy(dx: -inset, dy: 0)
    }
}

struct AppSwitcherView: View {
    let zoomNamespace: Namespace.ID
    let open: (LCAppModel, String?, CGRect) -> Void
    let goHome: () -> Void

    @Environment(HomeScreenModel.self) private var home
    @ObservedObject private var windows = MultitaskManager.shared
    @ObservedObject private var hosted = FullScreenGuestSession.shared
    @State private var dismissed = UserDefaults.standard.dictionary(forKey: "ryc0.switcher.dismissed") as? [String: Date] ?? [:]
    @State private var closing: Set<String> = []
    @Environment(\.locale) private var locale

    var body: some View {
        let cards = sessions
        GeometryReader { geometry in
            ZStack {
                Rectangle()
                    .fill(.regularMaterial)
                    .environment(\.colorScheme, .dark)
                    .overlay(Color.black.opacity(0.14))
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)

                Button(action: goHome) {
                    Color.clear.contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHidden(true)

                if cards.isEmpty {
                    Text(isArabic ? "لا توجد تطبيقات مفتوحة" : "No open apps")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                        .allowsHitTesting(false)
                } else {
                    RYSwitcherDeck(sessions: cards, size: geometry.size, zoomNamespace: zoomNamespace,
                                   goHome: goHome, open: open, close: closeSession)
                }

                VStack {
                    Spacer()
                    Button(action: goHome) {
                        Color.clear
                            .frame(width: 180, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .simultaneousGesture(DragGesture(minimumDistance: 12).onEnded { value in
                        if -value.translation.height > max(30, abs(value.translation.width)) { goHome() }
                    })
                    .accessibilityLabel(isArabic ? "الشاشة الرئيسية" : "Home")
                    .accessibilityIdentifier("ryc0.switcher.home")
                }
            }
        }
        .ignoresSafeArea()
        .tint(.white)
        .accessibilityAction(.escape, goHome)
    }

    private var isArabic: Bool { locale.language.languageCode?.identifier == "ar" }

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

private struct RYSwitcherDeck: View {
    let sessions: [SwitcherSession]
    let size: CGSize
    let zoomNamespace: Namespace.ID
    let goHome: () -> Void
    let open: (LCAppModel, String?, CGRect) -> Void
    let close: (SwitcherSession) -> Void

    private enum Drag {
        case browse(CGFloat)
        case lift(String, CGFloat)
        case home
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var page = 0
    @State private var focusedID: String?
    @State private var drag: Drag?
    @GestureState private var tracking = false
    @State private var flyingCard: String?

    private var bounds: CGRect { CGRect(origin: .zero, size: size) }
    private var currentPage: Int {
        focusedID.flatMap { id in sessions.firstIndex { $0.id == id } }
            ?? min(page, max(0, sessions.count - 1))
    }
    private var spring: Animation? { reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.9) }
    private var position: CGFloat {
        guard case .browse(let translation) = drag else { return CGFloat(currentPage) }
        let proposed = CGFloat(currentPage) + translation / RYSwitcherLayout.stride(in: bounds)
        let clamped = min(max(proposed, 0), CGFloat(sessions.count - 1))
        return clamped + (proposed - clamped) * 0.20
    }

    var body: some View {
        let position = position
        let first = max(0, min(Int(floor(position)), currentPage) - 2)
        let last = min(sessions.count, max(Int(ceil(position)), currentPage) + 5)
        ZStack(alignment: .topLeading) {
            ForEach(sessions[first..<last]) { session in
                let index = sessions.firstIndex { $0.id == session.id } ?? 0
                let distance = CGFloat(index) - position
                let frame = RYSwitcherLayout.cardFrame(at: index, position: position, in: bounds)
                let header = RYSwitcherLayout.headerHeight + RYSwitcherLayout.headerGap
                RYSwitcherCard(session: session, size: frame.size, depth: distance, zoomNamespace: zoomNamespace) {
                    guard flyingCard == nil else { return }
                    open(session.app, session.container, frame)
                } close: {
                    flyAway(session)
                }
                .offset(x: frame.minX, y: frame.minY - header + lift(of: session.id))
                .opacity(reduceMotion && flyingCard == session.id ? 0 : 1)
                .zIndex(-Double(index))
                .transition(.identity)
            }
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .contentShape(Rectangle())
        .gesture(pan.exclusively(before: tap))
        .environment(\.layoutDirection, .leftToRight)
        .accessibilityScrollAction { edge in
            switch edge {
            case .trailing: settle(on: currentPage + 1)
            case .leading: settle(on: currentPage - 1)
            default: break
            }
        }
        .onChange(of: sessions.map(\.id)) {
            // Keep the same card in focus when a neighboring window closes.
            page = currentPage
            focusedID = sessions.indices.contains(page) ? sessions[page].id : nil
        }
        .onChange(of: tracking) { _, active in
            if !active {
                // A cancelled gesture has no onEnded callback.
                Task { @MainActor in
                    await Task.yield()
                    if !tracking { withAnimation(spring) { drag = nil } }
                }
            }
        }
    }

    private func lift(of id: String) -> CGFloat {
        if flyingCard == id { return reduceMotion ? 0 : -size.height }
        if case .lift(let lifted, let offset) = drag, lifted == id { return reduceMotion ? 0 : min(0, offset) }
        return 0
    }

    private func settle(on index: Int) {
        withAnimation(spring) {
            page = min(max(index, 0), max(0, sessions.count - 1))
            focusedID = sessions.indices.contains(page) ? sessions[page].id : nil
            drag = nil
        }
    }

    private var pan: some Gesture {
        DragGesture(minimumDistance: 9)
            .updating($tracking) { _, active, _ in active = true }
            .onChanged { value in
                guard flyingCard == nil else { return }
                let delta = value.translation
                switch drag {
                case .browse: drag = .browse(delta.width)
                case .lift(let id, _): drag = .lift(id, delta.height)
                case .home: break
                case nil:
                    if abs(delta.width) >= abs(delta.height) {
                        drag = .browse(delta.width)
                    } else if value.startLocation.y > size.height - 45 {
                        drag = .home
                    } else if let (session, _) = card(at: value.startLocation) {
                        drag = .lift(session.id, delta.height)
                    }
                }
            }
            .onEnded { value in
                switch drag {
                case .browse:
                    let stride = RYSwitcherLayout.stride(in: bounds)
                    let predicted = value.predictedEndTranslation.width / stride
                    let distance = value.translation.width / stride
                    let projected = min(max(predicted, distance - 1), distance + 1)
                    settle(on: currentPage + Int(projected.rounded()))
                case .lift(let id, _):
                    let upward = value.translation.height < -28
                    let distance = value.translation.height < -size.height * 0.10
                    let fling = value.predictedEndTranslation.height < -size.height * 0.22
                    let reversing = value.predictedEndTranslation.height > value.translation.height + 50
                    if upward, distance || fling, !reversing, let session = sessions.first(where: { $0.id == id }) {
                        flyAway(session, upwardVelocity: max(0, -value.velocity.height))
                    } else {
                        settle(on: currentPage)
                    }
                case .home:
                    drag = nil
                    if value.translation.height < -30 { goHome() }
                case nil:
                    break
                }
            }
    }

    private var tap: some Gesture {
        SpatialTapGesture().onEnded { value in
            guard flyingCard == nil else { return }
            if let (session, frame) = card(at: value.location) {
                open(session.app, session.container, frame)
            } else {
                goHome()
            }
        }
    }

    private func card(at point: CGPoint) -> (SwitcherSession, CGRect)? {
        for index in max(0, currentPage - 2)..<min(sessions.count, currentPage + 5) {
            let frame = RYSwitcherLayout.cardFrame(at: index, position: CGFloat(currentPage), in: bounds)
            if frame.inset(by: UIEdgeInsets(top: -RYSwitcherLayout.headerHeight - RYSwitcherLayout.headerGap,
                                             left: 0, bottom: 0, right: 0)).contains(point) {
                return (sessions[index], frame)
            }
        }
        return nil
    }

    private func flyAway(_ session: SwitcherSession, upwardVelocity: CGFloat = 0) {
        guard flyingCard == nil else { return }
        let remaining = max(0, size.height + lift(of: session.id))
        let duration = max(0.14, min(0.24, remaining / max(upwardVelocity, 1)))
        withAnimation(.easeOut(duration: reduceMotion ? 0.10 : duration)) {
            flyingCard = session.id
            drag = nil
        } completion: {
            withAnimation(spring) {
                close(session)
                flyingCard = nil
            }
        }
    }
}

private struct RYSwitcherCard: View {
    let session: SwitcherSession
    let size: CGSize
    let depth: CGFloat
    let zoomNamespace: Namespace.ID
    let open: () -> Void
    let close: () -> Void

    @Environment(\.locale) private var locale
    @ObservedObject private var hosted = FullScreenGuestSession.shared
    @ObservedObject var app: LCAppModel
    @State private var snapshot: UIImage?

    init(session: SwitcherSession, size: CGSize, depth: CGFloat, zoomNamespace: Namespace.ID,
         open: @escaping () -> Void, close: @escaping () -> Void) {
        self.session = session
        self.size = size
        self.depth = depth
        self.zoomNamespace = zoomNamespace
        self.open = open
        self.close = close
        self.app = session.app
    }

    var body: some View {
        let locked = app.appInfo.isLocked || app.appInfo.isHidden
        let image = session.container.flatMap { hosted.previews[$0] ?? MainWindow.switcherPreviews[$0] } ?? snapshot
        let closeLabel = locale.language.languageCode?.identifier == "ar" ? "إغلاق \(session.name)" : "Close \(session.name)"
        VStack(alignment: .leading, spacing: RYSwitcherLayout.headerGap) {
            HStack(spacing: 8) {
                icon(size: RYSwitcherLayout.headerHeight)
                    .opacity(1 - min(0.42, max(0, depth) * 0.30))
                Text(session.name)
                    .font(.system(size: 18, weight: .semibold))
                    .lineLimit(1)
                    .foregroundStyle(.white)
                    .opacity(max(0, 1 - abs(depth)))
            }
            .padding(.horizontal, size.width * 0.08)

            ZStack {
                Color(uiColor: .secondarySystemBackground)
                if locked {
                    Image(systemName: "lock.fill").foregroundStyle(.secondary)
                } else if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    icon(size: 60)
                }
            }
            .frame(width: size.width, height: size.height)
            .overlay(.black.opacity(min(0.28, max(0, depth) * 0.24)))
            .clipShape(.rect(cornerRadius: RYSwitcherLayout.cornerRadius(for: CGRect(origin: .zero, size: size))))
            .modifier(HomeZoomSource(id: HomeItem.app(session.key).id,
                                     namespace: session.container == hosted.container ? zoomNamespace : nil))
        }
        .frame(width: size.width, alignment: .leading)
        .contentShape(Rectangle())
        .contextMenu {
            Button(action: open) { Label(session.name, systemImage: "arrow.up.forward.app") }
            Button(role: .destructive, action: close) { Label(closeLabel, systemImage: "xmark") }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(session.name)
        .accessibilityAction(.default, open)
        .accessibilityAction(named: Text(closeLabel), close)
        .accessibilityIdentifier("ryc0.switcher.card")
        .task(id: locked) {
            guard !locked, let bundle = app.appInfo.relativeBundlePath else {
                snapshot = nil
                return
            }
            let image = await MainWindow.loadSwitcherPreview(for: bundle)
            if !Task.isCancelled { snapshot = image }
        }
        .environment(\.layoutDirection, .leftToRight)
    }

    private func icon(size: CGFloat) -> some View {
        HomeAppIconImage(app: app, isDark: false)
            .frame(width: size, height: size)
            .clipShape(.rect(cornerRadius: size * 0.23))
    }
}

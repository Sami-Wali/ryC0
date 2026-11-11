import SwiftUI
import UserNotifications

struct HomeNotificationCenter: View {
    let close: () -> Void

    @Environment(HomeScreenModel.self) private var model
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @State private var notifications: [Notification] = []
    @State private var authorizationStatus: UNAuthorizationStatus?
    @State private var isRequestingAuthorization = false
    @State private var authorizationError: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                VStack(spacing: 0) {
                    Text(Date.now, format: .dateTime.weekday(.wide).month().day())
                        .font(.headline)
                    Text(Date.now, style: .time)
                        .font(.system(size: 72, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                }
                .accessibilityHidden(true)
                .padding(.top, 8)

                HStack {
                    Text("ryc0.notifications.title".loc)
                        .font(.title2.bold())
                    Spacer()
                    if !notifications.isEmpty {
                        Button("ryc0.notifications.clear".loc) {
                            LCSharedUtils.clearDeliveredGuestNotifications()
                            refresh()
                        }
                        .buttonStyle(.bordered)
                    }
                    Button(action: close) {
                        Image(systemName: "xmark")
                            .font(.body.weight(.semibold))
                            .frame(width: 42, height: 42)
                    }
                    .buttonStyle(.plain)
                    .homeGlass(.circle, isInteractive: true)
                    .accessibilityLabel("lc.common.close".loc)
                    .accessibilityIdentifier("ryc0.notifications.close")
                }

                if authorizationStatus == .notDetermined || authorizationStatus == .denied {
                    Button(authorizationStatus == .denied
                           ? "ryc0.notifications.openSettings".loc
                           : "ryc0.notifications.requestPermission".loc) {
                        if authorizationStatus == .denied {
                            if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                                openURL(url)
                            }
                        } else {
                            isRequestingAuthorization = true
                            Task { await requestAuthorization() }
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(isRequestingAuthorization)
                    .accessibilityIdentifier("ryc0.notifications.permission")
                }

                if notifications.isEmpty {
                    ContentUnavailableView {
                        Label("ryc0.notifications.empty".loc, systemImage: "bell")
                    } description: {
                        Text("ryc0.notifications.help".loc)
                    }
                }

                ForEach(notifications) { notification in
                    if let app = notification.app(in: model) {
                        Button {
                            close()
                            model.launch(app)
                        } label: {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "app.fill")
                                    .font(.title2)
                                    .frame(width: 32, height: 32)
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack {
                                        Text(app.displayName).font(.subheadline.weight(.semibold))
                                        Spacer(minLength: 8)
                                        Text(notification.date, style: .relative)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    if !notification.title.isEmpty {
                                        Text(notification.title).font(.headline)
                                    }
                                    if !notification.subtitle.isEmpty {
                                        Text(notification.subtitle).font(.subheadline.weight(.semibold))
                                    }
                                    Text(notification.body).font(.subheadline)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        .homeGlass(.rounded(24), isInteractive: true)
                    }
                }
            }
            .frame(maxWidth: 540)
            .padding(.horizontal, 18)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(.black.opacity(0.28))
                .ignoresSafeArea()
        }
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape, close)
        .alert("lc.common.error".loc, isPresented: Binding<Bool>.isPresented(for: $authorizationError),
               presenting: authorizationError) { _ in
            Button("lc.common.ok".loc) { }
        } message: { error in
            Text(error)
        }
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            if !Task.isCancelled { authorizationStatus = settings.authorizationStatus }
        }
        .task {
            while !Task.isCancelled {
                refresh()
                try? await Task.sleep(for: .seconds(2))
            }
        }
        .simultaneousGesture(DragGesture(minimumDistance: 28).onEnded { value in
            if value.startLocation.y < 150, -value.translation.height > max(64, abs(value.translation.width)) {
                close()
            }
        })
    }

    private func requestAuthorization() async {
        defer { isRequestingAuthorization = false }
        let center = UNUserNotificationCenter.current()
        do {
            _ = try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            authorizationError = error.localizedDescription
        }
        authorizationStatus = await center.notificationSettings().authorizationStatus
    }

    private func refresh() {
        notifications = LCSharedUtils.deliveredGuestNotifications()
            .compactMap(Notification.init)
            .filter { $0.app(in: model) != nil }
            .sorted { $0.date > $1.date }
    }

    private struct Notification: Identifiable {
        let id: String
        let bundle: String
        let date: Date
        let title: String
        let subtitle: String
        let body: String
        let isRyP0Test: Bool

        init?(_ record: [String: Any]) {
            guard let id = record["id"] as? String, let bundle = record["app"] as? String,
                  let date = record["date"] as? Date else { return nil }
            self.id = id
            self.bundle = bundle
            self.date = date
            title = record["title"] as? String ?? ""
            subtitle = record["subtitle"] as? String ?? ""
            body = record["body"] as? String ?? ""
            isRyP0Test = (record["container"] as? String) == BundledStore.notificationTestContainer &&
                (record["request"] as? String) == BundledStore.notificationTestIdentifier(for: bundle)
        }

        @MainActor
        func app(in model: HomeScreenModel) -> LCAppModel? {
            model.apps.values.first {
                $0.appInfo.relativeBundlePath == bundle && !$0.appInfo.isHidden && !$0.appInfo.isLocked &&
                ($0.uiFixLocalNotification || (isRyP0Test && $0.appInfo.bundleIdentifier() == BundledStore.bundleIdentifier))
            }
        }
    }
}

struct HomeNotificationPull: View {
    let height: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "bell.fill")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.9))
                .shadow(color: .black.opacity(0.7), radius: 2)
                .padding(.leading, 24)
                .padding(.bottom, 2)
                .frame(width: 112, height: height, alignment: .bottomLeading)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("ryc0.notifications.title".loc)
        .accessibilityIdentifier("ryc0.notifications.open")
        .simultaneousGesture(DragGesture(minimumDistance: 14).onEnded { value in
            if value.translation.height > max(40, abs(value.translation.width)) { action() }
        })
    }
}

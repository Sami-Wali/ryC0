import ActivityKit
import UIKit
import notify

@MainActor
final class GuestActivityMonitor {
    static let shared = GuestActivityMonitor()

    private var token: Int32 = -1
    private var requested: Set<String> = []
    private var syncTask: Task<Void, Never>?
    private var expiryTask: Task<Void, Never>?
    private var needsSync = false

    func start() {
        if token < 0 {
            notify_register_dispatch("com.ry0.ryC0.guestActivities", &token, .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.refresh() }
            }
        }
        refresh()
    }

    func refresh() {
        needsSync = true
        guard syncTask == nil else { return }
        syncTask = Task {
            while needsSync {
                needsSync = false
                await updateActivities()
            }
            syncTask = nil
        }
    }

    private func updateActivities() async {
        let installed = DataManager.shared.model.apps.filter { !$0.appInfo.isLocked && !$0.appInfo.isHidden }
        let records = LCSharedUtils.guestActivities()
            .compactMap { record -> (GuestActivityAttributes, ActivityContent<GuestActivityAttributes.ContentState>)? in
                guard let id = record["id"] as? String, let bundle = record["app"] as? String,
                      let date = record["date"] as? Date, date.timeIntervalSinceNow > -120,
                      let title = record["title"] as? String,
                      let app = installed.first(where: { $0.appInfo.relativeBundlePath == bundle }) else { return nil }
                let attributes = GuestActivityAttributes(id: "\(bundle):\(id)", appName: String(app.displayName.prefix(80)),
                    bundlePath: bundle, hostScheme: LCSharedUtils.hostAppUrlScheme())
                let state = GuestActivityAttributes.ContentState(title: title, detail: record["detail"] as? String ?? "",
                    progress: record["progress"] as? Double)
                return (attributes, ActivityContent(state: state, staleDate: date.addingTimeInterval(120)))
            }
        expiryTask?.cancel()
        if let expiry = records.compactMap({ $0.1.staleDate }).min() {
            expiryTask = Task {
                try? await Task.sleep(for: .seconds(max(0, expiry.timeIntervalSinceNow)))
                if !Task.isCancelled { refresh() }
            }
        }
        let active = Activity<GuestActivityAttributes>.activities
        let current = Set(records.map { $0.0.id })
        // Retain dismissal history while the guest still publishes this ID.
        requested.formIntersection(current)
        for activity in active {
            guard let record = records.first(where: { $0.0.id == activity.attributes.id }) else {
                await activity.end(nil, dismissalPolicy: .immediate)
                continue
            }
            requested.insert(record.0.id)
            if activity.content.state != record.1.state || activity.content.staleDate != record.1.staleDate {
                await activity.update(record.1)
            }
        }
        guard let widgetURL = Bundle.main.builtInPlugInsURL?.appending(path: "ActivityWidget.appex"),
              let widget = Bundle(url: widgetURL),
              (widget.infoDictionary?["NSExtension"] as? [String: Any])?["NSExtensionPointIdentifier"] as? String
                == "com.apple.widgetkit-extension",
              ActivityAuthorizationInfo().areActivitiesEnabled, UIApplication.shared.applicationState == .active else { return }
        var slots = max(0, 4 - active.count(where: { current.contains($0.attributes.id) }))
        for (attributes, content) in records.reversed() where slots > 0 && !requested.contains(attributes.id) {
            if (try? Activity.request(attributes: attributes, content: content, pushType: nil)) != nil {
                requested.insert(attributes.id)
                slots -= 1
            }
        }
    }
}

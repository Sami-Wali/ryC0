import CryptoKit
import UserNotifications
import notify

/// Schedules opted-in local alerts under ryC0's notification permission.
@MainActor
final class GuestNotificationMonitor {
    static let shared = GuestNotificationMonitor()

    private static let prefix = "ryc0.guest.notification."
    private static let scheduledKey = "RYC0ScheduledGuestNotificationRevisions"
    private var token: Int32 = -1
    private var task: Task<Void, Never>?
    private var needsRefresh = false

    func start() {
        if token < 0 {
            notify_register_dispatch("com.ry0.ryC0.guestNotifications", &token, .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.refresh() }
            }
        }
        refresh()
    }

    func refresh() {
        needsRefresh = true
        guard task == nil else { return }
        task = Task {
            while needsRefresh {
                needsRefresh = false
                await synchronize()
            }
            task = nil
        }
    }

    private func synchronize() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        let pending = await center.pendingNotificationRequests()
        let delivered = await center.deliveredNotifications()
        let records = LCSharedUtils.guestNotificationsForSystemDelivery().compactMap(Record.init)
        let apps = DataManager.shared.model.apps
        let desired = records.reduce(into: [String: Record]()) { result, record in
            if record.app(in: apps) != nil { result[record.identifier] = record }
        }
        let pendingToRemove = pending.filter { shouldRemove($0, from: desired) }.map(\.identifier)
        let deliveredToRemove = delivered.map(\.request).filter { shouldRemove($0, from: desired) }.map(\.identifier)
        if !pendingToRemove.isEmpty { center.removePendingNotificationRequests(withIdentifiers: pendingToRemove) }
        if !deliveredToRemove.isEmpty { center.removeDeliveredNotifications(withIdentifiers: deliveredToRemove) }

        let revisions = Set(records.map(\.revision))
        let defaults = UserDefaults.standard
        var scheduled = Set(defaults.stringArray(forKey: Self.scheduledKey) ?? []).intersection(revisions)
        for request in pending + delivered.map(\.request) where request.identifier.hasPrefix(Self.prefix) {
            if let revision = request.content.userInfo["ryc0Revision"] as? String, revisions.contains(revision) {
                scheduled.insert(revision)
            }
        }
        defaults.set(Array(scheduled), forKey: Self.scheduledKey)

        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional ||
            settings.authorizationStatus == .ephemeral else { return }
        var availableSlots = max(0, 32 - pending.count + pendingToRemove.count)
        for record in desired.values.sorted(by: { $0.date < $1.date }) {
            guard availableSlots > 0, !needsRefresh else { break }
            let delay = record.date.timeIntervalSinceNow
            guard delay >= -60, !scheduled.contains(record.revision),
                  let app = record.app(in: DataManager.shared.model.apps) else { continue }

            let content = UNMutableNotificationContent()
            content.title = String(app.displayName.prefix(120))
            content.subtitle = record.title
            content.body = record.body
            if record.playsSound { content.sound = .default }
            content.userInfo = ["ryc0Revision": record.revision]
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, delay), repeats: false)
            let request = UNNotificationRequest(identifier: record.identifier, content: content, trigger: trigger)
            do {
                try await center.add(request)
                scheduled.insert(record.revision)
                defaults.set(Array(scheduled), forKey: Self.scheduledKey)
                availableSlots -= 1
            } catch {
                // Keep the record so the next activation can retry a future alert.
                continue
            }
        }
    }

    private func shouldRemove(_ request: UNNotificationRequest, from desired: [String: Record]) -> Bool {
        guard request.identifier.hasPrefix(Self.prefix) else { return false }
        guard let record = desired[request.identifier] else { return true }
        return request.content.userInfo["ryc0Revision"] as? String != record.revision
    }

    private struct Record {
        let identifier: String
        let revision: String
        let bundle: String
        let container: String
        let requestedAt: Date
        let date: Date
        let title: String
        let body: String
        let playsSound: Bool

        init?(_ record: [String: Any]) {
            guard let revision = record["id"] as? String, UUID(uuidString: revision) != nil,
                  let request = record["request"] as? String, request.count <= 512,
                  let bundle = record["app"] as? String, !bundle.isEmpty, bundle.utf8.count <= 255,
                  let container = record["container"] as? String, !container.isEmpty, container.utf8.count <= 255,
                  let requestedAt = record["systemDeliveryRequestedAt"] as? Date,
                  let date = record["date"] as? Date, date.timeIntervalSinceReferenceDate.isFinite else { return nil }
            let identity = Data("\(bundle)\0\(container)\0\(request)".utf8)
            identifier = GuestNotificationMonitor.prefix + SHA256.hash(data: identity).map { String(format: "%02x", $0) }.joined()
            self.revision = revision
            self.bundle = bundle
            self.container = container
            self.requestedAt = requestedAt
            self.date = date
            title = String((record["title"] as? String ?? "").prefix(256))
            let lines = [record["subtitle"], record["body"]].compactMap { $0 as? String }.filter { !$0.isEmpty }
            body = String(lines.joined(separator: "\n").prefix(2048))
            playsSound = record["sound"] as? Bool == true
        }

        @MainActor
        func app(in apps: [LCAppModel]) -> LCAppModel? {
            apps.first { app in
                guard app.appInfo.relativeBundlePath == bundle, !app.appInfo.isHidden, !app.appInfo.isLocked,
                      app.uiFixLocalNotification, let enabledAt = app.uiSystemNotificationsEnabledAt,
                      enabledAt <= requestedAt else { return false }
                return app.uiDefaultDataFolder == container || app.uiContainers.contains { $0.folderName == container }
            }
        }
    }
}

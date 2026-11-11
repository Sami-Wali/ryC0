import ActivityKit

struct GuestActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        let title: String
        let detail: String
        let progress: Double?
    }

    let id: String
    let appName: String
    let bundlePath: String
    let hostScheme: String
}

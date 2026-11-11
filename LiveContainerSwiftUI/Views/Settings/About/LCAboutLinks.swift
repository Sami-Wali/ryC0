import Foundation

enum LCAboutLinks {
    /// Set RYC0_SOURCE_URL when publishing the fork.
    static var source: URL? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "RYC0SourceURL") as? String,
              let url = URL(string: value), url.scheme == "https", url.host != nil else { return nil }
        return url
    }
    static let upstream = URL(string: "https://github.com/getzeusapp/LiveContainer/tree/zcontainer")!
    static let liveContainer = URL(string: "https://github.com/LiveContainer/LiveContainer")!
    static let liveContainerContributors = URL(string: "https://github.com/LiveContainer/LiveContainer/graphs/contributors")!
    static let khanhduytran0 = URL(string: "https://github.com/khanhduytran0")!
    static let hugeBlack = URL(string: "https://github.com/hugeBlack")!
    static let license = URL(string: "https://www.gnu.org/licenses/agpl-3.0.html")!

    static func display(_ url: URL) -> String {
        (url.host ?? "") + url.path
    }
}

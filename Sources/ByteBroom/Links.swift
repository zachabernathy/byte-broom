import AppKit

enum Links {
    static let repo = URL(string: "https://github.com/zachabernathy/byte-broom")!
    static let newIssue = URL(string: "https://github.com/zachabernathy/byte-broom/issues/new/choose")!
    static let privacy = URL(string: "https://github.com/zachabernathy/byte-broom#privacy")!
    static let support = URL(string: "https://buymeacoffee.com/thezman")!
    static let latestReleaseAPI = URL(string: "https://api.github.com/repos/zachabernathy/byte-broom/releases/latest")!

    @MainActor static func open(_ url: URL) { NSWorkspace.shared.open(url) }
}

enum AppInfo {
    static var version: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0-dev" }
    static var build: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0" }
}

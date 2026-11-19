import ByteBroomCore
import Foundation
import Observation
import SwiftUI

@Observable @MainActor
final class UpdateChecker {
    enum State: Equatable, Sendable { case idle, checking, upToDate(String), available(SemVer, URL), failed(String) }
    private(set) var state: State = .idle

    func check() {
        guard state != .checking else { return }
        state = .checking
        let current = AppInfo.version
        Task {
            state = await Self.fetch(current: current)
        }
    }

    private struct Release: Decodable {
        let tagName: String
        let htmlUrl: String?
    }

    nonisolated static func fetch(current: String) async -> State {
        var req = URLRequest(url: Links.latestReleaseAPI, timeoutInterval: 15)
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        let data: Data, resp: URLResponse
        do {
            (data, resp) = try await URLSession.shared.data(for: req)
        } catch {
            return .failed(error.localizedDescription)
        }
        guard let http = resp as? HTTPURLResponse else { return .failed("No response from GitHub.") }
        if http.statusCode == 404 { return .failed("No releases have been published yet.") }
        if http.statusCode == 429 || (http.statusCode == 403 && (
            http.value(forHTTPHeaderField: "x-ratelimit-remaining") == "0" || http.value(forHTTPHeaderField: "retry-after") != nil
        )) {
            return .failed("GitHub is limiting requests right now. Try again in a little while.")
        }
        guard http.statusCode == 200 else { return .failed("GitHub returned status \(http.statusCode).") }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        guard let release = try? decoder.decode(Release.self, from: data) else {
            return .failed("GitHub sent a response Byte Broom couldn't read.")
        }
        switch updateStatus(current: current, latestTag: release.tagName) {
        case .upToDate: return .upToDate(SemVer(release.tagName)?.description ?? current)
        case .available(let v): return .available(v, validatedReleaseURL(release.htmlUrl))
        case .unknown:
            return .failed(SemVer(current) == nil
                ? "This copy of Byte Broom has no version number."
                : "Couldn't read the latest version number.")
        }
    }
}

struct UpdateView: View {
    let checker: UpdateChecker
    @Environment(\.dismissWindow) private var dismissWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch checker.state {
            case .idle:
                Text("Click Check Now to ask GitHub for the latest version of Byte Broom.")
                buttons { Button("Check Now") { checker.check() }.keyboardShortcut(.defaultAction) }
            case .checking:
                HStack(spacing: 10) {
                    ProgressView().controlSize(.small)
                    Text("Checking for updates…")
                }
            case .upToDate(let latest):
                Text("You're up to date.").font(.headline)
                Text("Byte Broom \(latest) is the latest version.")
                buttons { Button("OK") { dismissWindow(id: "updates") }.keyboardShortcut(.defaultAction) }
            case .available(let version, let url):
                Text("Byte Broom \(version.description) is available.").font(.headline)
                Text("You have \(AppInfo.version).")
                buttons {
                    Button("Later") { dismissWindow(id: "updates") }.keyboardShortcut(.cancelAction)
                    Button("Download") { Links.open(url); dismissWindow(id: "updates") }.keyboardShortcut(.defaultAction)
                }
            case .failed(let reason):
                Text("Couldn't check for updates.").font(.headline)
                Text(reason).foregroundStyle(.secondary).textSelection(.enabled)
                buttons {
                    Button("View Releases") { Links.open(releasesPageURL) }
                    Button("Try Again") { checker.check() }.keyboardShortcut(.defaultAction)
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(20)
        .frame(width: 360, alignment: .leading)
    }

    private func buttons(@ViewBuilder _ content: () -> some View) -> some View {
        HStack {
            Spacer()
            content()
        }
        .padding(.top, 4)
    }
}

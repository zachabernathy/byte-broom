import AppKit
import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
                .accessibilityHidden(true)
            Text("Byte Broom").font(.title2.bold())
            Text("Version \(AppInfo.version) (\(AppInfo.build))")
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
            Text("Find the big files cluttering your Mac and sweep them into the Trash.")
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            VStack(spacing: 2) {
                Text("© 2026 The Z Man")
                Text("Licensed under the GNU GPL v3.0")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            VStack(spacing: 8) {
                HStack {
                    Button("GitHub") { Links.open(Links.repo) }
                    Button("Report an Issue") { Links.open(Links.newIssue) }
                }
                HStack {
                    Button("Privacy") { Links.open(Links.privacy) }
                    Button("☕ Buy Me a Coffee") { Links.open(Links.support) }
                        .buttonStyle(.borderedProminent)
                        .accessibilityLabel("Buy Me a Coffee")
                }
            }
            .padding(.top, 6)
        }
        .padding(24)
        .frame(width: 360)
    }
}

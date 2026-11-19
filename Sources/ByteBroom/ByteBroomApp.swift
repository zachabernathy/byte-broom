import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

@main
struct ByteBroomApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var model = AppModel()
    @State private var updates = UpdateChecker()

    var body: some Scene {
        Window("Byte Broom", id: "main") {
            ContentView(model: model)
                .frame(minWidth: 820, minHeight: 460)
        }
        .defaultSize(width: 1100, height: 700)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Rescan") { model.rescan() }
                    .keyboardShortcut("r")
                    .disabled(model.isBusy)
            }
            InfoCommands(updates: updates)
        }

        Window("About Byte Broom", id: "about") {
            AboutView()
        }
        .windowResizability(.contentSize)
        .commandsRemoved()

        Window("Byte Broom Help", id: "help") {
            HelpView()
        }
        .defaultSize(width: 520, height: 600)
        .commandsRemoved()

        Window("Check for Updates", id: "updates") {
            UpdateView(checker: updates)
        }
        .windowResizability(.contentSize)
        .commandsRemoved()
    }
}

private struct InfoCommands: Commands {
    let updates: UpdateChecker
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("About Byte Broom") { openWindow(id: "about") }
            Button("Check for Updates…") {
                openWindow(id: "updates")
                updates.check()
            }
        }
        CommandGroup(before: .windowList) {
            Button("Byte Broom") { openWindow(id: "main") }
                .keyboardShortcut("0")
            Divider()
        }
        CommandGroup(replacing: .help) {
            Button("Byte Broom Help") { openWindow(id: "help") }
                .keyboardShortcut("?", modifiers: .command)
            Divider()
            Button("Report an Issue…") { Links.open(Links.newIssue) }
            Button("Support Byte Broom…") { Links.open(Links.support) }
            Button("View on GitHub") { Links.open(Links.repo) }
        }
    }
}

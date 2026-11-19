import ByteBroomCore
import SwiftUI

private let sizeOptions: [(String, Int64)] = [
    ("Any size", 0), ("At least 1 MB", 1_000_000), ("At least 10 MB", 10_000_000),
    ("At least 100 MB", 100_000_000), ("At least 1 GB", 1_000_000_000),
]

private let ageOptions: [(String, Int)] = [
    ("Created any time", 0), ("Created over 30 days ago", 30), ("Created over 90 days ago", 90),
    ("Created over 6 months ago", 182), ("Created over 1 year ago", 365), ("Created over 2 years ago", 730),
]

struct ContentView: View {
    @Bindable var model: AppModel
    @State private var confirmation = TrashConfirmation(count: 0, size: 0, notShown: 0)
    @State private var confirming = false

    var body: some View {
        NavigationSplitView {
            SidebarView(model: model)
        } detail: {
            VStack(spacing: 0) {
                banners
                content
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                BottomBar(model: model) {
                    confirmation = model.trashConfirmation()
                    confirming = true
                }
            }
        }
        .searchable(text: $model.searchText, placement: .toolbar, prompt: "Search names")
        .toolbar { toolbar }
        .confirmationDialog(
            "Move \(fileCount(confirmation.count)) to the Trash?",
            isPresented: $confirming,
            titleVisibility: .visible
        ) {
            Button("Move to Trash", role: .destructive) { model.trashMarked() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(confirmationMessage(confirmation))
        }
        .task {
            if !model.hasScanned { model.rescan() }
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItemGroup {
            Picker("Folder", selection: $model.filters.folder) {
                Text("All folders").tag(String?.none)
                ForEach(model.folders, id: \.self) { Text($0).tag(String?.some($0)) }
            }
            .help("Folder")
            Picker("Minimum size", selection: $model.filters.minSize) {
                ForEach(sizeOptions, id: \.1) { Text($0.0).tag($0.1) }
            }
            .help("Minimum size")
            Picker("Created", selection: $model.filters.olderThanDays) {
                ForEach(ageOptions, id: \.1) { Text($0.0).tag($0.1) }
            }
            .help("Created more than")
            Button { model.rescan() } label: {
                Label("Rescan", systemImage: "arrow.clockwise")
            }
            .help("Scan the folders again (⌘R)")
            .disabled(model.isBusy)
        }
    }

    @ViewBuilder
    private var banners: some View {
        if !model.blockedRoots.isEmpty {
            Banner(systemImage: "lock.fill", tint: .orange) {
                Text("macOS blocked access to: \(model.blockedRoots.joined(separator: ", ")). Open System Settings > Privacy & Security > Files and Folders, allow Byte Broom, then click Rescan.")
            }
        }
        if let message = model.message {
            Banner(systemImage: message.failures.isEmpty ? "checkmark.circle.fill" : "exclamationmark.triangle.fill",
                   tint: message.failures.isEmpty ? .green : .orange,
                   onClose: { model.message = nil }) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(message.text)
                    if !message.failures.isEmpty {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 2) {
                                ForEach(Array(message.failures.enumerated()), id: \.offset) { Text($0.element) }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxHeight: 96)
                        .foregroundStyle(.secondary)
                    }
                }
                .textSelection(.enabled)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if !model.hasScanned || (model.isScanning && model.all.isEmpty) {
            VStack(spacing: 12) {
                ProgressView()
                Text("Scanning… \(fileCount(model.scanCount)) found")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if model.all.isEmpty {
            ContentUnavailableView(
                "No Files Found", systemImage: "folder",
                description: Text("Nothing was found in Desktop, Documents, Downloads, Movies, Music, or Pictures.")
            )
        } else if model.shown.isEmpty {
            ContentUnavailableView(
                "No Matching Files", systemImage: "line.3.horizontal.decrease.circle",
                description: Text("No files match the current search and filters.")
            )
        } else {
            FileTableView(model: model)
        }
    }

    private func confirmationMessage(_ c: TrashConfirmation) -> String {
        var text = "Total size: \(formatSize(c.size)). You can restore them from the Trash with Put Back."
        if c.notShown > 0 { text += " \(c.notShown.formatted()) of these are not shown right now." }
        return text
    }
}

private struct Banner<Content: View>: View {
    let systemImage: String
    let tint: Color
    var onClose: (() -> Void)? = nil
    @ViewBuilder let content: Content

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage).foregroundStyle(tint)
            content.frame(maxWidth: .infinity, alignment: .leading)
            if let onClose {
                Button(action: onClose) { Image(systemName: "xmark") }
                    .buttonStyle(.borderless)
                    .help("Dismiss")
            }
        }
        .padding(10)
        .background(tint.opacity(0.12))
        .overlay(alignment: .bottom) { Divider() }
    }
}

import AppKit
import ByteBroomCore
import SwiftUI

struct FileTableView: View {
    @Bindable var model: AppModel
    @State private var rowSelection = Set<String>()

    var body: some View {
        Table(model.shown, selection: $rowSelection, sortOrder: $model.sortOrder) {
            TableColumn("") { (entry: FileEntry) in
                Toggle("Mark", isOn: Binding(
                    get: { model.marked.contains(entry.path) },
                    set: { model.setMarked([entry.path], $0) }
                ))
                .toggleStyle(.checkbox)
                .labelsHidden()
                .disabled(model.isBusy)
            }
            .width(24)
            TableColumn("Name", value: \.name) { entry in
                Text(entry.name).help(entry.path)
            }
            .width(min: 160, ideal: 320)
            TableColumn("Size", value: \.size) { entry in
                Text(formatSize(entry.size))
                    .monospacedDigit()
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(min: 70, ideal: 90)
            TableColumn("Created", value: \.created) { entry in
                Text(entry.created.formatted(date: .abbreviated, time: .omitted))
            }
            .width(min: 90, ideal: 110)
            TableColumn("Modified", value: \.modified) { entry in
                Text(entry.modified.formatted(date: .abbreviated, time: .omitted))
            }
            .width(min: 90, ideal: 110)
            TableColumn("Folder", value: \.folder) { entry in
                Text(entry.folder).foregroundStyle(.secondary)
            }
            .width(min: 120, ideal: 240)
        }
        .contextMenu(forSelectionType: String.self) { paths in
            if !paths.isEmpty {
                Button("Show in Finder") { reveal(paths) }
                Divider()
                Button("Mark") { model.setMarked(paths, true) }.disabled(model.isBusy)
                Button("Unmark") { model.setMarked(paths, false) }.disabled(model.isBusy)
            }
        } primaryAction: { paths in
            reveal(paths)
        }
        .onChange(of: model.selection) { rowSelection = [] }
    }

    private func reveal(_ paths: Set<String>) {
        guard !paths.isEmpty else { return }
        NSWorkspace.shared.activateFileViewerSelecting(paths.map { URL(fileURLWithPath: $0) })
    }
}

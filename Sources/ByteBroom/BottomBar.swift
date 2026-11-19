import SwiftUI

struct BottomBar: View {
    let model: AppModel
    let onTrash: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            if model.isScanning && model.hasScanned {
                status("Scanning… \(fileCount(model.scanCount)) found")
            } else if model.isTrashing {
                status("Moving to Trash…")
            }
            Text("\(fileCount(model.shown.count)) · \(formatSize(model.shownSize)) shown")
            Text("\(model.marked.count.formatted()) marked · \(formatSize(model.markedSize))")
            Spacer()
            Button("Mark all shown") { model.markAllShown() }
                .disabled(model.isBusy || model.shown.isEmpty)
            Button("Clear marks") { model.clearMarks() }
                .disabled(model.isBusy || model.marked.isEmpty)
            Button("Move \(model.marked.count.formatted()) to Trash", action: onTrash)
                .buttonStyle(.borderedProminent)
                .disabled(model.isBusy || model.marked.isEmpty)
        }
        .monospacedDigit()
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
    }

    private func status(_ text: String) -> some View {
        HStack(spacing: 6) {
            ProgressView().controlSize(.small)
            Text(text).foregroundStyle(.secondary)
        }
    }
}

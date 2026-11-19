import ByteBroomCore
import SwiftUI

struct SidebarView: View {
    let model: AppModel

    var body: some View {
        List(selection: Binding(get: { model.selection }, set: { if let item = $0 { model.selection = item } })) {
            ForEach(model.groups) { group in
                SidebarRow(group: group)
            }
        }
        .navigationSplitViewColumnWidth(min: 190, ideal: 230)
    }
}

private struct SidebarRow: View {
    let group: CategoryGroup

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: symbol)
        }
        .padding(.vertical, 2)
    }

    private var title: String {
        if case .category(let c) = group.item { return c.rawValue }
        return "All"
    }

    private var detail: String {
        var text = "\(fileCount(group.count)) · \(formatSize(group.size))"
        if group.marked > 0 { text += " · \(group.marked.formatted()) marked" }
        return text
    }

    private var symbol: String {
        guard case .category(let c) = group.item else { return "square.grid.2x2" }
        switch c {
        case .documents: return "doc.text"
        case .videos: return "film"
        case .images: return "photo"
        case .audio: return "music.note"
        case .installers: return "shippingbox"
        case .archives: return "archivebox"
        case .apps: return "app"
        case .other: return "questionmark.folder"
        }
    }
}

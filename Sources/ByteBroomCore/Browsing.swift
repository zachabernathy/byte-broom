import Foundation

public struct BrowseFilters: Equatable, Sendable {
    public var folder: String? = nil
    public var minSize: Int64 = 0
    public var olderThanDays: Int = 0
    public var search: String = ""

    public init(folder: String? = nil, minSize: Int64 = 0, olderThanDays: Int = 0, search: String = "") {
        self.folder = folder
        self.minSize = minSize
        self.olderThanDays = olderThanDays
        self.search = search
    }
}

public enum SidebarItem: Hashable, Sendable {
    case all
    case category(FileCategory)
}

public struct CategoryGroup: Identifiable, Hashable, Sendable {
    public let item: SidebarItem
    public let count: Int
    public let size: Int64
    public let marked: Int
    public var id: SidebarItem { item }

    public init(item: SidebarItem, count: Int, size: Int64, marked: Int) {
        self.item = item
        self.count = count
        self.size = size
        self.marked = marked
    }
}

public func applyFilters(_ entries: [FileEntry], _ filters: BrowseFilters, now: Date) -> [FileEntry] {
    let search = filters.search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    let cutoff = filters.olderThanDays > 0
        ? now.addingTimeInterval(-Double(filters.olderThanDays) * 86_400)
        : nil
    return entries.filter { e in
        if let folder = filters.folder, e.root != folder { return false }
        if e.size < filters.minSize { return false }
        if let cutoff, e.created >= cutoff { return false }
        if !search.isEmpty, !e.name.lowercased().contains(search) { return false }
        return true
    }
}

public func makeGroups(
    all: [FileEntry], filtered: [FileEntry], marked: Set<String>, current: SidebarItem?
) -> [CategoryGroup] {
    var totals: [FileCategory: (count: Int, size: Int64)] = [:]
    var totalSize: Int64 = 0
    for e in filtered {
        totals[e.category, default: (0, 0)].count += 1
        totals[e.category, default: (0, 0)].size += e.size
        totalSize += e.size
    }

    var markedBy: [FileCategory: Int] = [:]
    var markedTotal = 0
    var currentInAll = false
    var currentCategory: FileCategory?
    if case .category(let c) = current { currentCategory = c }
    for e in all {
        if !marked.isEmpty, marked.contains(e.path) {
            markedBy[e.category, default: 0] += 1
            markedTotal += 1
        }
        if e.category == currentCategory { currentInAll = true }
    }
    if let currentCategory, currentInAll, totals[currentCategory] == nil {
        totals[currentCategory] = (0, 0)
    }

    let categories = totals
        .sorted { $0.value.size != $1.value.size ? $0.value.size > $1.value.size : $0.key.rawValue < $1.key.rawValue }
        .map { CategoryGroup(item: .category($0.key), count: $0.value.count, size: $0.value.size, marked: markedBy[$0.key, default: 0]) }
    return [CategoryGroup(item: .all, count: filtered.count, size: totalSize, marked: markedTotal)] + categories
}

public func resolveSelection(_ current: SidebarItem?, all: [FileEntry], groups: [CategoryGroup]) -> SidebarItem {
    switch current {
    case .all:
        return .all
    case .category(let c) where all.contains(where: { $0.category == c }):
        return .category(c)
    default:
        return groups.first { $0.item != .all }?.item ?? .all
    }
}

public func entries(_ filtered: [FileEntry], in item: SidebarItem) -> [FileEntry] {
    guard case .category(let c) = item else { return filtered }
    return filtered.filter { $0.category == c }
}

/// Approximates Finder's `localizedStandardCompare` (case/diacritic-insensitive, digit runs
/// compared numerically via a length prefix after dropping leading zeros) at ~5x the speed for
/// 500k names. Names that fold to the same key are ordered by their raw UTF-8 bytes after a 0
/// separator, so the order is total. Not locale-aware collation; switch to
/// `localizedStandardCompare` if users notice order differences.
/// Digit runs longer than 255 digits share one length byte and compare as text.
public func sortKey(_ s: String) -> [UInt8] {
    let nfc = s.utf8.allSatisfy { $0 < 0x80 } ? s : s.precomposedStringWithCanonicalMapping
    let folded = nfc.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
    var key: [UInt8] = []
    key.reserveCapacity(folded.utf8.count + s.utf8.count + 5)
    var digits: [UInt8] = []
    func flush() {
        guard !digits.isEmpty else { return }
        let value = digits.drop { $0 == 48 }
        let kept = value.isEmpty ? digits.suffix(1) : value
        key.append(UInt8(min(kept.count, 255)))
        key += kept
        digits.removeAll(keepingCapacity: true)
    }
    for byte in folded.utf8 {
        if (48...57).contains(byte) { digits.append(byte) } else { flush(); key.append(byte) }
    }
    flush()
    key.append(0)
    key += s.utf8
    return key
}

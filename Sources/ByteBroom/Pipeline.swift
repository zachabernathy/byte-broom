import Foundation
import ByteBroomCore

enum SortKey: Sendable {
    case name, size, created, modified, folder
}

struct SortSpec: Sendable, Equatable {
    var key: SortKey = .size
    var ascending = false

    init(key: SortKey = .size, ascending: Bool = false) {
        self.key = key
        self.ascending = ascending
    }

    init(_ order: [KeyPathComparator<FileEntry>]) {
        guard let first = order.first else { self.init(); return }
        let path = first.keyPath
        let key: SortKey =
            path == \FileEntry.name ? .name
            : path == \FileEntry.created ? .created
            : path == \FileEntry.modified ? .modified
            : path == \FileEntry.folder ? .folder
            : .size
        self.init(key: key, ascending: first.order == .forward)
    }
}

struct EntryInfo: Sendable {
    let size: Int64
    let category: FileCategory
}

/// Scan results prepared once per scan. `entries` is kept in name order (`sortKey`),
/// so name sorting is free and other sorts use it as the tie-breaker.
struct Catalog: Sendable {
    var entries: [FileEntry] = []
    var info: [String: EntryInfo] = [:]
    var known: Set<String> = []
    var folderRank: [String: Int32] = [:]
    var folders: [String] = []
    var unreadableRoots: [String] = []

    init() {}

    init(_ result: ScanResult, roots: [URL]) {
        let nameKeys = result.entries.map { sortKey($0.name) }
        entries = result.entries.indices
            .sorted { nameKeys[$0].lexicographicallyPrecedes(nameKeys[$1]) }
            .map { result.entries[$0] }
        unreadableRoots = result.unreadableRoots
        info.reserveCapacity(entries.count)
        for e in entries { info[e.path] = EntryInfo(size: e.size, category: e.category) }
        known = Set(info.keys)
        let uniqueFolders = Set(entries.map(\.folder)).map { ($0, sortKey($0)) }
            .sorted { $0.1.lexicographicallyPrecedes($1.1) }
        for (i, f) in uniqueFolders.enumerated() { folderRank[f.0] = Int32(i) }
        let present = Set(entries.map(\.root))
        folders = roots.map(\.lastPathComponent).filter(present.contains)
    }

    mutating func remove(_ gone: Set<String>) {
        guard !gone.isEmpty else { return }
        entries.removeAll { gone.contains($0.path) }
        for path in gone {
            info[path] = nil
            known.remove(path)
        }
    }
}

struct ViewInput: Sendable {
    var entries: [FileEntry]
    var folderRank: [String: Int32]
    var filters: BrowseFilters
    var selection: SidebarItem?
    var sort: SortSpec
    var now: Date
}

struct ViewOutput: Sendable {
    var selection: SidebarItem
    var groups: [CategoryGroup]
    var shown: [FileEntry]
    var shownSize: Int64
}

/// Groups come back with zero marked counts; `withMarks` fills them in on the main actor.
/// Returns nil when the calling task was cancelled before the sort.
func computeView(_ input: ViewInput) -> ViewOutput? {
    let all = input.entries
    let filtered = applyFilters(all, input.filters, now: input.now)
    var groups = makeGroups(all: all, filtered: filtered, marked: [], current: input.selection)
    let selection = resolveSelection(input.selection, all: all, groups: groups)
    if selection != input.selection {
        groups = makeGroups(all: all, filtered: filtered, marked: [], current: selection)
    }
    if Task.isCancelled { return nil }
    let shown = sortEntries(entries(filtered, in: selection), input.sort, folderRank: input.folderRank)
    return ViewOutput(selection: selection, groups: groups, shown: shown, shownSize: shown.reduce(0) { $0 + $1.size })
}

func sortEntries(_ items: [FileEntry], _ spec: SortSpec, folderRank: [String: Int32]) -> [FileEntry] {
    switch spec.key {
    case .name: return spec.ascending ? items : Array(items.reversed())
    case .size: return ordered(items, spec.ascending) { $0.size }
    case .created: return ordered(items, spec.ascending) { $0.created.timeIntervalSinceReferenceDate }
    case .modified: return ordered(items, spec.ascending) { $0.modified.timeIntervalSinceReferenceDate }
    case .folder: return ordered(items, spec.ascending) { folderRank[$0.folder] ?? 0 }
    }
}

private func ordered<K: Comparable>(_ items: [FileEntry], _ ascending: Bool, _ key: (FileEntry) -> K) -> [FileEntry] {
    let keys = items.map(key)
    return items.indices
        .sorted { a, b in keys[a] == keys[b] ? a < b : (keys[a] < keys[b]) == ascending }
        .map { items[$0] }
}

struct MarkTally: Sendable, Equatable {
    var size: Int64 = 0
    var byCategory: [FileCategory: Int] = [:]

    mutating func add(_ info: EntryInfo) {
        size += info.size
        byCategory[info.category, default: 0] += 1
    }

    mutating func remove(_ info: EntryInfo) {
        size -= info.size
        byCategory[info.category, default: 0] -= 1
    }
}

func withMarks(_ groups: [CategoryGroup], _ tally: MarkTally, total: Int) -> [CategoryGroup] {
    groups.map { g in
        var marked = total
        if case .category(let c) = g.item { marked = tally.byCategory[c, default: 0] }
        return CategoryGroup(item: g.item, count: g.count, size: g.size, marked: marked)
    }
}

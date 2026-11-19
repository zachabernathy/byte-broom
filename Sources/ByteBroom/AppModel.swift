import Foundation
import ByteBroomCore
import Observation

struct AppMessage {
    var text: String
    var failures: [String]
}

struct TrashConfirmation {
    var count: Int
    var size: Int64
    var notShown: Int
}

func formatSize(_ bytes: Int64) -> String {
    ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
}

func fileCount(_ n: Int) -> String {
    n == 1 ? "1 file" : "\(n.formatted()) files"
}

@MainActor @Observable
final class AppModel {
    let home: URL
    let roots: [URL]

    private(set) var all: [FileEntry] = []
    private(set) var folders: [String] = []
    var filters = BrowseFilters() {
        didSet { if filters != oldValue { recompute() } }
    }
    var searchText = "" {
        didSet { scheduleSearch() }
    }
    var selection: SidebarItem? {
        didSet { if selection != oldValue, !resolving { recompute() } }
    }
    private(set) var marked: Set<String> = []
    var sortOrder = [KeyPathComparator(\FileEntry.size, order: .reverse)] {
        didSet { if SortSpec(sortOrder) != SortSpec(oldValue) { recompute() } }
    }
    private(set) var hasScanned = false
    private(set) var isScanning = false
    private(set) var scanCount = 0
    private(set) var isTrashing = false
    private(set) var blockedRoots: [String] = []
    var message: AppMessage?

    private(set) var groups: [CategoryGroup] = []
    private(set) var shown: [FileEntry] = []
    private(set) var shownSize: Int64 = 0
    private var tally = MarkTally()

    @ObservationIgnored private var catalog = Catalog()
    @ObservationIgnored private var baseGroups: [CategoryGroup] = []
    @ObservationIgnored private var loaded = false
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var afterApply: [() -> Void] = []
    @ObservationIgnored private var searchTask: Task<Void, Never>?
    @ObservationIgnored private var computeTask: Task<ViewOutput?, Never>?
    @ObservationIgnored private var resolving = false

    var isBusy: Bool { isScanning || isTrashing }
    var markedSize: Int64 { tally.size }

    init() {
        let override = ProcessInfo.processInfo.environment["BYTE_BROOM_HOME"]
        home = override.map { URL(fileURLWithPath: $0, isDirectory: true) }
            ?? FileManager.default.homeDirectoryForCurrentUser
        roots = defaultRoots(home: home)
    }

    func rescan() {
        guard !isBusy else { return }
        isScanning = true
        scanCount = 0
        message = nil
        let roots = roots, home = home
        Task {
            let catalog = await Task.detached(priority: .userInitiated) {
                let result = scan(roots: roots, home: home) { n in
                    Task { @MainActor in self.scanCount = n }
                }
                return Catalog(result, roots: roots)
            }.value
            self.catalog = catalog
            all = catalog.entries
            folders = catalog.folders
            blockedRoots = catalog.unreadableRoots
            retally()
            loaded = true
            afterApply.append { [self] in
                hasScanned = true
                isScanning = false
            }
            if let folder = filters.folder, !folders.contains(folder) { filters.folder = nil }
            recompute()
        }
    }

    func trashConfirmation() -> TrashConfirmation {
        let shownMarked = shown.reduce(0) { $0 + (marked.contains($1.path) ? 1 : 0) }
        return TrashConfirmation(count: marked.count, size: markedSize, notShown: marked.count - shownMarked)
    }

    func trashMarked() {
        guard !isBusy, !marked.isEmpty else { return }
        isTrashing = true
        message = nil
        let paths = Array(marked), roots = roots, known = catalog.known
        Task {
            let result = await trashPaths(paths, roots: roots, known: known, trasher: SystemTrasher())
            let gone = Set(result.trashed)
            catalog.remove(gone)
            all = catalog.entries
            retally()

            var text = gone.isEmpty ? "No files were moved to the Trash." : "Moved \(fileCount(gone.count)) to the Trash."
            if !result.failed.isEmpty { text += " \(fileCount(result.failed.count)) could not be moved:" }
            let failures = result.failed.map { "\(($0.path as NSString).lastPathComponent): \($0.error)" }
            afterApply.append { [self] in
                isTrashing = false
                message = AppMessage(text: text, failures: failures)
            }
            recompute()
        }
    }

    func setMarked(_ paths: some Sequence<String>, _ on: Bool) {
        guard !isBusy else { return }
        var next = marked
        marked = []
        var nextTally = tally
        for path in paths {
            guard let info = catalog.info[path] else { continue }
            if on {
                if next.insert(path).inserted { nextTally.add(info) }
            } else if next.remove(path) != nil {
                nextTally.remove(info)
            }
        }
        marked = next
        updateMarks(nextTally)
    }

    func markAllShown() {
        setMarked(shown.lazy.map(\.path), true)
    }

    func clearMarks() {
        guard !isBusy else { return }
        marked = []
        updateMarks(MarkTally())
    }

    private func retally() {
        var nextTally = MarkTally()
        marked = marked.filter { path in
            guard let info = catalog.info[path] else { return false }
            nextTally.add(info)
            return true
        }
        updateMarks(nextTally)
    }

    private func updateMarks(_ nextTally: MarkTally) {
        tally = nextTally
        groups = withMarks(baseGroups, tally, total: marked.count)
    }

    private func scheduleSearch() {
        searchTask?.cancel()
        searchTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled, let self else { return }
            filters.search = searchText
        }
    }

    private func recompute() {
        guard loaded else { return }
        generation += 1
        let gen = generation
        let input = ViewInput(
            entries: catalog.entries, folderRank: catalog.folderRank, filters: filters,
            selection: selection, sort: SortSpec(sortOrder), now: Date()
        )
        computeTask?.cancel()
        let task = Task.detached(priority: .userInitiated) { computeView(input) }
        computeTask = task
        Task {
            guard let output = await task.value, gen == generation else { return }
            apply(output)
        }
    }

    private func apply(_ output: ViewOutput) {
        if output.selection != selection {
            resolving = true
            selection = output.selection
            resolving = false
        }
        baseGroups = output.groups
        groups = withMarks(baseGroups, tally, total: marked.count)
        shown = output.shown
        shownSize = output.shownSize
        let pending = afterApply
        afterApply = []
        pending.forEach { $0() }
    }
}

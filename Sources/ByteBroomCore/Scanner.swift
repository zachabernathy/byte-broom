import Foundation

public struct FileEntry: Identifiable, Hashable, Sendable {
    public var id: String { path }
    public let path: String
    public let name: String
    public let category: FileCategory
    public let size: Int64
    public let created: Date
    public let modified: Date
    public let root: String
    public let folder: String

    public init(
        path: String, name: String, category: FileCategory, size: Int64,
        created: Date, modified: Date, root: String, folder: String
    ) {
        self.path = path
        self.name = name
        self.category = category
        self.size = size
        self.created = created
        self.modified = modified
        self.root = root
        self.folder = folder
    }
}

public struct ScanResult: Sendable {
    public var entries: [FileEntry]
    public var unreadableRoots: [String]

    public init(entries: [FileEntry], unreadableRoots: [String]) {
        self.entries = entries
        self.unreadableRoots = unreadableRoots
    }
}

public func defaultRoots(home: URL) -> [URL] {
    ["Desktop", "Documents", "Downloads", "Movies", "Music", "Pictures"].map { home.appendingPathComponent($0) }
}

public func scan(roots: [URL], home: URL, progress: ((Int) -> Void)? = nil) -> ScanResult {
    let fm = FileManager.default
    let homePrefix = home.path + "/"
    var entries: [FileEntry] = []
    var unreadableRoots: [String] = []

    for root in roots {
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: root.path, isDirectory: &isDir), isDir.boolValue else { continue }
        guard let rootNames = try? fm.contentsOfDirectory(atPath: root.path) else {
            unreadableRoots.append(root.lastPathComponent)
            continue
        }
        var stack = [(root.path, rootNames)]
        while let (dir, names) = stack.popLast() {
            let folder = dir.hasPrefix(homePrefix) ? String(dir.dropFirst(homePrefix.count)) : dir
            for name in names where !name.hasPrefix(".") {
                let path = dir + "/" + name
                var st = stat()
                guard lstat(path, &st) == 0 else { continue }
                var size = Int64(st.st_size)
                switch st.st_mode & S_IFMT {
                case S_IFREG, S_IFLNK:
                    break
                case S_IFDIR where isBundle(name: name):
                    size = bundleSize(path)
                case S_IFDIR:
                    if let children = try? fm.contentsOfDirectory(atPath: path) { stack.append((path, children)) }
                    continue
                default:
                    continue
                }
                entries.append(FileEntry(
                    path: path, name: name, category: category(forName: name), size: size,
                    created: date(st.st_birthtimespec), modified: date(st.st_mtimespec),
                    root: root.lastPathComponent, folder: folder
                ))
                if entries.count % 500 == 0 { progress?(entries.count) }
            }
        }
    }
    progress?(entries.count)
    return ScanResult(entries: entries, unreadableRoots: unreadableRoots)
}

private func bundleSize(_ path: String) -> Int64 {
    var total: Int64 = 0
    var stack = [path]
    while let dir = stack.popLast() {
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: dir) else { continue }
        for name in names {
            let child = dir + "/" + name
            var st = stat()
            guard lstat(child, &st) == 0 else { continue }
            switch st.st_mode & S_IFMT {
            case S_IFDIR: stack.append(child)
            case S_IFREG: total += Int64(st.st_size)
            default: break
            }
        }
    }
    return total
}

private func date(_ ts: timespec) -> Date {
    Date(timeIntervalSince1970: TimeInterval(ts.tv_sec) + TimeInterval(ts.tv_nsec) / 1_000_000_000)
}

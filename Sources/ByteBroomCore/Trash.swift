import AppKit

public protocol Trasher: Sendable {
    func trash(_ urls: [URL]) async -> [URL: String]
}

public struct TrashFailure: Hashable, Sendable {
    public let path: String
    public let error: String

    public init(path: String, error: String) {
        self.path = path
        self.error = error
    }
}

public struct TrashResult: Sendable {
    public let trashed: [String]
    public let failed: [TrashFailure]
}

private func exists(_ path: String) -> Bool {
    var info = stat()
    return lstat(path, &info) == 0
}

private func resolved(_ path: String) -> String? {
    realpath(path, nil).map { pointer in
        defer { free(pointer) }
        return String(cString: pointer)
    }
}

public func isAllowed(path: String, roots: [URL], known: Set<String>) -> Bool {
    guard path.hasPrefix("/"), known.contains(path), let slash = path.lastIndex(of: "/") else { return false }
    let name = String(path[path.index(after: slash)...])
    guard !["", ".", ".."].contains(name), exists(path) else { return false }
    let parent = slash == path.startIndex ? "/" : String(path[..<slash])
    guard let realParent = resolved(parent) else { return false }
    let real = (realParent == "/" ? "" : realParent) + "/" + name
    return roots.contains { root in
        guard let realRoot = resolved(root.path) else { return false }
        return real.hasPrefix(realRoot == "/" ? "/" : realRoot + "/")
    }
}

public func trashPaths(_ paths: [String], roots: [URL], known: Set<String>, trasher: Trasher) async -> TrashResult {
    var seen = Set<String>()
    let unique = paths.filter { seen.insert($0).inserted }
    let allowed = unique.filter { isAllowed(path: $0, roots: roots, known: known) }
    var errors: [String: String] = [:]
    if !allowed.isEmpty {
        for (url, message) in await trasher.trash(allowed.map { URL(fileURLWithPath: $0) }) {
            errors[url.path] = message
        }
    }
    let allowedSet = Set(allowed)
    var trashed: [String] = []
    var failed: [TrashFailure] = []
    for path in unique {
        if !allowedSet.contains(path) {
            failed.append(TrashFailure(path: path, error: "not allowed"))
        } else if exists(path) {
            failed.append(TrashFailure(path: path, error: errors[URL(fileURLWithPath: path).path] ?? "still exists after trash"))
        } else {
            trashed.append(path)
        }
    }
    return TrashResult(trashed: trashed, failed: failed)
}

public struct SystemTrasher: Trasher {
    public init() {}

    public func trash(_ urls: [URL]) async -> [URL: String] {
        await withCheckedContinuation { continuation in
            NSWorkspace.shared.recycle(urls) { newURLs, error in
                let done = Set(newURLs.keys.map(\.path))
                let message = error?.localizedDescription ?? "could not move to Trash"
                var failures: [URL: String] = [:]
                for url in urls where !done.contains(url.path) {
                    failures[url] = message
                }
                continuation.resume(returning: failures)
            }
        }
    }
}

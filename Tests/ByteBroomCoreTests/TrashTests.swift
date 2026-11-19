import XCTest
import ByteBroomCore

private actor RemovingTrasher: Trasher {
    private(set) var calls: [[URL]] = []
    let failures: Set<String>
    let removes: Bool

    init(removes: Bool = true, failures: Set<String> = []) {
        self.removes = removes
        self.failures = failures
    }

    func trash(_ urls: [URL]) async -> [URL: String] {
        calls.append(urls)
        var result: [URL: String] = [:]
        for url in urls {
            if failures.contains(url.path) {
                result[url] = "locked"
            } else if removes {
                try? FileManager.default.removeItem(at: url)
            }
        }
        return result
    }
}

final class TrashTests: XCTestCase {
    private var base: URL!
    private var rootA: URL!
    private var rootB: URL!
    private var outside: URL!
    private let fm = FileManager.default

    override func setUpWithError() throws {
        let tmp = fm.temporaryDirectory.appendingPathComponent("TrashTests-\(UUID().uuidString)")
        try fm.createDirectory(at: tmp, withIntermediateDirectories: true)
        base = URL(fileURLWithPath: realpath(tmp.path, nil).map { String(cString: $0) }!)
        let dir = base!
        addTeardownBlock { try? FileManager.default.removeItem(at: dir) }
        rootA = base.appendingPathComponent("A")
        rootB = base.appendingPathComponent("B")
        outside = base.appendingPathComponent("outside")
        for dir in [rootA!, rootB!, outside!, rootA.appendingPathComponent("sub")] {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }

    private var roots: [URL] { [rootA, rootB] }

    @discardableResult
    private func write(_ dir: URL, _ name: String) throws -> String {
        let url = dir.appendingPathComponent(name)
        try Data("x".utf8).write(to: url)
        return url.path
    }

    private func allowed(_ path: String, known: Set<String>? = nil) -> Bool {
        isAllowed(path: path, roots: roots, known: known ?? [path])
    }

    func testKnownFilesInsideEitherRootAreAllowed() throws {
        XCTAssertTrue(allowed(try write(rootA, "a.txt")))
        XCTAssertTrue(allowed(try write(rootB, "b.txt")))
        XCTAssertTrue(allowed(try write(rootA.appendingPathComponent("sub"), "c.txt")))
    }

    func testRootItselfIsRejected() {
        XCTAssertFalse(allowed(rootA.path))
    }

    func testSiblingFolderSharingRootPrefixIsRejected() throws {
        let sibling = base.appendingPathComponent("A2")
        try fm.createDirectory(at: sibling, withIntermediateDirectories: true)
        XCTAssertFalse(allowed(try write(sibling, "file")))
        XCTAssertTrue(allowed(try write(rootA, "file")))
    }

    func testKnownPathOutsideRootsIsRejected() throws {
        XCTAssertFalse(allowed(try write(outside, "o.txt")))
    }

    func testDotSlashAndDotDotPathsAreRejectedEvenWhenKnown() throws {
        try write(rootA.appendingPathComponent("sub"), "keep.txt")
        for path in [rootA.path + "/.", rootA.path + "/sub/..", rootA.path + "/"] {
            XCTAssertFalse(allowed(path), path)
        }
    }

    func testPathUnderSymlinkedParentFolderIsRejected() throws {
        try write(outside, "outside.txt")
        try fm.createSymbolicLink(at: rootA.appendingPathComponent("link"), withDestinationURL: outside)
        XCTAssertFalse(allowed(rootA.path + "/link/outside.txt"))
    }

    func testSymlinkEntryPointingOutsideIsAllowed() throws {
        let target = try write(outside, "target.txt")
        let alias = rootA.appendingPathComponent("alias.txt")
        try fm.createSymbolicLink(atPath: alias.path, withDestinationPath: target)
        XCTAssertTrue(allowed(alias.path))
    }

    func testUnknownRelativeAndMissingPathsAreRejected() throws {
        let path = try write(rootA, "a.txt")
        XCTAssertFalse(allowed(path, known: []))
        XCTAssertFalse(allowed("A/a.txt"))
        XCTAssertFalse(allowed(rootA.path + "/missing.txt"))
    }

    func testTrashPathsCallsTrasherOnceWithAllowedPathsDedupedInOrder() async throws {
        let a = try write(rootA, "a.txt")
        let b = try write(rootB, "b.txt")
        let o = try write(outside, "o.txt")
        let trasher = RemovingTrasher()
        let result = await trashPaths([b, o, a, b], roots: roots, known: [a, b, o], trasher: trasher)

        let calls = await trasher.calls
        XCTAssertEqual(calls.map { $0.map(\.path) }, [[b, a]])
        XCTAssertEqual(result.trashed, [b, a])
        XCTAssertEqual(result.failed, [TrashFailure(path: o, error: "not allowed")])
        XCTAssertTrue(fm.fileExists(atPath: o))
    }

    func testReportedFailureKeepsTrasherMessage() async throws {
        let a = try write(rootA, "a.txt")
        let b = try write(rootA, "b.txt")
        let trasher = RemovingTrasher(failures: [b])
        let result = await trashPaths([a, b], roots: roots, known: [a, b], trasher: trasher)

        XCTAssertEqual(result.trashed, [a])
        XCTAssertEqual(result.failed, [TrashFailure(path: b, error: "locked")])
    }

    func testPathStillPresentWithoutMessageFails() async throws {
        let a = try write(rootA, "a.txt")
        let result = await trashPaths([a], roots: roots, known: [a], trasher: RemovingTrasher(removes: false))

        XCTAssertEqual(result.trashed, [])
        XCTAssertEqual(result.failed, [TrashFailure(path: a, error: "still exists after trash")])
    }

    func testTrasherNotCalledWhenNothingIsAllowed() async throws {
        let o = try write(outside, "o.txt")
        let trasher = RemovingTrasher()
        let result = await trashPaths([o, "relative.txt"], roots: roots, known: [o], trasher: trasher)

        let calls = await trasher.calls
        XCTAssertEqual(calls.count, 0)
        XCTAssertEqual(result.trashed, [])
        XCTAssertEqual(result.failed.map(\.path), [o, "relative.txt"])
    }
}

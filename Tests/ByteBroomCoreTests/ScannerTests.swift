import XCTest
import ByteBroomCore

final class ScannerTests: XCTestCase {
    private var home: URL!
    private let fm = FileManager.default

    override func setUpWithError() throws {
        let tmp = fm.temporaryDirectory.appendingPathComponent("ScannerTests-\(UUID().uuidString)")
        try fm.createDirectory(at: tmp, withIntermediateDirectories: true)
        home = URL(fileURLWithPath: realpath(tmp.path, nil).map { String(cString: $0) }!)
        let dir = home!
        addTeardownBlock { try? FileManager.default.removeItem(at: dir) }
    }

    private func write(_ relative: String, bytes: Int) throws {
        let url = home.appendingPathComponent(relative)
        try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(count: bytes).write(to: url)
    }

    private func mkdir(_ relative: String) throws {
        try fm.createDirectory(at: home.appendingPathComponent(relative), withIntermediateDirectories: true)
    }

    private func symlink(_ relative: String, to target: String) throws {
        try fm.createSymbolicLink(atPath: home.appendingPathComponent(relative).path, withDestinationPath: target)
    }

    private func lockForTest(_ relative: String) throws {
        try XCTSkipIf(geteuid() == 0, "root ignores permissions")
        let path = home.appendingPathComponent(relative).path
        XCTAssertEqual(chmod(path, 0), 0)
        addTeardownBlock { chmod(path, 0o755) }
    }

    private func scanRoots(_ names: String...) -> ScanResult {
        scan(roots: names.map { home.appendingPathComponent($0) }, home: home)
    }

    private func byName(_ result: ScanResult) -> [String: FileEntry] {
        Dictionary(uniqueKeysWithValues: result.entries.map { ($0.name, $0) })
    }

    func testNestedFilesHaveSizesRootAndFolder() throws {
        try write("Downloads/a.pdf", bytes: 10)
        try write("Downloads/sub/deep/b.mov", bytes: 25)
        let created = Date(timeIntervalSince1970: 1_600_000_000)
        let modified = Date(timeIntervalSince1970: 1_700_000_000)
        try fm.setAttributes(
            [.creationDate: created, .modificationDate: modified],
            ofItemAtPath: home.appendingPathComponent("Downloads/a.pdf").path
        )

        let entries = byName(scanRoots("Downloads"))

        XCTAssertEqual(entries.count, 2)
        let a = try XCTUnwrap(entries["a.pdf"])
        XCTAssertEqual(a.path, home.path + "/Downloads/a.pdf")
        XCTAssertEqual(a.id, a.path)
        XCTAssertEqual(a.size, 10)
        XCTAssertEqual(a.category, .documents)
        XCTAssertEqual(a.root, "Downloads")
        XCTAssertEqual(a.folder, "Downloads")
        XCTAssertEqual(a.modified, modified)
        XCTAssertEqual(a.created, created)
        let b = try XCTUnwrap(entries["b.mov"])
        XCTAssertEqual(b.size, 25)
        XCTAssertEqual(b.category, .videos)
        XCTAssertEqual(b.folder, "Downloads/sub/deep")
    }

    func testHiddenFilesAndFoldersAreSkipped() throws {
        try write("Downloads/.DS_Store", bytes: 1)
        try write("Downloads/.git/config.txt", bytes: 1)
        try write("Downloads/keep.txt", bytes: 1)

        XCTAssertEqual(scanRoots("Downloads").entries.map(\.name), ["keep.txt"])
    }

    func testBundleIsOneEntryWithSummedSize() throws {
        try write("Downloads/Thing.app/Contents/MacOS/bin", bytes: 100)
        try write("Downloads/Thing.app/Contents/Info.plist", bytes: 20)
        try write("Downloads/Thing.app/.hidden", bytes: 5)
        try write("Downloads/outside.bin", bytes: 1000)
        try symlink("Downloads/Thing.app/Contents/link", to: "../../outside.bin")

        let entries = byName(scanRoots("Downloads"))

        XCTAssertEqual(entries.count, 2)
        let app = try XCTUnwrap(entries["Thing.app"])
        XCTAssertEqual(app.size, 125)
        XCTAssertEqual(app.category, .apps)
        XCTAssertEqual(app.folder, "Downloads")
    }

    func testSymlinkIsListedWithOwnSizeAndNotFollowed() throws {
        try write("Downloads/big.bin", bytes: 1000)
        try symlink("Downloads/link.zip", to: "big.bin")
        try write("Elsewhere/secret.txt", bytes: 1)
        try symlink("Downloads/dirlink", to: home.appendingPathComponent("Elsewhere").path)

        let entries = byName(scanRoots("Downloads"))

        XCTAssertEqual(Set(entries.keys), ["big.bin", "link.zip", "dirlink"])
        XCTAssertEqual(entries["link.zip"]?.size, Int64("big.bin".utf8.count))
        XCTAssertEqual(entries["link.zip"]?.category, .archives)
        XCTAssertEqual(entries["dirlink"]?.category, .other)
    }

    func testBrokenSymlinkIsListed() throws {
        try mkdir("Downloads")
        try symlink("Downloads/gone.pdf", to: "/nonexistent/gone.pdf")

        let entries = byName(scanRoots("Downloads"))

        XCTAssertEqual(entries["gone.pdf"]?.category, .documents)
        XCTAssertEqual(entries["gone.pdf"]?.size, Int64("/nonexistent/gone.pdf".utf8.count))
    }

    func testMissingRootIsSkippedAndOthersScan() throws {
        try write("Downloads/a.txt", bytes: 1)

        let result = scanRoots("Missing", "Downloads")

        XCTAssertEqual(result.entries.map(\.name), ["a.txt"])
        XCTAssertEqual(result.unreadableRoots, [])
    }

    func testUnreadableSubfolderIsSkipped() throws {
        try write("Downloads/locked/hidden.txt", bytes: 1)
        try write("Downloads/open/seen.txt", bytes: 1)
        try write("Downloads/top.txt", bytes: 1)
        try lockForTest("Downloads/locked")

        let result = scanRoots("Downloads")

        XCTAssertEqual(Set(result.entries.map(\.name)), ["seen.txt", "top.txt"])
        XCTAssertEqual(result.unreadableRoots, [])
    }

    func testUnreadableRootIsReported() throws {
        try write("Downloads/a.txt", bytes: 1)
        try write("Documents/b.txt", bytes: 1)
        try lockForTest("Downloads")

        let result = scanRoots("Downloads", "Documents")

        XCTAssertEqual(result.entries.map(\.name), ["b.txt"])
        XCTAssertEqual(result.unreadableRoots, ["Downloads"])
    }

    func testDefaultRoots() {
        let home = URL(fileURLWithPath: "/Users/someone")
        XCTAssertEqual(
            defaultRoots(home: home).map(\.path),
            ["Desktop", "Documents", "Downloads", "Movies", "Music", "Pictures"].map { "/Users/someone/\($0)" }
        )
    }

    func testProgressReportsIncreasingCounts() throws {
        for i in 0..<1200 { try write("Downloads/d\(i % 3)/f\(i).txt", bytes: 0) }
        var counts: [Int] = []

        let result = scan(roots: [home.appendingPathComponent("Downloads")], home: home) { counts.append($0) }

        XCTAssertEqual(result.entries.count, 1200)
        XCTAssertEqual(counts, [500, 1000, 1200])
    }
}

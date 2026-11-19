import XCTest
import ByteBroomCore

private let now = Date(timeIntervalSince1970: 1_800_000_000)
private let day: TimeInterval = 86_400

private func entry(
    _ name: String, _ category: FileCategory, size: Int64 = 0,
    ageDays: Double = 0, root: String = "Downloads"
) -> FileEntry {
    let created = now.addingTimeInterval(-ageDays * day)
    return FileEntry(
        path: "/Users/me/\(root)/\(name)", name: name, category: category, size: size,
        created: created, modified: created, root: root, folder: root
    )
}

final class BrowsingTests: XCTestCase {
    private let sample = [
        entry("Report.pdf", .documents, size: 2_000_000, ageDays: 10, root: "Documents"),
        entry("movie.mov", .videos, size: 500_000_000, ageDays: 400, root: "Movies"),
        entry("photo.jpg", .images, size: 3_000_000, ageDays: 100, root: "Pictures"),
        entry("setup.dmg", .installers, size: 50_000_000, ageDays: 200, root: "Downloads"),
        entry("notes.txt", .documents, size: 1_000, ageDays: 40, root: "Downloads"),
    ]

    private func names(_ entries: [FileEntry]) -> [String] { entries.map(\.name) }

    func testNoFiltersKeepsEverything() {
        XCTAssertEqual(applyFilters(sample, BrowseFilters(), now: now), sample)
    }

    func testFolderFilter() {
        var f = BrowseFilters()
        f.folder = "Downloads"
        XCTAssertEqual(names(applyFilters(sample, f, now: now)), ["setup.dmg", "notes.txt"])
    }

    func testMinSizeFilter() {
        var f = BrowseFilters()
        f.minSize = 3_000_000
        XCTAssertEqual(names(applyFilters(sample, f, now: now)), ["movie.mov", "photo.jpg", "setup.dmg"])
    }

    func testAgeFilterUsesCreatedRelativeToNow() {
        var f = BrowseFilters()
        f.olderThanDays = 90
        XCTAssertEqual(names(applyFilters(sample, f, now: now)), ["movie.mov", "photo.jpg", "setup.dmg"])
        let exact = [entry("edge", .other, ageDays: 90)]
        XCTAssertEqual(applyFilters(exact, f, now: now), [])
    }

    func testSearchIsTrimmedCaseInsensitiveSubstring() {
        var f = BrowseFilters()
        f.search = "  REP "
        XCTAssertEqual(names(applyFilters(sample, f, now: now)), ["Report.pdf"])
        f.search = "   "
        XCTAssertEqual(applyFilters(sample, f, now: now), sample)
    }

    func testFiltersCombine() {
        var f = BrowseFilters()
        f.folder = "Downloads"
        f.minSize = 10_000
        f.olderThanDays = 30
        f.search = "set"
        XCTAssertEqual(names(applyFilters(sample, f, now: now)), ["setup.dmg"])
    }

    func testGroupsAllFirstThenSizeDescendingTiesByName() {
        let all = [
            entry("a", .videos, size: 100),
            entry("b", .images, size: 50),
            entry("c", .audio, size: 50),
            entry("d", .documents, size: 60),
            entry("e", .documents, size: 30),
        ]
        let groups = makeGroups(all: all, filtered: all, marked: [], current: nil)
        XCTAssertEqual(groups.map(\.item), [
            .all, .category(.videos), .category(.documents), .category(.audio), .category(.images),
        ])
        XCTAssertEqual(groups[0], CategoryGroup(item: .all, count: 5, size: 290, marked: 0))
        XCTAssertEqual(groups[2], CategoryGroup(item: .category(.documents), count: 2, size: 90, marked: 0))
    }

    func testGroupMarkedCountsUseAllEntries() {
        let all = [
            entry("a", .videos, size: 100),
            entry("b", .videos, size: 10),
            entry("c", .images, size: 50),
        ]
        let filtered = [all[0], all[2]]
        let marked: Set<String> = [all[1].path, all[2].path, "/gone/path"]
        let groups = makeGroups(all: all, filtered: filtered, marked: marked, current: nil)
        XCTAssertEqual(groups, [
            CategoryGroup(item: .all, count: 2, size: 150, marked: 2),
            CategoryGroup(item: .category(.videos), count: 1, size: 100, marked: 1),
            CategoryGroup(item: .category(.images), count: 1, size: 50, marked: 1),
        ])
    }

    func testCurrentCategoryWithNoFilteredFilesStaysAsZeroGroup() {
        let all = [
            entry("a", .videos, size: 100),
            entry("b", .images, size: 50),
            entry("c", .audio, size: 0),
        ]
        let filtered = [all[0], all[2]]
        let groups = makeGroups(all: all, filtered: filtered, marked: [all[1].path], current: .category(.images))
        XCTAssertEqual(groups, [
            CategoryGroup(item: .all, count: 2, size: 100, marked: 1),
            CategoryGroup(item: .category(.videos), count: 1, size: 100, marked: 0),
            CategoryGroup(item: .category(.audio), count: 1, size: 0, marked: 0),
            CategoryGroup(item: .category(.images), count: 0, size: 0, marked: 1),
        ])
    }

    func testCurrentCategoryAbsentFromAllIsNotAdded() {
        let all = [entry("a", .videos, size: 100)]
        let groups = makeGroups(all: all, filtered: all, marked: [], current: .category(.images))
        XCTAssertEqual(groups.map(\.item), [.all, .category(.videos)])
    }

    func testResolveNilPicksLargestCategory() {
        let all = [entry("a", .images, size: 10), entry("b", .videos, size: 100)]
        let groups = makeGroups(all: all, filtered: all, marked: [], current: nil)
        XCTAssertEqual(resolveSelection(nil, all: all, groups: groups), .category(.videos))
    }

    func testResolveKeepsCategoryStillInAll() {
        let all = [entry("a", .images, size: 10), entry("b", .videos, size: 100)]
        let groups = makeGroups(all: all, filtered: [all[1]], marked: [], current: .category(.images))
        XCTAssertEqual(resolveSelection(.category(.images), all: all, groups: groups), .category(.images))
    }

    func testResolveGoneCategoryFallsBackToLargest() {
        let all = [entry("a", .images, size: 10), entry("b", .videos, size: 100)]
        let groups = makeGroups(all: all, filtered: all, marked: [], current: .category(.audio))
        XCTAssertEqual(resolveSelection(.category(.audio), all: all, groups: groups), .category(.videos))
    }

    func testResolveWithNoEntriesGivesAll() {
        let groups = makeGroups(all: [], filtered: [], marked: [], current: nil)
        XCTAssertEqual(groups, [CategoryGroup(item: .all, count: 0, size: 0, marked: 0)])
        XCTAssertEqual(resolveSelection(nil, all: [], groups: groups), .all)
        XCTAssertEqual(resolveSelection(.category(.videos), all: [], groups: groups), .all)
    }

    func testResolveAllStaysAll() {
        let all = [entry("a", .videos, size: 100)]
        let groups = makeGroups(all: all, filtered: all, marked: [], current: .all)
        XCTAssertEqual(resolveSelection(.all, all: all, groups: groups), .all)
    }

    func testEntriesInItem() {
        XCTAssertEqual(entries(sample, in: .all), sample)
        XCTAssertEqual(names(entries(sample, in: .category(.documents))), ["Report.pdf", "notes.txt"])
    }
}

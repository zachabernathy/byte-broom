import XCTest
import ByteBroomCore

final class SortKeyTests: XCTestCase {
    private func sorted(_ names: [String]) -> [String] {
        names.sorted { sortKey($0).lexicographicallyPrecedes(sortKey($1)) }
    }

    func testDigitRunsCompareByNumericValueIgnoringLeadingZeros() {
        XCTAssertEqual(sorted(["file10", "file2", "file01"]), ["file01", "file2", "file10"])
        XCTAssertEqual(sorted(["1", "00", "0"]), ["0", "00", "1"])
        XCTAssertEqual(sorted(["v1.010", "v1.9", "v1.0002"]), ["v1.0002", "v1.9", "v1.010"])
    }

    func testEqualValuesWithDifferentPaddingHaveATotalOrder() {
        XCTAssertNotEqual(sortKey("file1"), sortKey("file01"))
        XCTAssertEqual(sorted(["file1", "file01"]), sorted(["file01", "file1"]))
        XCTAssertNotEqual(sortKey("File"), sortKey("file"))
        XCTAssertEqual(sorted(["file1", "file01", "file2"]).last, "file2")
    }

    func testCaseAndDiacriticsAreIgnoredForOrder() {
        XCTAssertEqual(sorted(["b", "Á", "a"]), ["a", "Á", "b"])
        XCTAssertEqual(sorted(["éb", "Ea"]), ["Ea", "éb"])
    }

    func testDecomposedAndPrecomposedNamesSortTogether() {
        let decomposed = "Cafe\u{301} 2"
        XCTAssertEqual(sorted(["Café 10", decomposed]), [decomposed, "Café 10"])
        XCTAssertEqual(sorted(["Café 1b", "Cafe\u{301} 1a"]), ["Cafe\u{301} 1a", "Café 1b"])
    }
}

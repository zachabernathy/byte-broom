import XCTest
import ByteBroomCore

final class CategoriesTests: XCTestCase {
    private let bundleSuffixes = [
        "app", "photoslibrary", "musiclibrary", "fcpbundle", "imovielibrary",
        "logicx", "band", "pages", "numbers", "key", "rtfd",
    ]

    func testCategoryByExtension() {
        XCTAssertEqual(category(forName: "report.PDF"), .documents)
        XCTAssertEqual(category(forName: "clip.mov"), .videos)
        XCTAssertEqual(category(forName: "Setup.dmg"), .installers)
        XCTAssertEqual(category(forName: "a.tar.gz"), .archives)
        XCTAssertEqual(category(forName: "Photos Library.photoslibrary"), .images)
        XCTAssertEqual(category(forName: "Foo.app"), .apps)
    }

    func testNamesWithoutExtensionAreOther() {
        XCTAssertEqual(category(forName: "noext"), .other)
        XCTAssertEqual(category(forName: ".zshrc"), .other)
        XCTAssertEqual(category(forName: "foo."), .other)
    }

    func testIsBundle() {
        for suffix in bundleSuffixes {
            XCTAssertTrue(isBundle(name: "Thing.\(suffix)"), suffix)
        }
        XCTAssertFalse(isBundle(name: "notes.txt"))
        XCTAssertFalse(isBundle(name: ".app"))
    }

    func testEveryBundleSuffixHasACategory() {
        for suffix in bundleSuffixes {
            XCTAssertNotEqual(category(forName: "Thing.\(suffix)"), .other, suffix)
        }
    }
}

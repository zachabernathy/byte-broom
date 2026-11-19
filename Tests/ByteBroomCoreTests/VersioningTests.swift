import XCTest
@testable import ByteBroomCore

final class VersioningTests: XCTestCase {
    func testParses() {
        XCTAssertEqual(SemVer("1.2.3")?.description, "1.2.3")
        XCTAssertEqual(SemVer("v1.2.3")?.description, "1.2.3")
        XCTAssertEqual(SemVer(" 1.2.3-beta.1 ")?.description, "1.2.3-beta.1")
        XCTAssertEqual(SemVer("1.2.3+build.5")?.description, "1.2.3")
    }
    func testRejectsMalformed() {
        for s in ["", "1", "1.2", "1.2.3.4", "a.b.c", "1..3", "-1.2.3", "1.2.x", "v", "1.2.3-"] {
            XCTAssertNil(SemVer(s), s)
        }
    }
    func testOrdering() {
        XCTAssertLessThan(SemVer("1.2.3")!, SemVer("1.2.4")!)
        XCTAssertLessThan(SemVer("1.2.9")!, SemVer("1.10.0")!)
        XCTAssertLessThan(SemVer("1.9.9")!, SemVer("2.0.0")!)
        XCTAssertLessThan(SemVer("1.0.0-beta")!, SemVer("1.0.0")!)
        XCTAssertFalse(SemVer("1.0.0")! < SemVer("1.0.0")!)
    }
    func testUpdateStatus() {
        XCTAssertEqual(updateStatus(current: "1.0.0", latestTag: "v1.0.0"), .upToDate)
        XCTAssertEqual(updateStatus(current: "1.0.0", latestTag: "v1.1.0"), .available(SemVer("1.1.0")!))
        XCTAssertEqual(updateStatus(current: "1.2.0", latestTag: "v1.1.0"), .upToDate)
        XCTAssertEqual(updateStatus(current: "1.0.0-dev", latestTag: "v1.0.0"), .upToDate)
        XCTAssertEqual(updateStatus(current: "0.0.0-dev", latestTag: "v1.0.0"), .available(SemVer("1.0.0")!))
        XCTAssertEqual(updateStatus(current: "garbage", latestTag: "v1.0.0"), .unknown)
        XCTAssertEqual(updateStatus(current: "1.0.0", latestTag: "nightly"), .unknown)
    }
    func testValidatedReleaseURL() {
        let good = "https://github.com/zachabernathy/byte-broom/releases/tag/v1.1.0"
        XCTAssertEqual(validatedReleaseURL(good).absoluteString, good)
        for bad in [nil, "", "http://github.com/zachabernathy/byte-broom/releases/tag/v1",
                    "https://evil.com/zachabernathy/byte-broom/releases/tag/v1",
                    "https://github.com.evil.com/zachabernathy/byte-broom/releases/",
                    "https://github.com/someone/byte-broom/releases/tag/v1",
                    "https://github.com/zachabernathy/byte-broom-evil/releases/tag/v1",
                    "javascript:alert(1)",
                    "https://evil.com\\@github.com/zachabernathy/byte-broom/releases/x",
                    "https://user@github.com/zachabernathy/byte-broom/releases/x"] {
            XCTAssertEqual(validatedReleaseURL(bad), releasesPageURL, bad ?? "nil")
        }
    }

    func testRejectsEdgeCases() {
        let overflow = "\(Int.max)0"
        for s in ["01.2.3", "1.02.3", "1.2.03", "+1.2.3", "1.+2.3", "1.2.-3",
                  "1.2.3 beta", "1 .2.3", "1.2.3-be ta", "\u{0661}.2.3", "1.\u{FF12}.3",
                  "\(overflow).0.0", "1.2.3-beta..1", "1.2.3+", "1.2.3+a..b", "1.2.3-beta_1",
                  "vv1.2.3", "V1.2.3"] {
            XCTAssertNil(SemVer(s), s)
        }
    }
    func testAcceptsBoundaries() {
        XCTAssertEqual(SemVer("0.0.0")?.description, "0.0.0")
        XCTAssertEqual(SemVer("\(Int.max).0.0")?.major, Int.max)
        XCTAssertEqual(SemVer("1.2.3-rc.1+exp.sha.5114f85")?.description, "1.2.3-rc.1")
        XCTAssertEqual(SemVer("1.2.3+b"), SemVer("1.2.3"))
    }
    func testPrereleaseOrdering() {
        XCTAssertLessThan(SemVer("1.0.0-alpha")!, SemVer("1.0.0-beta")!)
        XCTAssertLessThan(SemVer("1.0.0-rc")!, SemVer("1.0.1-alpha")!)
        XCTAssertLessThan(SemVer("1.0.0-beta.10")!, SemVer("1.0.0-beta.2")!)
        XCTAssertEqual(updateStatus(current: "1.0.0", latestTag: "v1.0.0-beta"), .upToDate)
    }
    func testRejectsTrickyReleaseURLs() {
        for bad in ["https://user:pw@github.com/zachabernathy/byte-broom/releases/tag/v1",
                    "https://github.com:8443/zachabernathy/byte-broom/releases/tag/v1",
                    "https://github.com/zachabernathy/byte-broom/releases",
                    "https://github.com/zachabernathy/byte-broom/releases/../../../evil",
                    "https://github.com/zachabernathy/byte-broom/releases/%2e%2e/%2e%2e/x"] {
            XCTAssertEqual(validatedReleaseURL(bad), releasesPageURL, bad)
        }
    }
}

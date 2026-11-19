import Foundation

/// A `major.minor.patch[-prerelease][+build]` version.
///
/// Parsing rules:
/// - Leading and trailing whitespace is trimmed. One optional lowercase `v` prefix is allowed.
/// - Exactly three numeric components. Each is ASCII `0`-`9` only (no sign, no Unicode digits),
///   fits in `Int`, and has no leading zeros (`0` is fine, `01` is rejected), as in SemVer 2.0.
/// - Prerelease and build metadata are dot-separated, non-empty identifiers of ASCII letters,
///   digits, and `-`. Build metadata is validated, then dropped: it does not affect
///   `description`, equality, or ordering.
/// - Two prereleases compare as plain strings, so `beta.10` sorts before `beta.2`.
public struct SemVer: Comparable, Sendable, CustomStringConvertible {
    public let major: Int, minor: Int, patch: Int
    public let prerelease: String?

    public init?(_ string: String) {
        var rest = Substring(string.trimmingCharacters(in: .whitespacesAndNewlines))
        if rest.hasPrefix("v") { rest = rest.dropFirst() }

        if let plus = rest.firstIndex(of: "+") {
            guard Self.isValidIdentifiers(rest[rest.index(after: plus)...]) else { return nil }
            rest = rest[..<plus]
        }
        var pre: Substring?
        if let dash = rest.firstIndex(of: "-") {
            pre = rest[rest.index(after: dash)...]
            guard Self.isValidIdentifiers(pre!) else { return nil }
            rest = rest[..<dash]
        }

        let parts = rest.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3 else { return nil }
        var numbers: [Int] = []
        for part in parts {
            guard !part.isEmpty, part.utf8.allSatisfy({ $0 >= 0x30 && $0 <= 0x39 }),
                  part == "0" || !part.hasPrefix("0"),
                  let n = Int(part) else { return nil }
            numbers.append(n)
        }
        (major, minor, patch) = (numbers[0], numbers[1], numbers[2])
        prerelease = pre.map(String.init)
    }

    public var description: String {
        "\(major).\(minor).\(patch)" + (prerelease.map { "-\($0)" } ?? "")
    }

    var release: (Int, Int, Int) { (major, minor, patch) }

    public static func < (a: SemVer, b: SemVer) -> Bool {
        if a.release != b.release { return a.release < b.release }
        switch (a.prerelease, b.prerelease) {
        case let (x?, y?): return x < y
        case (_?, nil): return true
        default: return false
        }
    }

    private static func isValidIdentifiers(_ s: Substring) -> Bool {
        let ids = s.split(separator: ".", omittingEmptySubsequences: false)
        return ids.allSatisfy { id in
            !id.isEmpty && id.utf8.allSatisfy { c in
                (c >= 0x30 && c <= 0x39) || (c >= 0x41 && c <= 0x5A) || (c >= 0x61 && c <= 0x7A) || c == 0x2D
            }
        }
    }
}

public enum UpdateStatus: Equatable, Sendable { case upToDate, available(SemVer), unknown }

/// `.available(latest)` only when the latest tag's `major.minor.patch` is higher than the
/// current one. Prerelease tags are ignored in this comparison, so a `1.0.0-dev` build counts
/// as `1.0.0`. `.unknown` when either string fails to parse.
public func updateStatus(current: String, latestTag: String) -> UpdateStatus {
    guard let cur = SemVer(current), let latest = SemVer(latestTag) else { return .unknown }
    return latest.release > cur.release ? .available(latest) : .upToDate
}

public let releasesPageURL = URL(string: "https://github.com/zachabernathy/byte-broom/releases")!

/// Returns the URL only if it is an `https://github.com` link (no user, password, or port)
/// under `/zachabernathy/byte-broom/releases/` with no `..` path segments; otherwise
/// `releasesPageURL`. Raw input containing `\`, `@`, whitespace, or control characters is
/// rejected before parsing, because browsers and Foundation can disagree on the host.
public func validatedReleaseURL(_ string: String?) -> URL {
    let unsafe = CharacterSet(charactersIn: "\\@").union(.whitespacesAndNewlines).union(.controlCharacters)
    guard let string, string.rangeOfCharacter(from: unsafe) == nil,
          let c = URLComponents(string: string),
          c.scheme == "https", c.host == "github.com",
          c.user == nil, c.password == nil, c.port == nil,
          c.path.hasPrefix("/zachabernathy/byte-broom/releases/"),
          !c.path.split(separator: "/").contains(".."),
          let url = c.url else { return releasesPageURL }
    return url
}

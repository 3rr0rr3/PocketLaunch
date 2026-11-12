import Foundation

enum NXTitleIdentity {
    static func titleID(from launchURL: String) -> String? {
        guard let scheme = URL(string: launchURL)?.scheme?.lowercased() else { return nil }
        let pattern = #"^(?:sidestore-|altstore-)?org\.nxnative\.([0-9a-f]{16})(?:\.[a-z0-9-]+)?$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: scheme, range: NSRange(scheme.startIndex..., in: scheme)),
              let range = Range(match.range(at: 1), in: scheme) else { return nil }
        return String(scheme[range]).uppercased()
    }

    static func trustedIconURL(_ text: String) -> URL? {
        guard let url = URL(string: text), url.scheme == "https",
              url.host?.lowercased() == "img-eshop.cdn.nintendo.net",
              url.user == nil, url.password == nil, url.port == nil else { return nil }
        return url
    }
}

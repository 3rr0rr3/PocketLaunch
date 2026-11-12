import Foundation
import ZIPFoundation

struct IPAIconMetadata {
    let name: String
    let bundleIdentifier: String
    let schemes: [String]
    let icons: [Data]

    func matches(launchURL: String) -> Bool {
        guard let scheme = URL(string: launchURL)?.scheme?.lowercased() else { return false }
        if schemes.contains(where: { $0.lowercased() == scheme }) { return true }
        let bundle = bundleIdentifier.lowercased()
        guard !bundle.isEmpty else { return false }
        for prefix in ["sidestore-", "altstore-"] where scheme.hasPrefix(prefix) {
            let target = String(scheme.dropFirst(prefix.count))
            if target == bundle || target.hasPrefix(bundle + ".") { return true }
        }
        return false
    }
}

enum IPAIconError: LocalizedError {
    case invalidApp, tooLarge, noIcon
    var errorDescription: String? {
        switch self {
        case .invalidApp: return "This IPA does not contain one valid app in Payload."
        case .tooLarge: return "The IPA's icon metadata exceeds the supported size."
        case .noIcon: return "No readable icon image was found. This IPA may store its icon only in an asset catalog. You can still choose artwork from Photos."
        }
    }
}

/// Reads only the app's plist and small icon files, never the game payload.
enum IPAIconReader {
    static func read(_ url: URL) throws -> IPAIconMetadata {
        let archive = try Archive(url: url, accessMode: .read)
        var infoEntries: [Entry] = []
        var rootPNGs: [Entry] = []
        var count = 0
        for entry in archive {
            count += 1
            guard count <= 250_000 else { throw IPAIconError.tooLarge }
            guard entry.type == .file else { continue }
            let parts = entry.path.split(separator: "/", omittingEmptySubsequences: false)
            guard parts.count == 3, parts[0] == "Payload", parts[1].hasSuffix(".app") else { continue }
            if parts[2] == "Info.plist" { infoEntries.append(entry) }
            if parts[2].lowercased().hasSuffix(".png") { rootPNGs.append(entry) }
        }
        guard infoEntries.count == 1, let infoEntry = infoEntries.first else { throw IPAIconError.invalidApp }
        let data = try read(infoEntry, from: archive, limit: 2 * 1024 * 1024)
        guard let info = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let identifier = info["CFBundleIdentifier"] as? String, !identifier.isEmpty else {
            throw IPAIconError.invalidApp
        }
        let folder = String(infoEntry.path.dropLast("Info.plist".count))
        let names = declaredIconNames(info)
        let pngs = rootPNGs.filter { $0.path.hasPrefix(folder) }
        let declared = pngs.filter { entry in
            let stem = iconStem(entry.path)
            return names.contains { name in
                stem == name || stem.hasPrefix(name + "@") || stem.hasPrefix(name + "~")
            }
        }
        let fallback = pngs.filter {
            let stem = iconStem($0.path)
            return stem.hasPrefix("appicon") || stem.hasPrefix("icon")
        }
        let candidates = (declared.isEmpty ? fallback : declared)
            .filter { $0.uncompressedSize > 0 && $0.uncompressedSize <= 8 * 1024 * 1024 }
            .sorted { $0.uncompressedSize > $1.uncompressedSize }
        var icons: [Data] = []
        var budget = 32 * 1024 * 1024
        for entry in candidates.prefix(24) {
            let size = Int(entry.uncompressedSize)
            guard size <= budget else { continue }
            if let icon = try? read(entry, from: archive, limit: 8 * 1024 * 1024) {
                icons.append(icon)
                budget -= icon.count
            }
        }
        let urlTypes = info["CFBundleURLTypes"] as? [[String: Any]] ?? []
        let schemes = urlTypes.flatMap { $0["CFBundleURLSchemes"] as? [String] ?? [] }
        return IPAIconMetadata(
            name: info["CFBundleDisplayName"] as? String ?? info["CFBundleName"] as? String ?? identifier,
            bundleIdentifier: identifier, schemes: schemes, icons: icons
        )
    }

    static func declaredIconNames(_ info: [String: Any]) -> [String] {
        var names = info["CFBundleIconFiles"] as? [String] ?? []
        if let name = info["CFBundleIconFile"] as? String { names.append(name) }
        for key in ["CFBundleIcons", "CFBundleIcons~ipad"] {
            let dictionary = info[key] as? [String: Any]
            let primary = dictionary?["CFBundlePrimaryIcon"] as? [String: Any]
            names += primary?["CFBundleIconFiles"] as? [String] ?? []
        }
        return names.map(iconStem)
    }

    private static func iconStem(_ path: String) -> String {
        let name = (path as NSString).lastPathComponent
        return (name.lowercased().hasSuffix(".png") ? (name as NSString).deletingPathExtension : name).lowercased()
    }

    private static func read(_ entry: Entry, from archive: Archive, limit: Int) throws -> Data {
        guard entry.uncompressedSize <= UInt64(limit) else { throw IPAIconError.tooLarge }
        var result = Data()
        let checksum = try archive.extract(entry) { chunk in
            guard chunk.count <= limit - result.count else { throw IPAIconError.tooLarge }
            result.append(chunk)
        }
        guard checksum == entry.checksum else { throw Archive.ArchiveError.invalidCRC32 }
        return result
    }
}

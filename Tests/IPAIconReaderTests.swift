import XCTest
import ZIPFoundation
@testable import PocketLaunchImport

final class IPAIconReaderTests: XCTestCase {
    private func fixture(_ entries: [(String, Data)]) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".ipa")
        let archive = try Archive(url: url, accessMode: .create)
        for (path, data) in entries {
            try archive.addEntry(with: path, type: .file, uncompressedSize: Int64(data.count), compressionMethod: .deflate) { offset, size in
                data.subdata(in: Int(offset)..<min(data.count, Int(offset) + size))
            }
        }
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    private func plist(_ extra: [String: Any] = [:], format: PropertyListSerialization.PropertyListFormat = .binary) throws -> Data {
        var info: [String: Any] = [
            "CFBundleIdentifier": "org.nxnative.010095300b6a4000",
            "CFBundleDisplayName": "South Park",
            "CFBundleIcons": ["CFBundlePrimaryIcon": ["CFBundleIconFiles": ["GameIcon60x60"]]],
            "CFBundleURLTypes": [["CFBundleURLSchemes": ["custom-game"]]]
        ]
        info.merge(extra) { _, new in new }
        return try PropertyListSerialization.data(fromPropertyList: info, format: format, options: 0)
    }

    func testBinaryPlistReadsDeclaredRetinaIconAndExcludesOtherAssets() throws {
        let wanted = Data([1, 2, 3, 4])
        let url = try fixture([
            ("Payload/Game.app/Info.plist", try plist()),
            ("Payload/Game.app/GameIcon60x60@3x.png", wanted),
            ("Payload/Game.app/AppIconAlternate.png", Data(repeating: 5, count: 40)),
            ("Payload/Game.app/PlugIns/Widget.appex/Icon.png", Data([8])),
            ("Payload/Game.app/images/GameIcon60x60.png", Data([9]))
        ])
        let metadata = try IPAIconReader.read(url)
        XCTAssertEqual(metadata.name, "South Park")
        XCTAssertEqual(metadata.icons, [wanted])
        XCTAssertEqual(metadata.bundleIdentifier, "org.nxnative.010095300b6a4000")
        XCTAssertTrue(metadata.matches(launchURL: "sidestore-org.nxnative.010095300b6a4000.5V7XAX44YG://"))
        XCTAssertTrue(metadata.matches(launchURL: "custom-game://"))
        XCTAssertFalse(metadata.matches(launchURL: "sidestore-org.nxnative.010095300b6a40001.5V7XAX44YG://"))
        XCTAssertFalse(metadata.matches(launchURL: "https://example.com"))
    }

    func testXMLLegacyIconsAndCaseInsensitiveExtensions() throws {
        let info = try plist(["CFBundleIcons": [:], "CFBundleIconFile": "Icon.png"], format: .xml)
        let url = try fixture([("Payload/Game.app/Info.plist", info), ("Payload/Game.app/Icon@2x.PNG", Data([3]))])
        XCTAssertEqual(try IPAIconReader.read(url).icons, [Data([3])])
    }

    func testFallbackIconsDoNotChooseAnUnrelatedScreenshot() throws {
        let url = try fixture([
            ("Payload/Game.app/Info.plist", try plist(["CFBundleIcons": [:]])),
            ("Payload/Game.app/AppIcon120.png", Data([4])),
            ("Payload/Game.app/Screenshot.png", Data(repeating: 9, count: 100))
        ])
        XCTAssertEqual(try IPAIconReader.read(url).icons, [Data([4])])
    }

    func testAssetCatalogOnlyReturnsNoIconWithoutFailingMetadata() throws {
        let url = try fixture([("Payload/Game.app/Info.plist", try plist()), ("Payload/Game.app/Assets.car", Data([0]))])
        XCTAssertTrue(try IPAIconReader.read(url).icons.isEmpty)
    }

    func testRejectsMalformedAndAmbiguousApps() throws {
        let bad = try fixture([("Payload/Game.app/Info.plist", Data([0, 1]))])
        XCTAssertThrowsError(try IPAIconReader.read(bad))
        let ambiguous = try fixture([
            ("Payload/One.app/Info.plist", try plist()),
            ("Payload/Two.app/Info.plist", try plist())
        ])
        XCTAssertThrowsError(try IPAIconReader.read(ambiguous))
    }

    func testLimitsLargeIconsAndPlist() throws {
        let url = try fixture([
            ("Payload/Game.app/Info.plist", try plist()),
            ("Payload/Game.app/GameIcon60x60.png", Data(repeating: 0, count: 8 * 1024 * 1024 + 1))
        ])
        XCTAssertTrue(try IPAIconReader.read(url).icons.isEmpty)
        let hugePlist = try fixture([("Payload/Game.app/Info.plist", Data(repeating: 0, count: 2 * 1024 * 1024 + 1))])
        XCTAssertThrowsError(try IPAIconReader.read(hugePlist))
    }
}

import XCTest
import ImageIO
@testable import PocketLaunchImport

final class AutomaticArtworkIdentityTests: XCTestCase {
    func testExtractsExactNXTitleIDFromSignedLaunchLink() {
        XCTAssertEqual(NXTitleIdentity.titleID(from: "sidestore-org.nxnative.010095300b6a4000.5V7XAX44YG://"), "010095300B6A4000")
        XCTAssertEqual(NXTitleIdentity.titleID(from: "altstore-org.nxnative.0400a3a01ee4c000.TEAM123://"), "0400A3A01EE4C000")
        XCTAssertEqual(NXTitleIdentity.titleID(from: "org.nxnative.010095300b6a4000://"), "010095300B6A4000")
    }
    func testDoesNotGuessFromNamesOrUnrelatedLinks() {
        XCTAssertNil(NXTitleIdentity.titleID(from: "https://example.com/010095300B6A4000"))
        XCTAssertNil(NXTitleIdentity.titleID(from: "sidestore-org.nxnative.010095300B6A40001.TEAM://"))
        XCTAssertNil(NXTitleIdentity.titleID(from: "sidestore-org.other.010095300B6A4000.TEAM://"))
        XCTAssertNil(NXTitleIdentity.titleID(from: "South Park"))
    }
    func testBundledSouthParkArtworkActuallyDecodes() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let folder = root.appendingPathComponent("Resources/AutomaticArtwork")
        let index = try JSONDecoder().decode([String: String].self, from: Data(contentsOf: folder.appendingPathComponent("artwork-index.json")))
        XCTAssertNotNil(index["010095300B6A4000"])
        let url = folder.appendingPathComponent("010095300B6A4000.jpg")
        let source = try XCTUnwrap(CGImageSourceCreateWithURL(url as CFURL, nil))
        let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
        XCTAssertGreaterThan(image.width, 32)
        XCTAssertGreaterThan(image.height, 32)
    }
    func testArtworkDownloadHostsAreRestricted() {
        XCTAssertNotNil(NXTitleIdentity.trustedIconURL("https://img-eshop.cdn.nintendo.net/i/icon.jpg"))
        XCTAssertNil(NXTitleIdentity.trustedIconURL("http://img-eshop.cdn.nintendo.net/i/icon.jpg"))
        XCTAssertNil(NXTitleIdentity.trustedIconURL("https://img-eshop.cdn.nintendo.net.example.com/i/icon.jpg"))
        XCTAssertNil(NXTitleIdentity.trustedIconURL("https://user@img-eshop.cdn.nintendo.net/i/icon.jpg"))
    }
}

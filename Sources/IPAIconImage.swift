import Foundation
import UIKit
import ImageIO

enum IPAIconImage {
    static func artwork(from metadata: IPAIconMetadata) throws -> Data {
        var best: UIImage?
        var bestArea: CGFloat = 0
        for data in metadata.icons {
            guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                  let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceThumbnailMaxPixelSize: 1000,
                    kCGImageSourceCreateThumbnailWithTransform: true
                  ] as CFDictionary) else { continue }
            let area = CGFloat(thumbnail.width) * CGFloat(thumbnail.height)
            if area > bestArea { best = UIImage(cgImage: thumbnail); bestArea = area }
        }
        guard let png = best?.pngData() else { throw IPAIconError.noIcon }
        return png
    }

    static func read(_ url: URL) async throws -> Data {
        try await Task.detached(priority: .userInitiated) {
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            var result: Result<Data, Error>?
            var coordinationError: NSError?
            NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinationError) { readable in
                result = Result { try artwork(from: IPAIconReader.read(readable)) }
            }
            if let coordinationError { throw coordinationError }
            guard let result else { throw IPAIconError.invalidApp }
            return try result.get()
        }.value
    }
}

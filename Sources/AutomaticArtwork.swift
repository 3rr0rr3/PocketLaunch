import Foundation
import UIKit
import ImageIO

enum AutomaticArtworkError: LocalizedError {
    case unsupported, unavailable
    var errorDescription: String? {
        switch self {
        case .unsupported: return "Import this game’s IPA to detect its icon."
        case .unavailable: return "Artwork unavailable. Long-press to retry."
        }
    }
}

actor AutomaticArtwork {
    static let shared = AutomaticArtwork()
    private var catalogue: [String: String]?
    private var cached: [String: Data] = [:]

    func artwork(launchURL: String, localFiles: [URL]) async throws -> Data {
        if let data = cached[launchURL] { return data }
        // The user has already granted access to these imported files.
        let local = try await Task.detached(priority: .utility) {
            for file in localFiles {
                try Task.checkCancellation()
                if let metadata = try? IPAIconReader.read(file),
                   metadata.matches(launchURL: launchURL),
                   let artwork = try? IPAIconImage.artwork(from: metadata) { return artwork }
            }
            return Optional<Data>.none
        }.value
        try Task.checkCancellation()
        if let local { cached[launchURL] = local; return local }

        guard let title = NXTitleIdentity.titleID(from: launchURL) else { throw AutomaticArtworkError.unsupported }
        if let bundled = Bundle.main.url(forResource: title, withExtension: "jpg"),
           let data = try? Data(contentsOf: bundled), let normalized = Self.normalized(data) {
            cached[launchURL] = normalized
            return normalized
        }
        if catalogue == nil, let url = Bundle.main.url(forResource: "artwork-index", withExtension: "json") {
            catalogue = try JSONDecoder().decode([String: String].self, from: Data(contentsOf: url))
        }
        guard let value = catalogue?[title], let url = NXTitleIdentity.trustedIconURL(value) else {
            throw AutomaticArtworkError.unavailable
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 18
        let (data, response) = try await URLSession.shared.data(for: request)
        try Task.checkCancellation()
        guard let http = response as? HTTPURLResponse, http.statusCode == 200,
              data.count <= 8 * 1024 * 1024,
              let normalized = Self.normalized(data) else { throw AutomaticArtworkError.unavailable }
        cached[launchURL] = normalized
        return normalized
    }

    private static func normalized(_ data: Data) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: 768,
                kCGImageSourceCreateThumbnailWithTransform: true
              ] as CFDictionary) else { return nil }
        return UIImage(cgImage: image).pngData()
    }
}

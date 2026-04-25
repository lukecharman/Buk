import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// A single audiobook stored in the user's local library.
///
/// Audio data lives on disk under `LibraryStore.audioFolder`, addressed by `fileName`.
/// Artwork lives on disk under `LibraryStore.artworkFolder` if `artworkFileName` is set.
struct Audiobook: Identifiable, Codable, Hashable {
    struct Chapter: Identifiable, Codable, Hashable {
        let id: UUID
        let title: String
        let startTime: TimeInterval
        let duration: TimeInterval

        var endTime: TimeInterval { startTime + duration }
    }

    let id: UUID
    var title: String
    var author: String?
    var narrator: String?
    /// File name (not full path) of the audio file inside the library folder.
    var fileName: String
    /// File name (not full path) of the cached artwork inside the artwork folder.
    var artworkFileName: String?
    /// Total duration of the audio in seconds.
    var duration: TimeInterval
    /// Source of the book — used for attribution and re-download behaviour.
    var source: Source
    /// Date the book was added to the library.
    var dateAdded: Date
    var chapters: [Chapter]

    enum Source: String, Codable, Hashable {
        case importedFile
        case librivox
        case internetArchive
        case bundled
    }
}

extension Audiobook {
    /// Returns the artwork as a SwiftUI `Image` if the cached file exists and decodes.
    /// Decoded `UIImage`/`NSImage` instances are cached per artwork filename so the
    /// row and detail screens share the same backing image — without this, the
    /// matched-geometry morph re-decodes from disk and produces a brief flicker
    /// as the destination's freshly-decoded copy swaps in.
    func artworkImage(in folder: URL) -> Image? {
        guard let artworkFileName else { return nil }
        let key = artworkFileName as NSString
        #if canImport(UIKit)
        if let cached = ArtworkCache.shared.object(forKey: key) {
            return Image(uiImage: cached)
        }
        guard
            let data = try? Data(contentsOf: folder.appendingPathComponent(artworkFileName)),
            let uiImage = UIImage(data: data)
        else { return nil }
        ArtworkCache.shared.setObject(uiImage, forKey: key)
        return Image(uiImage: uiImage)
        #elseif canImport(AppKit)
        if let cached = ArtworkCache.shared.object(forKey: key) {
            return Image(nsImage: cached)
        }
        guard
            let data = try? Data(contentsOf: folder.appendingPathComponent(artworkFileName)),
            let nsImage = NSImage(data: data)
        else { return nil }
        ArtworkCache.shared.setObject(nsImage, forKey: key)
        return Image(nsImage: nsImage)
        #else
        return nil
        #endif
    }

    /// Looks up the chapter index that contains `time` (seconds from the start of the book).
    func chapterIndex(containing time: TimeInterval) -> Int {
        guard !chapters.isEmpty else { return 0 }
        if let index = chapters.lastIndex(where: { time >= $0.startTime }) { return index }
        return 0
    }
}

/// In-process cache for decoded artwork images, keyed by filename. Shared by
/// the library row and detail screen so the matched-geometry morph hands off
/// the same image instance instead of re-decoding from disk.
#if canImport(UIKit)
final class ArtworkCache {
    static let shared = NSCache<NSString, UIImage>()
    private init() {}
}
#elseif canImport(AppKit)
final class ArtworkCache {
    static let shared = NSCache<NSString, NSImage>()
    private init() {}
}
#endif

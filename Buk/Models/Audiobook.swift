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
    func artworkImage(in folder: URL) -> Image? {
        guard
            let artworkFileName,
            let data = try? Data(contentsOf: folder.appendingPathComponent(artworkFileName))
        else { return nil }
        #if canImport(UIKit)
        guard let uiImage = UIImage(data: data) else { return nil }
        return Image(uiImage: uiImage)
        #elseif canImport(AppKit)
        guard let nsImage = NSImage(data: data) else { return nil }
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

import Foundation

/// Centralised on-disk locations used by the app. All folders are guaranteed to exist.
enum LibraryPaths {
    /// Root folder for everything the app stores on disk for itself.
    static let root: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("Buk", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    /// Audio files (`.m4b`, `.mp3`, …) keyed by `Audiobook.fileName`.
    static let audioFolder: URL = {
        let dir = root.appendingPathComponent("Audio", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    /// Cover artwork keyed by `Audiobook.artworkFileName`.
    static let artworkFolder: URL = {
        let dir = root.appendingPathComponent("Artwork", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    /// JSON snapshot of the library.
    static let libraryFile = root.appendingPathComponent("library.json", isDirectory: false)

    /// JSON snapshot of progress, keyed by book id.
    static let progressFile = root.appendingPathComponent("progress.json", isDirectory: false)
}

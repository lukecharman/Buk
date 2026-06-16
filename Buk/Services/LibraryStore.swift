import Foundation

/// On-disk persistence for the library snapshot and book artwork / audio files.
///
/// Stores the library as a single JSON file under `LibraryPaths.libraryFile`. Atomically
/// replaces it on every save to avoid corruption on background termination. All file IO
/// happens off the main actor.
actor LibraryStore {
    private let fileURL: URL
    private let audioFolder: URL
    private let artworkFolder: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(fileURL: URL = LibraryPaths.libraryFile,
         audioFolder: URL = LibraryPaths.audioFolder,
         artworkFolder: URL = LibraryPaths.artworkFolder) {
        self.fileURL = fileURL
        self.audioFolder = audioFolder
        self.artworkFolder = artworkFolder
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        enc.dateEncodingStrategy = .iso8601
        self.encoder = enc
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        self.decoder = dec
    }

    func load() throws -> [Audiobook] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        let data = try Data(contentsOf: fileURL)
        return try decoder.decode([Audiobook].self, from: data)
    }

    func save(_ books: [Audiobook]) throws {
        let data = try encoder.encode(books)
        try data.write(to: fileURL, options: [.atomic])
    }

    /// Removes all files belonging to a book from disk. Safe to call for a book that
    /// no longer exists.
    func deleteFiles(for book: Audiobook) {
        for name in book.allFileNames {
            try? FileManager.default.removeItem(at: audioFolder.appendingPathComponent(name))
        }
        if let art = book.artworkFileName {
            try? FileManager.default.removeItem(at: artworkFolder.appendingPathComponent(art))
        }
    }

    /// Copies a source audio file into the library folder, returning the destination URL
    /// and the file name used for storage. Avoids overwriting existing files.
    func ingestAudioFile(at source: URL) throws -> (url: URL, fileName: String) {
        let fileName = uniqueFileName(for: source.lastPathComponent, in: audioFolder)
        let destination = audioFolder.appendingPathComponent(fileName)
        if FileManager.default.fileExists(atPath: source.path) {
            try FileManager.default.copyItem(at: source, to: destination)
        }
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var mutable = destination
        try? mutable.setResourceValues(values)
        return (destination, fileName)
    }

    /// Writes artwork bytes to disk and returns the file name to record on the book.
    func writeArtwork(_ data: Data, suggestedExtension ext: String = "jpg") throws -> String {
        let fileName = "\(UUID().uuidString).\(ext)"
        let url = artworkFolder.appendingPathComponent(fileName)
        try data.write(to: url, options: [.atomic])
        return fileName
    }

    nonisolated func uniqueFileName(for proposed: String, in folder: URL) -> String {
        var candidate = proposed.replacingOccurrences(of: "/", with: "_")
        var index = 1
        let base = (candidate as NSString).deletingPathExtension
        let ext = (candidate as NSString).pathExtension
        while FileManager.default.fileExists(atPath: folder.appendingPathComponent(candidate).path) {
            candidate = ext.isEmpty ? "\(base)-\(index)" : "\(base)-\(index).\(ext)"
            index += 1
        }
        return candidate
    }
}

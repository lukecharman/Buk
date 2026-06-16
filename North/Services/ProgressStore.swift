import Foundation

/// Disk-backed store for per-book playback progress.
///
/// Uses an atomic JSON write keyed by `bookID`. Reads and writes happen on the actor's
/// own executor so that frequent updates from the player don't block the main thread.
actor ProgressStore {
    private let fileURL: URL
    private var cache: [UUID: PlaybackProgress] = [:]
    private var loaded = false
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    init(fileURL: URL = LibraryPaths.progressFile) {
        self.fileURL = fileURL
    }

    private func ensureLoaded() {
        guard !loaded else { return }
        loaded = true
        guard
            FileManager.default.fileExists(atPath: fileURL.path),
            let data = try? Data(contentsOf: fileURL),
            let array = try? decoder.decode([PlaybackProgress].self, from: data)
        else { return }
        for entry in array { cache[entry.bookID] = entry }
    }

    func progress(for id: UUID) -> PlaybackProgress {
        ensureLoaded()
        return cache[id] ?? .empty(for: id)
    }

    func allProgress() -> [UUID: PlaybackProgress] {
        ensureLoaded()
        return cache
    }

    func update(_ progress: PlaybackProgress) {
        ensureLoaded()
        cache[progress.bookID] = progress
        persist()
    }

    func remove(bookID: UUID) {
        ensureLoaded()
        cache.removeValue(forKey: bookID)
        persist()
    }

    private func persist() {
        let array = Array(cache.values)
        guard let data = try? encoder.encode(array) else { return }
        try? data.write(to: fileURL, options: [.atomic])
    }
}

import Foundation
import Combine
import AVFoundation
import SwiftUI

/// The user's local audiobook library. Owns the on-disk `LibraryStore`, surfaces the
/// list of books to SwiftUI via `@Published`, and handles imports from Files or from
/// a downloaded URL.
@MainActor
final class LibraryViewModel: ObservableObject {
    @Published private(set) var books: [Audiobook] = []
    @Published private(set) var progress: [UUID: PlaybackProgress] = [:]
    @Published private(set) var isImporting = false
    @Published var importError: String?
    /// The book currently presented in the Walkman player overlay, if any.
    @Published var presentingPlayerBook: Audiobook? {
        didSet {
            guard oldValue?.id != presentingPlayerBook?.id else { return }
            currentPlayer?.tearDown()
            if let book = presentingPlayerBook {
                currentPlayer = PlayerViewModel(book: book, library: self)
            } else {
                currentPlayer = nil
            }
        }
    }
    /// The live player for `presentingPlayerBook`, owned here so it persists
    /// across tab switches and is shared with the tab-bar mini player.
    @Published private(set) var currentPlayer: PlayerViewModel?
    /// Active downloads keyed by `CatalogBook.id`.
    @Published private(set) var activeDownloads: [String: Double] = [:]

    private let store: LibraryStore
    let progressStore: ProgressStore

    /// Set while restoring the last-played book on launch, so the UI can avoid
    /// auto-switching to the Player tab during a silent session restore.
    var isRestoringPlayer = false

    init(store: LibraryStore = LibraryStore(), progressStore: ProgressStore = ProgressStore()) {
        self.store = store
        self.progressStore = progressStore
        Task { await initialLoad() }
    }

    private func initialLoad() async {
        let loaded = (try? await store.load()) ?? []
        books = loaded.sorted { $0.dateAdded > $1.dateAdded }
        progress = await progressStore.allProgress()
        if books.isEmpty {
            await importBundledAudiobooks()
        }
        restoreLastPlayedBook()
    }

    /// Re-presents the book the user most recently listened to (if any), so the
    /// Player tab resumes from the saved position after an app relaunch.
    private func restoreLastPlayedBook() {
        guard presentingPlayerBook == nil else { return }
        let candidate = progress.values
            .filter { $0.updatedAt > .distantPast && !$0.isFinished }
            .max { $0.updatedAt < $1.updatedAt }
        guard let lastID = candidate?.bookID,
              let book = books.first(where: { $0.id == lastID }) else { return }
        isRestoringPlayer = true
        presentingPlayerBook = book
    }

    // MARK: - Import

    func importBook(from url: URL) async {
        isImporting = true
        defer { isImporting = false }
        do {
            let book = try await ingest(url: url, source: .importedFile)
            insert(book)
        } catch {
            importError = "Couldn't import \"\(url.lastPathComponent)\": \(error.localizedDescription)"
        }
    }

    /// Imports a user selection from the Files importer. Folders are expanded into
    /// their contained audio files, and any group of multiple files is merged into a
    /// single audiobook with one chapter per file:
    ///
    /// - Each selected folder becomes one audiobook (its audio files = chapters).
    /// - Multiple loosely-selected files become one audiobook (named after their
    ///   parent folder), since selecting every file in a folder is the common way to
    ///   "import a folder" from the iOS Files picker.
    /// - A single selected file imports as a normal single-file book.
    func importSelection(_ urls: [URL]) async {
        isImporting = true
        defer { isImporting = false }

        // Hold security-scoped access for every picked URL until all copies finish.
        let scoped = urls.map { ($0, $0.startAccessingSecurityScopedResource()) }
        defer { for (url, ok) in scoped where ok { url.stopAccessingSecurityScopedResource() } }

        var folderGroups: [(title: String, files: [URL])] = []
        var looseFiles: [URL] = []
        for url in urls {
            if isDirectory(url) {
                let files = audioFiles(in: url)
                if !files.isEmpty {
                    folderGroups.append((url.lastPathComponent, files))
                }
            } else if isAudioFile(url) {
                looseFiles.append(url)
            }
        }

        do {
            for group in folderGroups {
                let book = try await ingestGroup(urls: group.files,
                                                 title: group.title,
                                                 source: .importedFile)
                insert(book)
            }
            if looseFiles.count == 1 {
                let book = try await ingest(url: looseFiles[0], source: .importedFile)
                insert(book)
            } else if looseFiles.count > 1 {
                let sorted = sortedNaturally(looseFiles)
                let title = looseFiles[0].deletingLastPathComponent().lastPathComponent
                let book = try await ingestGroup(urls: sorted, title: title, source: .importedFile)
                insert(book)
            }
        } catch {
            importError = "Couldn't import the selected audio: \(error.localizedDescription)"
        }
    }

    /// Imports a downloaded `CatalogBook` into the library.
    func importDownloaded(localURL: URL, catalogBook: CatalogBook, source: Audiobook.Source) async {
        isImporting = true
        defer { isImporting = false }
        do {
            let book = try await ingest(url: localURL,
                                        source: source,
                                        titleOverride: catalogBook.title,
                                        authorOverride: catalogBook.author,
                                        narratorOverride: catalogBook.narrator,
                                        coverFallbackURL: catalogBook.coverURL)
            insert(book)
            // The downloaded file lived in /tmp; safe to remove the original now.
            try? FileManager.default.removeItem(at: localURL)
        } catch {
            importError = "Couldn't import \"\(catalogBook.title)\": \(error.localizedDescription)"
        }
    }

    func delete(_ book: Audiobook) async {
        await store.deleteFiles(for: book)
        await progressStore.remove(bookID: book.id)
        books.removeAll { $0.id == book.id }
        progress.removeValue(forKey: book.id)
        try? await store.save(books)
    }

    private func insert(_ book: Audiobook) {
        books.removeAll { $0.id == book.id }
        books.insert(book, at: 0)
        Task { try? await store.save(books) }
    }

    private func importBundledAudiobooks() async {
        guard let urls = Bundle.main.urls(forResourcesWithExtension: "m4b", subdirectory: nil) else { return }
        for url in urls {
            do {
                let book = try await ingest(url: url, source: .bundled)
                insert(book)
            } catch {
                #if DEBUG
                print("LibraryViewModel: bundled import failed for \(url.lastPathComponent): \(error)")
                #endif
            }
        }
    }

    // MARK: - Ingest pipeline

    private func ingest(url: URL,
                        source: Audiobook.Source,
                        titleOverride: String? = nil,
                        authorOverride: String? = nil,
                        narratorOverride: String? = nil,
                        coverFallbackURL: URL? = nil) async throws -> Audiobook {
        let (destination, fileName) = try await store.ingestAudioFile(at: url)
        let asset = AVURLAsset(url: destination)
        let metadata = try await BookImporter.read(asset: asset)

        var artworkFileName: String?
        if let data = metadata.artworkData {
            artworkFileName = try? await store.writeArtwork(data)
        } else if let coverFallbackURL {
            if let (data, _) = try? await URLSession.shared.data(from: coverFallbackURL) {
                artworkFileName = try? await store.writeArtwork(data)
            }
        }

        return Audiobook(
            id: UUID(),
            title: titleOverride ?? metadata.title,
            author: authorOverride ?? metadata.author,
            narrator: narratorOverride ?? metadata.narrator,
            fileName: fileName,
            artworkFileName: artworkFileName,
            duration: metadata.duration,
            source: source,
            dateAdded: Date(),
            chapters: metadata.chapters
        )
    }

    /// Merges several audio files into a single audiobook, one chapter per file laid
    /// out on a continuous timeline. The first file with embedded artwork / author /
    /// narrator metadata provides those fields for the whole book.
    private func ingestGroup(urls: [URL],
                             title: String,
                             source: Audiobook.Source) async throws -> Audiobook {
        var fileNames: [String] = []
        var chapters: [Audiobook.Chapter] = []
        var cursor: TimeInterval = 0
        var artworkFileName: String?
        var author: String?
        var narrator: String?

        for url in urls {
            let (destination, fileName) = try await store.ingestAudioFile(at: url)
            let asset = AVURLAsset(url: destination)
            let metadata = try await BookImporter.read(asset: asset)

            fileNames.append(fileName)
            chapters.append(Audiobook.Chapter(id: UUID(),
                                              title: metadata.title,
                                              startTime: cursor,
                                              duration: metadata.duration))
            cursor += metadata.duration
            if author == nil { author = metadata.author }
            if narrator == nil { narrator = metadata.narrator }
            if artworkFileName == nil, let data = metadata.artworkData {
                artworkFileName = try? await store.writeArtwork(data)
            }
        }

        guard let firstFile = fileNames.first else {
            throw CocoaError(.fileNoSuchFile)
        }

        return Audiobook(
            id: UUID(),
            title: title,
            author: author,
            narrator: narrator,
            fileName: firstFile,
            fileNames: fileNames,
            artworkFileName: artworkFileName,
            duration: cursor,
            source: source,
            dateAdded: Date(),
            chapters: chapters
        )
    }

    // MARK: - File selection helpers

    private func isDirectory(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
    }

    private func isAudioFile(_ url: URL) -> Bool {
        SharedInbox.isAudioFile(url)
    }

    /// Returns the audio files inside `folder` (recursively), sorted in natural order
    /// so "Track 2" comes before "Track 10".
    private func audioFiles(in folder: URL) -> [URL] {
        SharedInbox.audioFiles(in: folder)
    }

    private func sortedNaturally(_ urls: [URL]) -> [URL] {
        SharedInbox.naturalSort(urls)
    }

    // MARK: - Shared inbox (Share extension hand-off)

    /// Imports anything the Share extension dropped into the App Group inbox. Each
    /// pending directory becomes one audiobook (a chapter per file). Safe to call
    /// repeatedly; processed directories are removed.
    func importPendingShares() async {
        let groups = SharedInbox.pendingGroups()
        guard !groups.isEmpty else { return }

        isImporting = true
        defer { isImporting = false }

        for group in groups {
            let files = SharedInbox.audioFiles(in: group)
            defer { SharedInbox.remove(group) }
            guard !files.isEmpty else { continue }

            let title = SharedInbox.title(in: group)
                ?? files[0].deletingPathExtension().lastPathComponent
            do {
                if files.count == 1 {
                    let book = try await ingest(url: files[0], source: .importedFile)
                    insert(book)
                } else {
                    let book = try await ingestGroup(urls: files, title: title, source: .importedFile)
                    insert(book)
                }
            } catch {
                importError = "Couldn't import shared audio: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Progress

    func progress(for book: Audiobook) -> PlaybackProgress {
        progress[book.id] ?? .empty(for: book.id)
    }

    func updateProgress(_ value: PlaybackProgress) async {
        progress[value.bookID] = value
        await progressStore.update(value)
    }

    // MARK: - Downloads

    func setDownloadProgress(_ fraction: Double?, for catalogBookID: String) {
        if let fraction { activeDownloads[catalogBookID] = fraction }
        else { activeDownloads.removeValue(forKey: catalogBookID) }
    }

    func downloadProgress(for catalogBookID: String) -> Double? {
        activeDownloads[catalogBookID]
    }
}

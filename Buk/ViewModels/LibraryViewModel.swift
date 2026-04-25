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
    @Published var presentingPlayerBook: Audiobook?
    /// Active downloads keyed by `CatalogBook.id`.
    @Published private(set) var activeDownloads: [String: Double] = [:]

    private let store: LibraryStore
    let progressStore: ProgressStore

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

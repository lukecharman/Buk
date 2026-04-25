import Foundation

/// Source of audiobooks that can be browsed and downloaded inside the app.
///
/// Implementations should be value types or actors safe for concurrent use, since the
/// `DiscoverViewModel` may invoke multiple methods in parallel.
nonisolated protocol CatalogProvider: Sendable {
    /// Stable, human-readable identifier (e.g. "librivox").
    var id: String { get }
    /// User-facing name shown in the Discover screen.
    var displayName: String { get }
    /// Short attribution shown beside results, e.g. "Public domain · LibriVox".
    var attribution: String { get }
    /// Whether the provider exposes a notion of categories beyond plain search.
    var supportsCategories: Bool { get }

    func search(query: String, limit: Int) async throws -> [CatalogBook]
    func books(in category: CatalogCategory, limit: Int) async throws -> [CatalogBook]
    /// Resolves the actual downloadable audio file for a book.
    func resolveDownloadURL(for book: CatalogBook) async throws -> URL
}

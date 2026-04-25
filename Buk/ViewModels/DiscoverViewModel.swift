import Foundation
import Combine
import SwiftUI

/// Drives the Discover tab — searching across `CatalogProvider`s and curating browse
/// rows by `CatalogCategory`.
@MainActor
final class DiscoverViewModel: ObservableObject {
    @Published var query: String = ""
    @Published var selectedProviderID: String
    @Published private(set) var searchResults: [CatalogBook] = []
    @Published private(set) var browseSections: [BrowseSection] = []
    @Published private(set) var isSearching = false
    @Published var error: String?

    let providers: [CatalogProvider]

    struct BrowseSection: Identifiable, Equatable {
        let id: String
        let category: CatalogCategory
        let books: [CatalogBook]
    }

    init(providers: [CatalogProvider] = [LibrivoxProvider(), InternetArchiveProvider()]) {
        self.providers = providers
        self.selectedProviderID = providers.first?.id ?? ""
    }

    var selectedProvider: CatalogProvider? {
        providers.first { $0.id == selectedProviderID }
    }

    func search() async {
        guard let provider = selectedProvider else { return }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { searchResults = []; return }
        isSearching = true
        defer { isSearching = false }
        do {
            searchResults = try await provider.search(query: trimmed, limit: 30)
        } catch is CancellationError {
            // ignored — newer search superseded this one
        } catch {
            self.error = error.localizedDescription
            searchResults = []
        }
    }

    func loadBrowseSections() async {
        guard let provider = selectedProvider, provider.supportsCategories else {
            browseSections = []
            return
        }
        let categories: [CatalogCategory] = [.featured, .fiction, .nonFiction, .childrens,
                                             .poetry, .mystery, .scienceFiction]
        var sections: [BrowseSection] = []
        await withTaskGroup(of: (CatalogCategory, [CatalogBook]).self) { group in
            for category in categories {
                group.addTask { [provider] in
                    let books = (try? await provider.books(in: category, limit: 12)) ?? []
                    return (category, books)
                }
            }
            for await (category, books) in group where !books.isEmpty {
                sections.append(BrowseSection(id: "\(provider.id):\(category.id)",
                                              category: category,
                                              books: books))
            }
        }
        // Preserve the natural category ordering instead of completion order.
        let order = categories.map(\.id)
        sections.sort { lhs, rhs in
            (order.firstIndex(of: lhs.category.id) ?? .max) < (order.firstIndex(of: rhs.category.id) ?? .max)
        }
        browseSections = sections
    }

    /// Downloads `book` into the user's library, reporting progress to `library`.
    func download(_ book: CatalogBook, library: LibraryViewModel) async {
        guard let provider = providers.first(where: { $0.id == book.providerID }) else { return }
        library.setDownloadProgress(0, for: book.id)
        defer { library.setDownloadProgress(nil, for: book.id) }
        do {
            let url = try await provider.resolveDownloadURL(for: book)
            let temp = try await DownloadManager.shared.download(url) { fraction in
                library.setDownloadProgress(fraction, for: book.id)
            }
            let source: Audiobook.Source = (provider.id == "librivox") ? .librivox : .internetArchive
            await library.importDownloaded(localURL: temp, catalogBook: book, source: source)
        } catch {
            self.error = error.localizedDescription
        }
    }
}

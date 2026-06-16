import SwiftUI

/// Lazy, paginated list of LibriVox books for a single genre. Loads the first
/// page on appear and fetches additional pages as the user scrolls to the end,
/// using `LibrivoxProvider`'s `offset` parameter. State is local to the view —
/// there's no shared cache, so navigating away and back will refetch.
struct LibrivoxGenreBooksView: View {
    let genre: String
    @ObservedObject var library: LibraryViewModel
    @ObservedObject var viewModel: DiscoverViewModel

    @State private var books: [CatalogBook] = []
    @State private var isLoading = false
    @State private var reachedEnd = false
    @State private var error: String?

    private static let pageSize = 30

    var body: some View {
        Group {
            if books.isEmpty && isLoading {
                ProgressView().controlSize(.large)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if books.isEmpty {
                ContentUnavailableView("No audiobooks",
                                       systemImage: "books.vertical",
                                       description: Text("LibriVox didn't return anything for this genre."))
            } else {
                List {
                    ForEach(books) { book in
                        CatalogBookRow(book: book, library: library, viewModel: viewModel)
                            .listRowBackground(Color.clear)
                            .onAppear {
                                if book.id == books.last?.id { Task { await loadNextPage() } }
                            }
                    }
                    if isLoading {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                        .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .cassetteBackground()
        .navigationTitle(genre)
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadNextPage() }
        .alert("Couldn't load",
               isPresented: Binding(get: { error != nil },
                                    set: { if !$0 { error = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(error ?? "") }
    }

    private func loadNextPage() async {
        guard !isLoading, !reachedEnd else { return }
        guard let provider = viewModel.providers.first(where: { $0.id == "librivox" })
                as? LibrivoxProvider else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let next = try await provider.books(genre: genre,
                                                limit: Self.pageSize,
                                                offset: books.count)
            if next.isEmpty {
                reachedEnd = true
            } else {
                books.append(contentsOf: next)
                if next.count < Self.pageSize { reachedEnd = true }
            }
        } catch {
            self.error = error.localizedDescription
        }
    }
}

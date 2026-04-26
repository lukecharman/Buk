import SwiftUI

/// The Discover tab — search and browse public-domain audiobooks from one or more
/// `CatalogProvider`s.
struct DiscoverView: View {
    @ObservedObject var library: LibraryViewModel
    @StateObject private var viewModel = DiscoverViewModel()
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            content
                .cassetteBackground()
                .navigationTitle("Discover")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        if viewModel.providers.count > 1 {
                            Menu {
                                ForEach(viewModel.providers, id: \.id) { provider in
                                    Button(provider.displayName) {
                                        viewModel.selectedProviderID = provider.id
                                        Task { await viewModel.loadBrowseSections() }
                                    }
                                }
                            } label: {
                                Label(viewModel.selectedProvider?.displayName ?? "Source",
                                      systemImage: "globe")
                            }
                        }
                    }
                }
                .searchable(text: $viewModel.query, prompt: "Search audiobooks")
                .onSubmit(of: .search) {
                    triggerSearch(immediate: true)
                }
                .onChange(of: viewModel.query) { _, _ in
                    triggerSearch(immediate: false)
                }
                .task { await viewModel.loadBrowseSections() }
                .alert("Couldn't load",
                       isPresented: Binding(get: { viewModel.error != nil },
                                            set: { if !$0 { viewModel.error = nil } })) {
                    Button("OK", role: .cancel) {}
                } message: { Text(viewModel.error ?? "") }
        }
    }

    @ViewBuilder
    private var content: some View {
        if !viewModel.query.isEmpty {
            searchResults
        } else {
            browse
        }
    }

    @ViewBuilder
    private var searchResults: some View {
        if viewModel.isSearching {
            ProgressView().controlSize(.large)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.searchResults.isEmpty {
            ContentUnavailableView.search(text: viewModel.query)
        } else {
            List(viewModel.searchResults) { book in
                CatalogBookRow(book: book, library: library, viewModel: viewModel)
                    .listRowBackground(Color.clear)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }

    @ViewBuilder
    private var browse: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                if let provider = viewModel.selectedProvider {
                    Text(provider.attribution)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                }
                if viewModel.selectedProviderID == "librivox" {
                    NavigationLink {
                        LibrivoxGenreListView(library: library, viewModel: viewModel)
                    } label: {
                        HStack {
                            Label("Browse by Genre", systemImage: "square.grid.2x2")
                                .font(CassetteFont.label(16))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal)
                    }
                    .buttonStyle(.plain)
                }
                ForEach(viewModel.browseSections) { section in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(section.category.title)
                            .font(CassetteFont.label(20))
                            .padding(.horizontal)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(alignment: .top, spacing: 14) {
                                ForEach(section.books) { book in
                                    CatalogBookCard(book: book, library: library, viewModel: viewModel)
                                        .frame(width: 160)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                if viewModel.browseSections.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                }
            }
            .padding(.vertical, 12)
        }
    }

    private func triggerSearch(immediate: Bool) {
        searchTask?.cancel()
        searchTask = Task { @MainActor in
            if !immediate {
                try? await Task.sleep(nanoseconds: 350_000_000)
                if Task.isCancelled { return }
            }
            await viewModel.search()
        }
    }
}

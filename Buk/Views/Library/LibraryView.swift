import SwiftUI
import UniformTypeIdentifiers

/// The Library tab — a grid of cassette tiles, plus an import button that pulls
/// `.m4b` files from the Files app.
struct LibraryView: View {
    @ObservedObject var library: LibraryViewModel
    @State private var showImporter = false

    private let columns = [GridItem(.adaptive(minimum: 170, maximum: 220), spacing: 18)]

    var body: some View {
        NavigationStack {
            Group {
                if library.books.isEmpty {
                    EmptyLibraryView(onImport: { showImporter = true })
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 22) {
                            ForEach(library.books) { book in
                                NavigationLink {
                                    BookDetailView(book: book, library: library)
                                } label: {
                                    CassetteTileView(
                                        book: book,
                                        progress: progress(for: book)
                                    )
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button(role: .destructive) {
                                        Task { await library.delete(book) }
                                    } label: {
                                        Label("Remove", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .cassetteBackground()
            .navigationTitle("Library")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showImporter = true } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Import audiobook")
                }
            }
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: importContentTypes,
                allowsMultipleSelection: true
            ) { result in
                switch result {
                case .success(let urls):
                    for url in urls {
                        let accessed = url.startAccessingSecurityScopedResource()
                        Task {
                            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                            await library.importBook(from: url)
                        }
                    }
                case .failure:
                    break
                }
            }
            .alert("Import failed",
                   isPresented: Binding(get: { library.importError != nil },
                                        set: { if !$0 { library.importError = nil } })) {
                Button("OK", role: .cancel) {}
            } message: { Text(library.importError ?? "") }
            .overlay(alignment: .bottom) {
                if library.isImporting {
                    HStack(spacing: 10) {
                        ProgressView().scaleEffect(0.8)
                        Text("Importing…")
                            .font(.subheadline)
                    }
                    .padding(.horizontal, 18).padding(.vertical, 10)
                    .cassetteGlass(cornerRadius: 18)
                    .padding(.bottom, 24)
                }
            }
        }
    }

    private var importContentTypes: [UTType] {
        var types: [UTType] = [.audio, .mp3]
        if let m4b = UTType(filenameExtension: "m4b") { types.append(m4b) }
        if let m4a = UTType(filenameExtension: "m4a") { types.append(m4a) }
        return types
    }

    private func progress(for book: Audiobook) -> Double {
        let p = library.progress(for: book)
        guard book.duration > 0 else { return 0 }
        return min(1, max(0, p.position / book.duration))
    }
}

private struct EmptyLibraryView: View {
    let onImport: () -> Void
    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "books.vertical")
                .font(.system(size: 64, weight: .regular))
                .foregroundStyle(.secondary)
            Text("Your shelf is empty")
                .font(CassetteFont.label(22))
            Text("Import .m4b audiobooks from Files, or browse Discover for free public-domain titles.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)
            Button {
                onImport()
            } label: {
                Label("Import from Files", systemImage: "square.and.arrow.down")
                    .padding(.horizontal, 18).padding(.vertical, 10)
            }
            .buttonStyle(.plain)
            .cassetteGlass(cornerRadius: 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

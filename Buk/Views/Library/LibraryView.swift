import SwiftUI
import UniformTypeIdentifiers

/// The Library tab — a single-column list of cassette rows. Tapping a row
/// presents the book detail in-place, with the cassette/title/author morphing
/// across via a shared `matchedGeometryEffect` namespace.
struct LibraryView: View {
    @ObservedObject var library: LibraryViewModel
    @State private var showImporter = false
    @State private var selectedBook: Audiobook?
    @Namespace private var heroNamespace

    private let columns = [GridItem(.flexible())]
    private let zoomAnimation: Animation = .spring(response: 0.5, dampingFraction: 0.85)

    var body: some View {
        ZStack {
            NavigationStack {
                content
                    .cassetteBackground()
                    .navigationTitle("Library")
                    .navigationBarTitleDisplayMode(.inline)
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

            if let book = selectedBook {
                BookDetailView(
                    book: book,
                    library: library,
                    transitionNamespace: heroNamespace,
                    onClose: dismiss
                )
                .transition(.opacity)
                .zIndex(1)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if library.books.isEmpty {
            EmptyLibraryView(onImport: { showImporter = true })
        } else {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 22) {
                    ForEach(library.books) { book in
                        Button {
                            present(book)
                        } label: {
                            CassetteTileView(
                                book: book,
                                progress: progress(for: book),
                                transitionNamespace: heroNamespace,
                                isPresentingDetail: selectedBook?.id == book.id
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
                // Recede the rows themselves while a tape is zoomed — the
                // background, scroll view bounds, and nav bar all stay put.
                .scaleEffect(selectedBook == nil ? 1 : 0.92)
                .blur(radius: selectedBook == nil ? 0 : 18)
                .animation(zoomAnimation, value: selectedBook?.id)
            }
        }
    }

    private func present(_ book: Audiobook) {
        guard selectedBook == nil else { return }
        withAnimation(zoomAnimation) {
            selectedBook = book
        }
    }

    private func dismiss() {
        withAnimation(zoomAnimation) {
            selectedBook = nil
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

import SwiftUI
import UniformTypeIdentifiers

/// The Library tab — a single-column list of cassette rows. Tapping a row
/// presents the book detail in-place, with the cassette/title/author morphing
/// across via a shared `matchedGeometryEffect` namespace.
struct LibraryView: View {
    @ObservedObject var library: LibraryViewModel
    @State private var showImporter = false
    @State private var selectedBook: Audiobook?
    /// Bumped by the toolbar's close action to ask the presented detail view
    /// to run its dismiss animation. The detail observes changes and calls its
    /// own `closeAnimated()` so all the fade/blur/morph stays in one place.
    @State private var detailCloseRequest: UUID?
    @Namespace private var heroNamespace

    private let columns = [GridItem(.flexible())]
    private let zoomAnimation: Animation = .spring(response: 0.5, dampingFraction: 0.85)

    var body: some View {
        ZStack(alignment: .topTrailing) {
            NavigationStack {
                content
                    .cassetteBackground()
                    .navigationTitle("Library")
                    .navigationBarTitleDisplayMode(.inline)
                    .fileImporter(
                        isPresented: $showImporter,
                        allowedContentTypes: importContentTypes,
                        allowsMultipleSelection: true
                    ) { result in
                        switch result {
                        case .success(let urls):
                            Task { await library.importSelection(urls) }
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
                    closeRequest: detailCloseRequest,
                    onClose: dismiss
                )
                .transition(.opacity)
                .zIndex(1)
            }

            // Floating top-right button. Lives outside the NavigationStack so
            // it stays above the detail overlay and morphs from "+" to "×"
            // when a tape is open.
            actionButton
                .padding(.trailing, 16)
                .padding(.top, 8)
                .zIndex(2)
        }
    }

    private var actionButton: some View {
        Button {
            if selectedBook == nil {
                showImporter = true
            } else {
                detailCloseRequest = UUID()
            }
        } label: {
            Image(systemName: "plus")
                .font(.title2.weight(.semibold))
                .rotationEffect(.degrees(selectedBook == nil ? 0 : 45))
                .animation(zoomAnimation, value: selectedBook?.id)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .controlSize(.large)
        .accessibilityLabel(selectedBook == nil ? "Import audiobook" : "Close")
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
        var types: [UTType] = [.audio, .mp3, .folder]
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

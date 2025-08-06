import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
    @StateObject private var viewModel = LibraryViewModel()
    @State private var showImporter = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.books) { book in
                    NavigationLink(book.title) {
                        ChapterListView(book: book)
                    }
                }
            }
            .navigationTitle("Library")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showImporter = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .fileImporter(isPresented: $showImporter,
                          allowedContentTypes: [UTType(filenameExtension: "m4b")!],
                          allowsMultipleSelection: false) { result in
                switch result {
                case .success(let url):
                  if let first = url.first {
                    Task { try? await viewModel.importBook(from: first) }
                  }
                case .failure:
                    break
                }
            }
        }
    }
}

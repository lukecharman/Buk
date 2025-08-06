import SwiftUI

struct LibrivoxSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var library: LibraryViewModel
    @StateObject private var viewModel = LibrivoxViewModel()

    var body: some View {
        List(viewModel.books) { book in
            Button(book.title) {
                Task {
                    await viewModel.download(book, library: library)
                    dismiss()
                }
            }
        }
        .navigationTitle("Librivox")
        .searchable(text: $viewModel.query, prompt: "Search")
        .onSubmit(of: .search) {
            Task { await viewModel.search() }
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView()
            }
        }
    }
}

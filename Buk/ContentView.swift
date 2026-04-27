import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var library: LibraryViewModel

    var body: some View {
        LibraryView(library: library)
            .sheet(item: $library.presentingPlayerBook) { book in
                PlayerSheetContainer(book: book, library: library) {
                    library.presentingPlayerBook = nil
                }
                .id(book.id)
            }
    }
}

#Preview {
    ContentView()
        .environmentObject(LibraryViewModel())
}

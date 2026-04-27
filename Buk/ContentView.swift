import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var library: LibraryViewModel

    var body: some View {
        TabView {
            LibraryView(library: library)
                .tabItem { Label("Library", systemImage: "books.vertical.fill") }

            DiscoverView(library: library)
                .tabItem { Label("Discover", systemImage: "sparkles") }
                .badge(library.activeDownloads.isEmpty ? nil : Text("↓"))

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        // The player is a single multi-detent sheet (bar / mid / full) that
        // sits permanently on top of the tab bar while a book is current. The
        // bar detent is sized for tab-bar coexistence and the sheet is fully
        // undismissable — Stop (in the full detent) is the only escape hatch.
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

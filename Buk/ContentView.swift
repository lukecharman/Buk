import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var library: LibraryViewModel
    @State private var playerDetent: PresentationDetent = PlayerSheet.midDetent

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
        .sheet(item: $library.presentingPlayerBook) { book in
            PlayerSheet(book: book, library: library, detent: $playerDetent)
                .id(book.id)
                .presentationDetents(
                    [PlayerSheet.miniDetent, PlayerSheet.midDetent, .large],
                    selection: $playerDetent
                )
                .presentationBackgroundInteraction(.enabled(upThrough: PlayerSheet.midDetent))
                .presentationDragIndicator(.visible)
                .presentationContentInteraction(.scrolls)
                .onAppear {
                    // Reset to the default detent for each new book.
                    playerDetent = PlayerSheet.midDetent
                }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(LibraryViewModel())
}

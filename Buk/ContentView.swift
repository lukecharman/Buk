import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var library: LibraryViewModel

    var body: some View {
        ZStack {
            TabView {
                LibraryView(library: library)
                    .tabItem { Label("Library", systemImage: "books.vertical.fill") }

                DiscoverView(library: library)
                    .tabItem { Label("Discover", systemImage: "sparkles") }
                    .badge(library.activeDownloads.isEmpty ? nil : Text("↓"))

                SettingsView()
                    .tabItem { Label("Settings", systemImage: "gearshape.fill") }
            }

            if let book = library.presentingPlayerBook {
                WalkmanPlayerView(book: book, library: library) {
                    library.presentingPlayerBook = nil
                }
                .transition(.opacity)
                .zIndex(10)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: library.presentingPlayerBook?.id)
    }
}

#Preview {
    ContentView()
        .environmentObject(LibraryViewModel())
}

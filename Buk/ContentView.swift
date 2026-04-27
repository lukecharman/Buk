import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var library: LibraryViewModel
    @State private var selection: Tab = .library

    private enum Tab: Hashable { case library, discover, settings, player }

    var body: some View {
        TabView(selection: $selection) {
            LibraryView(library: library)
                .tabItem { Label("Library", systemImage: "books.vertical.fill") }
                .tag(Tab.library)

            DiscoverView(library: library)
                .tabItem { Label("Discover", systemImage: "sparkles") }
                .badge(library.activeDownloads.isEmpty ? nil : Text("↓"))
                .tag(Tab.discover)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(Tab.settings)

            // Now Playing tab — only present while a book is current. Lives
            // inside a regular tab so the tab bar stays visible above it.
            if let book = library.presentingPlayerBook {
                NowPlayingView(book: book, library: library) {
                    library.presentingPlayerBook = nil
                    selection = .library
                }
                .id(book.id)
                .tabItem {
                    Label(book.title, systemImage: "waveform")
                }
                .tag(Tab.player)
            }
        }
        // If the playing book disappears (Stop), bounce off the player tab.
        .onChange(of: library.presentingPlayerBook?.id) { _, newID in
            if newID == nil && selection == .player {
                selection = .library
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(LibraryViewModel())
}

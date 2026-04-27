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

            // Player tab — always present. Shows the Now Playing view when a
            // book is current, otherwise an empty state.
            PlayerTabView(
                library: library,
                onPickFromLibrary: { selection = .library },
                onStop: {
                    library.presentingPlayerBook = nil
                }
            )
            .tabItem { Label("Player", systemImage: "waveform") }
            .tag(Tab.player)
        }
        .onChange(of: library.presentingPlayerBook?.id) { _, newID in
            // Auto-jump to Player when a new book starts playing.
            if newID != nil { selection = .player }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(LibraryViewModel())
}

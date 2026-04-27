import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var library: LibraryViewModel
    @State private var selection: TabID = .library

    private enum TabID: Hashable { case library, discover, settings, player }

    var body: some View {
        TabView(selection: $selection) {
            Tab("Library", systemImage: "books.vertical.fill", value: TabID.library) {
                LibraryView(library: library)
            }

            Tab("Discover", systemImage: "sparkles", value: TabID.discover) {
                DiscoverView(library: library)
            }
            .badge(library.activeDownloads.isEmpty ? nil : Text("↓"))

            Tab("Settings", systemImage: "gearshape.fill", value: TabID.settings) {
                SettingsView()
            }

            // Player gets its own liquid-glass capsule, separated from the
            // other tabs (.search role on iOS 26 floats as a standalone pill).
            Tab("Player", systemImage: "waveform", value: TabID.player, role: .search) {
                PlayerTabView(
                    library: library,
                    onPickFromLibrary: { selection = .library },
                    onStop: { library.presentingPlayerBook = nil }
                )
            }
        }
        .onChange(of: library.presentingPlayerBook?.id) { _, newID in
            if newID != nil { selection = .player }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(LibraryViewModel())
}

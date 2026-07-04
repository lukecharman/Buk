import SwiftUI

/// The app's four destinations. Declared at file scope so the tab container and
/// anything that needs to drive selection can share it.
enum NorthTab: Hashable {
    case library, discover, settings, player
}

struct ContentView: View {
    @EnvironmentObject private var library: LibraryViewModel
    @State private var selection: NorthTab = .library

    var body: some View {
        TabView(selection: $selection) {
            Tab("", systemImage: "books.vertical.fill", value: NorthTab.library) {
                LibraryView(library: library)
            }

            Tab("", systemImage: "sparkles", value: NorthTab.discover) {
                DiscoverView(library: library)
            }
            .badge(library.activeDownloads.count)

            Tab("", systemImage: "gearshape.fill", value: NorthTab.settings) {
                SettingsView()
            }

            // The player lives in its own search-style tab, floating apart on the
            // trailing side of the tab bar.
            Tab("", systemImage: "waveform", value: NorthTab.player, role: .search) {
                PlayerTabView(
                    library: library,
                    onPickFromLibrary: { selection = .library }
                )
            }
        }
        .onChange(of: library.presentingPlayerBook?.id) { _, newID in
            if library.isRestoringPlayer {
                library.isRestoringPlayer = false
                return
            }
            if newID != nil { selection = .player }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(LibraryViewModel())
}

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var library: LibraryViewModel
    @State private var selection: Tab = .library
    @State private var isPlayerExpanded = false
    @State private var lastNonPlayerSelection: Tab = .library

    private enum Tab: Hashable { case library, discover, settings, player }

    var body: some View {
        ZStack {
            TabView(selection: tabSelection) {
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

                // Player tab is only added while a book is current. Its
                // content is never shown — selecting it instead expands the
                // player sheet and bounces the selection back.
                if library.presentingPlayerBook != nil {
                    Color.clear
                        .tabItem {
                            Label(
                                library.presentingPlayerBook?.title ?? "Now Playing",
                                systemImage: "waveform"
                            )
                        }
                        .tag(Tab.player)
                }
            }

            // Invisible host that owns the long-lived PlayerViewModel and
            // presents the expanded sheet. Lives as long as a book is current,
            // so dismissing the sheet doesn't tear playback down.
            if let book = library.presentingPlayerBook {
                PlayerHost(
                    book: book,
                    library: library,
                    isExpanded: $isPlayerExpanded,
                    onStop: {
                        library.presentingPlayerBook = nil
                        isPlayerExpanded = false
                    }
                )
                .id(book.id)
            }
        }
        .onChange(of: library.presentingPlayerBook?.id) { _, newID in
            if newID == nil { isPlayerExpanded = false }
        }
    }

    /// Custom binding that intercepts taps on the player tab: instead of
    /// switching to it, we expand the player sheet and revert the selection.
    private var tabSelection: Binding<Tab> {
        Binding(
            get: { selection },
            set: { newValue in
                if newValue == .player {
                    isPlayerExpanded = true
                    selection = lastNonPlayerSelection
                } else {
                    selection = newValue
                    lastNonPlayerSelection = newValue
                }
            }
        )
    }
}

#Preview {
    ContentView()
        .environmentObject(LibraryViewModel())
}

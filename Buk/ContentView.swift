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
        // Mini-player bar lives above the tab bar via safeAreaInset, so the
        // tab bar stays visible and tappable. PlayerHost owns the long-lived
        // PlayerViewModel; the expanded sheet is presented from inside it.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let book = library.presentingPlayerBook {
                PlayerHost(book: book, library: library) {
                    library.presentingPlayerBook = nil
                }
                .id(book.id)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.85),
                   value: library.presentingPlayerBook?.id)
    }
}

#Preview {
    ContentView()
        .environmentObject(LibraryViewModel())
}

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var library: LibraryViewModel
    @State private var selection: NorthTab = .library

    var body: some View {
        ZStack {
            tab(.library) { LibraryView(library: library) }
            tab(.discover) { DiscoverView(library: library) }
            tab(.settings) { SettingsView() }
            tab(.player) {
                PlayerTabView(
                    library: library,
                    onPickFromLibrary: { selection = .library }
                )
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            CustomTabBar(selection: $selection, library: library)
        }
        .onChange(of: library.presentingPlayerBook?.id) { _, newID in
            if library.isRestoringPlayer {
                library.isRestoringPlayer = false
                return
            }
            if newID != nil { selection = .player }
        }
    }

    /// Keeps every destination alive (preserving scroll/search state and avoiding
    /// reloads) while only the selected one is visible and interactive.
    @ViewBuilder
    private func tab<Content: View>(_ tab: NorthTab, @ViewBuilder content: () -> Content) -> some View {
        content()
            .opacity(selection == tab ? 1 : 0)
            .allowsHitTesting(selection == tab)
            .zIndex(selection == tab ? 1 : 0)
    }
}

#Preview {
    ContentView()
        .environmentObject(LibraryViewModel())
}

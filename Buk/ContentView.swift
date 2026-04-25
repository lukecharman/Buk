import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var library: LibraryViewModel

    var body: some View {
        TabView {
            LibraryView(library: library)
                .tabItem { Label("Library", systemImage: "books.vertical.fill") }

            DiscoverView(library: library)
                .tabItem { Label("Discover", systemImage: "sparkles") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(LibraryViewModel())
}

import SwiftUI

@main
struct BukApp: App {
    @StateObject private var library = LibraryViewModel()

    init() {
        AudioSessionManager.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(library)
                .tint(CassettePalette.recordRed)
        }
    }
}

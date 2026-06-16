import SwiftUI
import UIKit

@main
struct NorthApp: App {
    @StateObject private var library = LibraryViewModel()
    @StateObject private var settings = SettingsStore.shared
    @Environment(\.scenePhase) private var scenePhase

    init() {
        AudioSessionManager.configure()
        Self.applySerifNavigationTitles()
    }

    /// UIKit renders navigation-bar titles, so SwiftUI's `.fontDesign(.serif)`
    /// doesn't reach them. Point the title fonts at the system serif face so the
    /// screen titles match the rest of the app.
    private static func applySerifNavigationTitles() {
        func serif(_ size: CGFloat, weight: UIFont.Weight) -> UIFont {
            let base = UIFont.systemFont(ofSize: size, weight: weight)
            if let descriptor = base.fontDescriptor.withDesign(.serif) {
                return UIFont(descriptor: descriptor, size: size)
            }
            return base
        }
        UINavigationBar.appearance().titleTextAttributes = [.font: serif(17, weight: .semibold)]
        UINavigationBar.appearance().largeTitleTextAttributes = [.font: serif(34, weight: .bold)]
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(library)
                .tint(settings.accent)
                .fontDesign(.serif)
                .onOpenURL { url in
                    if url.scheme == "north" {
                        Task { await library.importPendingShares() }
                    } else {
                        Task { await library.importBook(from: url) }
                    }
                }
                .task { await library.importPendingShares() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await library.importPendingShares() }
            }
        }
    }
}

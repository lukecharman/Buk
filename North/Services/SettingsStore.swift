import Foundation
import Combine
import SwiftUI

/// User-tweakable playback preferences. Backed by `UserDefaults` so it's available
/// instantly on launch.
@MainActor
final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    @AppStorage("settings.skipBackSeconds")    var skipBackSeconds: Int = 15
    @AppStorage("settings.skipForwardSeconds") var skipForwardSeconds: Int = 30
    @AppStorage("settings.defaultPlaybackRate") var defaultPlaybackRate: Double = 1.0
    @AppStorage("settings.autoPlayNextChapter") var autoPlayNextChapter: Bool = true
    @AppStorage("settings.sleepTimerMinutes")  var sleepTimerMinutes: Int = 0

    private static let appTintKey = "settings.appTint"

    /// The accent tint chosen by the user, applied app-wide. Backed by a
    /// `@Published` (rather than `@AppStorage`) so every observer re-renders
    /// immediately when it changes; persisted manually to `UserDefaults`.
    @Published var appTint: AppTint {
        didSet { UserDefaults.standard.set(appTint.rawValue, forKey: Self.appTintKey) }
    }

    /// Convenience accessor for the chosen tint colour.
    var accent: Color { appTint.color }

    /// The chosen tint as a `ShapeStyle` — a gradient when the tint is a gradient,
    /// otherwise the flat colour. Use for prominent fills that should show
    /// gradients (tab bar, scrubber, chapter indicators).
    var accentStyle: AnyShapeStyle { appTint.style }

    private init() {
        let stored = UserDefaults.standard.string(forKey: Self.appTintKey)
        appTint = stored.flatMap(AppTint.init(rawValue:)) ?? .red
    }

    static let allowedSkipValues: [Int] = [5, 10, 15, 20, 30, 45, 60, 90]
    static let allowedRates: [Double] = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.5, 3.0]
    static let allowedSleepTimers: [Int] = [0, 5, 10, 15, 30, 45, 60, 90]
}

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

    static let allowedSkipValues: [Int] = [5, 10, 15, 20, 30, 45, 60, 90]
    static let allowedRates: [Double] = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.5, 3.0]
    static let allowedSleepTimers: [Int] = [0, 5, 10, 15, 30, 45, 60, 90]
}

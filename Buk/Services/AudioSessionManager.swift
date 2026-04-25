import Foundation
import AVFoundation
#if canImport(UIKit)
import UIKit
#endif

/// Configures the shared `AVAudioSession` for background spoken-audio playback.
///
/// - Uses `.playback` category with `.spokenAudio` mode so playback continues with the
///   screen locked, mixes politely with other audio, and respects Do Not Disturb.
/// - Honours `.longFormAudio` route sharing policy on iOS for AirPlay 2 long-form
///   handoff (audiobook).
/// - Activates lazily — call `activate()` before starting playback and `deactivate()`
///   when the user explicitly stops, so we don't hold the audio focus needlessly.
enum AudioSessionManager {
    static func configure() {
        #if os(iOS) || os(visionOS) || os(tvOS) || os(watchOS)
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback,
                                    mode: .spokenAudio,
                                    policy: .longFormAudio,
                                    options: [])
        } catch {
            // Failing to configure the session shouldn't crash the app — playback
            // simply may not work in background.
            #if DEBUG
            print("AudioSessionManager: configure failed: \(error)")
            #endif
        }
        #endif
    }

    static func activate() {
        #if os(iOS) || os(visionOS) || os(tvOS) || os(watchOS)
        try? AVAudioSession.sharedInstance().setActive(true, options: [])
        #endif
    }

    static func deactivate() {
        #if os(iOS) || os(visionOS) || os(tvOS) || os(watchOS)
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        #endif
    }
}

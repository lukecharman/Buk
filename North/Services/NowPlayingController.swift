import Foundation
import AVFoundation
import MediaPlayer
#if canImport(UIKit)
import UIKit
typealias PlatformImage = UIImage
#elseif canImport(AppKit)
import AppKit
typealias PlatformImage = NSImage
#endif

/// Bridges a single `AVPlayer` to `MPNowPlayingInfoCenter` and `MPRemoteCommandCenter`
/// so the user gets a Lock Screen / Control Center / CarPlay / AirPods experience.
///
/// The owning `PlayerViewModel` retains this object for the lifetime of a playback
/// session and tells it about play/pause/skip events so the OS controls stay in sync.
@MainActor
final class NowPlayingController {
    private weak var player: AVPlayer?
    private var book: Audiobook?
    private var artwork: MPMediaItemArtwork?

    var onPlay: (() -> Void)?
    var onPause: (() -> Void)?
    var onSkipForward: (() -> Void)?
    var onSkipBackward: (() -> Void)?
    var onNextChapter: (() -> Void)?
    var onPreviousChapter: (() -> Void)?
    var onSeek: ((TimeInterval) -> Void)?
    var onRateChange: ((Double) -> Void)?

    var skipForwardInterval: Int = 30 {
        didSet { commandCenter.skipForwardCommand.preferredIntervals = [NSNumber(value: skipForwardInterval)] }
    }
    var skipBackwardInterval: Int = 15 {
        didSet { commandCenter.skipBackwardCommand.preferredIntervals = [NSNumber(value: skipBackwardInterval)] }
    }

    private var commandCenter: MPRemoteCommandCenter { .shared() }

    func attach(player: AVPlayer, book: Audiobook, artworkImage: PlatformImage?) {
        self.player = player
        self.book = book
        if let artworkImage {
            self.artwork = MPMediaItemArtwork(boundsSize: artworkImage.size) { _ in artworkImage }
        } else {
            self.artwork = nil
        }
        registerCommands()
        refreshNowPlayingMetadata()
    }

    func detach() {
        unregisterCommands()
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        player = nil
        book = nil
        artwork = nil
    }

    // MARK: - Now Playing metadata

    func refreshNowPlayingMetadata() {
        guard let book else { return }
        var info: [String: Any] = [:]
        info[MPMediaItemPropertyTitle] = book.chapters.indices.contains(currentChapterIndex)
            ? book.chapters[currentChapterIndex].title
            : book.title
        info[MPMediaItemPropertyAlbumTitle] = book.title
        if let author = book.author { info[MPMediaItemPropertyArtist] = author }
        info[MPMediaItemPropertyPlaybackDuration] = book.duration
        info[MPNowPlayingInfoPropertyMediaType] = MPNowPlayingInfoMediaType.audio.rawValue
        info[MPNowPlayingInfoPropertyIsLiveStream] = false
        if let artwork { info[MPMediaItemPropertyArtwork] = artwork }
        if let player {
            info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = player.currentTime().seconds
            info[MPNowPlayingInfoPropertyPlaybackRate] = Double(player.rate)
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    func updateProgress(elapsed: TimeInterval, rate: Double) {
        var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = elapsed
        info[MPNowPlayingInfoPropertyPlaybackRate] = rate
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    var currentChapterIndex: Int = 0 {
        didSet { refreshNowPlayingMetadata() }
    }

    // MARK: - Remote commands

    private func registerCommands() {
        let cc = commandCenter

        cc.playCommand.isEnabled = true
        cc.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.onPlay?() }
            return .success
        }
        cc.pauseCommand.isEnabled = true
        cc.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.onPause?() }
            return .success
        }
        cc.togglePlayPauseCommand.isEnabled = true
        cc.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if self.player?.rate ?? 0 > 0 { self.onPause?() } else { self.onPlay?() }
            }
            return .success
        }

        cc.skipForwardCommand.isEnabled = true
        cc.skipForwardCommand.preferredIntervals = [NSNumber(value: skipForwardInterval)]
        cc.skipForwardCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.onSkipForward?() }
            return .success
        }
        cc.skipBackwardCommand.isEnabled = true
        cc.skipBackwardCommand.preferredIntervals = [NSNumber(value: skipBackwardInterval)]
        cc.skipBackwardCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.onSkipBackward?() }
            return .success
        }

        cc.nextTrackCommand.isEnabled = true
        cc.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.onNextChapter?() }
            return .success
        }
        cc.previousTrackCommand.isEnabled = true
        cc.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.onPreviousChapter?() }
            return .success
        }

        cc.changePlaybackPositionCommand.isEnabled = true
        cc.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            let time = event.positionTime
            Task { @MainActor in self?.onSeek?(time) }
            return .success
        }
        cc.changePlaybackRateCommand.isEnabled = true
        cc.changePlaybackRateCommand.supportedPlaybackRates = SettingsStore.allowedRates.map { NSNumber(value: $0) }
        cc.changePlaybackRateCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackRateCommandEvent else { return .commandFailed }
            let rate = Double(event.playbackRate)
            Task { @MainActor in self?.onRateChange?(rate) }
            return .success
        }
    }

    private func unregisterCommands() {
        let cc = commandCenter
        cc.playCommand.removeTarget(nil)
        cc.pauseCommand.removeTarget(nil)
        cc.togglePlayPauseCommand.removeTarget(nil)
        cc.skipForwardCommand.removeTarget(nil)
        cc.skipBackwardCommand.removeTarget(nil)
        cc.nextTrackCommand.removeTarget(nil)
        cc.previousTrackCommand.removeTarget(nil)
        cc.changePlaybackPositionCommand.removeTarget(nil)
        cc.changePlaybackRateCommand.removeTarget(nil)
    }
}

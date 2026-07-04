import Foundation
import Combine
import AVFoundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Drives playback of a single `Audiobook`. Owns:
///
/// - the `AVPlayer` instance,
/// - persistence of progress back to `LibraryViewModel`/`ProgressStore`,
/// - the `NowPlayingController` so the lock screen and remote controls work,
/// - a sleep timer.
///
/// Designed to be created when the user opens the player and torn down when they
/// leave it. Background audio keeps playing because the audio session remains active.
@MainActor
final class PlayerViewModel: ObservableObject {
    @Published private(set) var book: Audiobook
    @Published private(set) var isPlaying = false
    @Published private(set) var currentChapterIndex: Int = 0
    @Published private(set) var elapsedTime: TimeInterval = 0
    @Published private(set) var isReady = false
    @Published private(set) var sleepTimerRemaining: TimeInterval?
    @Published var playbackError: String?
    @Published var playbackRate: Double {
        didSet {
            player.rate = isPlaying ? Float(playbackRate) : 0
            nowPlaying.updateProgress(elapsed: elapsedTime, rate: isPlaying ? playbackRate : 0)
        }
    }

    private let player: AVPlayer
    private let library: LibraryViewModel
    private let settings: SettingsStore
    private let nowPlaying = NowPlayingController()

    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var sleepTimerTask: Task<Void, Never>?
    private var lastPersistedSecond: Int = -1

    /// Chapters the user has played through to the end, in any order.
    private var completedChapters: Set<Int> = []
    /// Chapters the user has begun but not finished.
    private var startedChapters: Set<Int> = []
    /// Absolute position seen on the previous time-observer tick, used to detect
    /// chapter boundaries that were crossed by *continuous playback* (as opposed to
    /// a seek/jump) so only genuinely-listened chapters get marked complete.
    private var lastTickTime: TimeInterval?

    /// When set, playback starts at this chapter instead of the saved position.
    private let startChapterIndex: Int?
    /// When true, playback begins automatically once the player is ready.
    private let autoPlay: Bool

    init(book: Audiobook,
         library: LibraryViewModel,
         settings: SettingsStore = .shared,
         startChapterIndex: Int? = nil,
         autoPlay: Bool = false) {
        self.book = book
        self.library = library
        self.settings = settings
        self.playbackRate = settings.defaultPlaybackRate
        self.startChapterIndex = startChapterIndex
        self.autoPlay = autoPlay

        AudioSessionManager.configure()

        let fileNames = book.allFileNames
        if fileNames.count <= 1 {
            // Single-file book: load the asset directly for instant playback.
            let url = LibraryPaths.audioFolder.appendingPathComponent(fileNames.first ?? book.fileName)
            let item = AVPlayerItem(url: url)
            self.player = AVPlayer(playerItem: item)
            self.player.automaticallyWaitsToMinimizeStalling = true
            attachObservers(item: item)
            attachNowPlaying()
            Task { await restoreProgress() }
        } else {
            // Multi-file book: stitch the files into one continuous timeline so the
            // rest of the player (chapters, seeking, duration) is unchanged.
            self.player = AVPlayer()
            self.player.automaticallyWaitsToMinimizeStalling = true
            attachNowPlaying()
            Task { await setUpCompositionPlayback(fileNames: fileNames) }
        }
    }

    deinit {
        // All clean-up is performed by `tearDown()`, which the owning view calls in
        // `onDisappear`. Doing the work there keeps every property access on the
        // main actor and avoids cross-isolation hazards in `deinit`.
    }

    // MARK: - Lifecycle

    func tearDown() {
        sleepTimerTask?.cancel()
        sleepTimerTask = nil
        sleepTimerRemaining = nil
        if let timeObserver { player.removeTimeObserver(timeObserver) }
        timeObserver = nil
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        endObserver = nil
        pause()
        nowPlaying.detach()
        AudioSessionManager.deactivate()
    }

    private func attachObservers(item: AVPlayerItem) {
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            // The time observer fires on the main queue but the closure isn't
            // MainActor-isolated by the compiler's eyes, so jump explicitly.
            let seconds = time.seconds
            Task { @MainActor in
                guard let self else { return }
                guard seconds.isFinite else { return }
                self.detectPlayedThroughChapters(upTo: seconds)
                self.elapsedTime = seconds
                self.updateChapter(for: seconds)
                self.nowPlaying.updateProgress(elapsed: seconds, rate: self.isPlaying ? self.playbackRate : 0)
                self.persistProgressIfNeeded()
            }
        }
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.handlePlaybackFinished() }
        }
    }

    private func attachNowPlaying() {        let artworkImage: PlatformImage? = {
            guard let name = book.artworkFileName,
                  let data = try? Data(contentsOf: LibraryPaths.artworkFolder.appendingPathComponent(name))
            else { return nil }
            return PlatformImage(data: data)
        }()
        nowPlaying.attach(player: player, book: book, artworkImage: artworkImage)
        nowPlaying.skipForwardInterval = settings.skipForwardSeconds
        nowPlaying.skipBackwardInterval = settings.skipBackSeconds
        nowPlaying.onPlay          = { [weak self] in self?.play() }
        nowPlaying.onPause         = { [weak self] in self?.pause() }
        nowPlaying.onSkipForward   = { [weak self] in self?.skipForward() }
        nowPlaying.onSkipBackward  = { [weak self] in self?.skipBackward() }
        nowPlaying.onNextChapter   = { [weak self] in self?.nextChapter() }
        nowPlaying.onPreviousChapter = { [weak self] in self?.previousChapter() }
        nowPlaying.onSeek          = { [weak self] time in self?.seek(to: time) }
        nowPlaying.onRateChange    = { [weak self] rate in self?.playbackRate = rate }
    }

    /// Applies a metadata rename to the live session so the Now Playing screen
    /// and system controls (lock screen / control centre) reflect the new
    /// title and author immediately.
    func applyRename(title: String, author: String?) {
        book.title = title
        book.author = author
        attachNowPlaying()
    }

    private func restoreProgress() async {
        // Seed the per-chapter tracking from any saved progress so previously
        // completed/started chapters survive across sessions.
        let saved = await library.progressStore.progress(for: book.id)
        completedChapters = saved.completedChapters
        startedChapters = saved.startedChapters

        if let startChapterIndex, book.chapters.indices.contains(startChapterIndex) {
            // Caller asked to begin at a specific chapter (e.g. tapping a chapter
            // row); jump there instead of restoring the saved position.
            seek(to: book.chapters[startChapterIndex].startTime, persist: true)
        } else if saved.position > 0, saved.position < book.duration - 1 {
            seek(to: saved.position, persist: false)
        }
        isReady = true
        if autoPlay { play() }
    }

    /// Builds a single `AVPlayerItem` that plays every file in the book back-to-back,
    /// then wires up the observers and restores progress once it's ready.
    private func setUpCompositionPlayback(fileNames: [String]) async {
        guard let item = await makeCompositionItem(fileNames: fileNames) else {
            playbackError = "Couldn't prepare this audiobook for playback."
            isReady = true
            return
        }
        player.replaceCurrentItem(with: item)
        attachObservers(item: item)
        await restoreProgress()
    }

    /// Concatenates the audio tracks of `fileNames` into one composition, in order.
    private func makeCompositionItem(fileNames: [String]) async -> AVPlayerItem? {
        let composition = AVMutableComposition()
        guard let audioTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else { return nil }

        var cursor = CMTime.zero
        for name in fileNames {
            let url = LibraryPaths.audioFolder.appendingPathComponent(name)
            let asset = AVURLAsset(url: url)
            do {
                let tracks = try await asset.loadTracks(withMediaType: .audio)
                let duration = try await asset.load(.duration)
                guard let sourceTrack = tracks.first, duration.seconds.isFinite, duration > .zero else { continue }
                let range = CMTimeRange(start: .zero, duration: duration)
                try audioTrack.insertTimeRange(range, of: sourceTrack, at: cursor)
                cursor = cursor + duration
            } catch {
                continue
            }
        }

        guard cursor > .zero else { return nil }
        return AVPlayerItem(asset: composition)
    }

    // MARK: - Transport

    func togglePlay() { isPlaying ? pause() : play() }

    func play() {
        AudioSessionManager.activate()
        player.play()
        player.rate = Float(playbackRate)
        isPlaying = true
        nowPlaying.updateProgress(elapsed: elapsedTime, rate: playbackRate)
    }

    func pause() {
        player.pause()
        isPlaying = false
        nowPlaying.updateProgress(elapsed: elapsedTime, rate: 0)
        persistProgress(force: true)
    }

    func skipForward() {
        seek(to: min(elapsedTime + Double(settings.skipForwardSeconds), book.duration))
    }

    func skipBackward() {
        seek(to: max(elapsedTime - Double(settings.skipBackSeconds), 0))
    }

    func nextChapter() {
        let next = currentChapterIndex + 1
        guard next < book.chapters.count else { return }
        seek(to: book.chapters[next].startTime)
    }

    func previousChapter() {
        // Standard audiobook behaviour: pressing back within the first 3 seconds of a
        // chapter goes to the previous chapter, otherwise restart current chapter.
        let chapter = book.chapters[currentChapterIndex]
        let intoChapter = elapsedTime - chapter.startTime
        if intoChapter > 3, currentChapterIndex >= 0 {
            seek(to: chapter.startTime)
            return
        }
        let previous = currentChapterIndex - 1
        guard previous >= 0 else { seek(to: 0); return }
        seek(to: book.chapters[previous].startTime)
    }

    func jumpToChapter(at index: Int) {
        guard book.chapters.indices.contains(index) else { return }
        seek(to: book.chapters[index].startTime)
    }

    /// Seeks within the entire book.
    func seek(to time: TimeInterval, persist: Bool = true) {
        let clamped = max(0, min(time, book.duration))
        // A seek breaks the continuous-playback chain, so the next observer tick
        // must not treat the gap it jumped over as "played through".
        lastTickTime = nil
        let cm = CMTime(seconds: clamped, preferredTimescale: 600)
        player.seek(to: cm, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.elapsedTime = clamped
                self.updateChapter(for: clamped)
                self.nowPlaying.updateProgress(elapsed: clamped,
                                                rate: self.isPlaying ? self.playbackRate : 0)
                if persist { self.persistProgress(force: true) }
            }
        }
    }

    /// Seeks via a 0–1 fraction of the entire book.
    func seek(toBookFraction fraction: Double) {
        seek(to: max(0, min(1, fraction)) * book.duration)
    }

    var bookFraction: Double {
        guard book.duration > 0 else { return 0 }
        return elapsedTime / book.duration
    }

    var currentChapterStart: TimeInterval {
        book.chapters.indices.contains(currentChapterIndex) ? book.chapters[currentChapterIndex].startTime : 0
    }

    var currentChapterEnd: TimeInterval {
        guard book.chapters.indices.contains(currentChapterIndex) else { return book.duration }
        return book.chapters[currentChapterIndex].endTime
    }

    var currentChapter: Audiobook.Chapter? {
        book.chapters.indices.contains(currentChapterIndex) ? book.chapters[currentChapterIndex] : nil
    }

    var chapterFraction: Double {
        let length = currentChapterEnd - currentChapterStart
        guard length > 0 else { return 0 }
        return max(0, min(1, (elapsedTime - currentChapterStart) / length))
    }

    var remaining: TimeInterval {
        max(0, book.duration - elapsedTime)
    }

    // MARK: - Sleep timer

    /// Starts a sleep timer that pauses playback after `minutes`. Pass 0 to cancel.
    func setSleepTimer(minutes: Int) {
        sleepTimerTask?.cancel()
        sleepTimerTask = nil
        sleepTimerRemaining = nil
        guard minutes > 0 else { return }
        let total = TimeInterval(minutes * 60)
        sleepTimerRemaining = total
        sleepTimerTask = Task { @MainActor [weak self] in
            let start = Date()
            while !Task.isCancelled {
                let elapsed = Date().timeIntervalSince(start)
                let remaining = total - elapsed
                if remaining <= 0 { break }
                self?.sleepTimerRemaining = remaining
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
            if Task.isCancelled { return }
            self?.pause()
            self?.sleepTimerRemaining = nil
        }
    }

    // MARK: - Internals

    private func updateChapter(for time: TimeInterval) {
        let new = book.chapterIndex(containing: time)
        // Being positioned in a chapter counts as having started it (unless it's
        // already finished), so it shows an "in-progress" state.
        markChapterStarted(new)
        if new != currentChapterIndex {
            currentChapterIndex = new
            nowPlaying.currentChapterIndex = new
        }
    }

    /// Marks every chapter whose end was crossed by continuous playback between the
    /// previous tick and `now` as completed. Large gaps (seeks/jumps) are ignored so
    /// skipping ahead never marks the skipped chapters as listened.
    private func detectPlayedThroughChapters(upTo now: TimeInterval) {
        defer { lastTickTime = now }
        guard isPlaying, let previous = lastTickTime else { return }
        let delta = now - previous
        // A normal tick advances ~0.5s × rate; anything larger is a discontinuity.
        guard delta > 0, delta < 5 else { return }
        var completedSomething = false
        for (index, chapter) in book.chapters.enumerated()
        where chapter.endTime > previous && chapter.endTime <= now {
            if completedChapters.insert(index).inserted {
                startedChapters.remove(index)
                completedSomething = true
            }
        }
        if completedSomething { persistProgress(force: true) }
    }

    private func markChapterStarted(_ index: Int) {
        guard book.chapters.indices.contains(index), !completedChapters.contains(index) else { return }
        startedChapters.insert(index)
    }

    private func markChapterCompleted(_ index: Int) {
        guard book.chapters.indices.contains(index) else { return }
        completedChapters.insert(index)
        startedChapters.remove(index)
    }

    private func persistProgressIfNeeded() {
        let second = Int(elapsedTime)
        if second != lastPersistedSecond, second % 5 == 0 {
            persistProgress(force: false)
        }
    }

    private func persistProgress(force: Bool) {
        let second = Int(elapsedTime)
        if !force && second == lastPersistedSecond { return }
        lastPersistedSecond = second
        let value = PlaybackProgress(
            bookID: book.id,
            position: elapsedTime,
            chapterIndex: currentChapterIndex,
            updatedAt: Date(),
            isFinished: false,
            completedChapters: completedChapters,
            startedChapters: startedChapters
        )
        Task { await library.updateProgress(value) }
    }

    private func handlePlaybackFinished() {
        markChapterCompleted(currentChapterIndex)
        if settings.autoPlayNextChapter, currentChapterIndex < book.chapters.count - 1 {
            nextChapter()
            play()
            return
        }
        isPlaying = false
        let value = PlaybackProgress(
            bookID: book.id,
            position: book.duration,
            chapterIndex: max(0, book.chapters.count - 1),
            updatedAt: Date(),
            isFinished: true,
            completedChapters: completedChapters,
            startedChapters: startedChapters
        )
        Task { await library.updateProgress(value) }
    }
}

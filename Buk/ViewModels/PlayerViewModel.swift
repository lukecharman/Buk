import Combine
import Foundation
import AVFoundation

@MainActor
final class PlayerViewModel: ObservableObject {
    @Published private(set) var isPlaying = false
    @Published private(set) var currentChapterIndex: Int
    @Published var playbackRate: Float = 1.0 {
        didSet {
            if isPlaying {
                player.rate = playbackRate
            }
        }
    }
    @Published private(set) var elapsedTime: TimeInterval = 0

    let book: Audiobook
    private let player: AVPlayer
    private var timeObserver: Any?

    init(book: Audiobook, startAt index: Int) {
        self.book = book
        self.currentChapterIndex = index
        let url = LibraryViewModel.libraryFolder.appendingPathComponent(book.fileName)
        self.player = AVPlayer(url: url)
        addTimeObserver()
        seek(to: book.chapters[index].startTime)
    }

    deinit {
        if let timeObserver {
            player.removeTimeObserver(timeObserver)
        }
    }

    func togglePlay() {
        if isPlaying { pause() } else { play() }
    }

    func play() {
        player.play()
        player.rate = playbackRate
        isPlaying = true
    }

    func pause() {
        player.pause()
        isPlaying = false
    }

    func nextChapter() {
        let nextIndex = currentChapterIndex + 1
        guard nextIndex < book.chapters.count else { return }
        seek(to: book.chapters[nextIndex].startTime)
    }

    func previousChapter() {
        let prevIndex = currentChapterIndex - 1
        guard prevIndex >= 0 else { return }
        seek(to: book.chapters[prevIndex].startTime)
    }

    func skipForward15() {
        let newTime = min(elapsedTime + 15, totalDuration)
        seek(to: newTime)
    }

    func skipBackward15() {
        let newTime = max(elapsedTime - 15, 0)
        seek(to: newTime)
    }

    var totalDuration: TimeInterval {
        player.currentItem?.asset.duration.seconds ?? 0
    }

    var currentChapterStart: TimeInterval {
        book.chapters[currentChapterIndex].startTime
    }

    var currentChapterEnd: TimeInterval {
        if currentChapterIndex + 1 < book.chapters.count {
            return book.chapters[currentChapterIndex + 1].startTime
        } else {
            return totalDuration
        }
    }

    var currentChapterDuration: TimeInterval {
        currentChapterEnd - currentChapterStart
    }

    var chapterProgress: Double {
        let duration = currentChapterDuration
        guard duration > 0 else { return 0 }
        return (elapsedTime - currentChapterStart) / duration
    }

    func seekToChapterProgress(_ progress: Double) {
        let clamped = max(0, min(1, progress))
        let time = currentChapterStart + clamped * currentChapterDuration
        seek(to: time)
    }

    private func addTimeObserver() {
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self else { return }
            elapsedTime = time.seconds
            updateCurrentChapter(for: time.seconds)
        }
    }

    private func updateCurrentChapter(for time: TimeInterval) {
        if let index = book.chapters.lastIndex(where: { time >= $0.startTime }) {
            currentChapterIndex = index
        }
    }

    private func seek(to time: TimeInterval) {
        let cmTime = CMTime(seconds: time, preferredTimescale: 1)
        player.seek(to: cmTime)
        elapsedTime = time
        updateCurrentChapter(for: time)
    }
}

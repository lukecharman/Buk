import Foundation
import AVFoundation

@MainActor
final class PlayerViewModel: ObservableObject {
    @Published private(set) var isPlaying = false
    @Published private(set) var currentChapterIndex: Int

    let book: Audiobook
    private let player: AVPlayer

    init(book: Audiobook, startAt index: Int) {
        self.book = book
        self.currentChapterIndex = index
        let url = LibraryViewModel.libraryFolder.appendingPathComponent(book.fileName)
        self.player = AVPlayer(url: url)
        seek(to: book.chapters[index].startTime)
    }

    func togglePlay() {
        if isPlaying { pause() } else { play() }
    }

    func play() {
        player.play()
        isPlaying = true
    }

    func pause() {
        player.pause()
        isPlaying = false
    }

    func nextChapter() {
        guard currentChapterIndex + 1 < book.chapters.count else { return }
        currentChapterIndex += 1
        seek(to: book.chapters[currentChapterIndex].startTime)
    }

    func previousChapter() {
        guard currentChapterIndex > 0 else { return }
        currentChapterIndex -= 1
        seek(to: book.chapters[currentChapterIndex].startTime)
    }

    private func seek(to time: TimeInterval) {
        let cmTime = CMTime(seconds: time, preferredTimescale: 1)
        player.seek(to: cmTime)
    }
}

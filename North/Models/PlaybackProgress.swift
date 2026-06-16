import Foundation

/// Per-book playback progress. Persisted independently from the library so that
/// the library snapshot stays small and progress can be updated frequently.
struct PlaybackProgress: Codable, Hashable {
    let bookID: UUID
    /// Last absolute position in seconds from the start of the book.
    var position: TimeInterval
    /// Most recent chapter index the user was on.
    var chapterIndex: Int
    /// When this progress was last updated.
    var updatedAt: Date
    /// Marked true when the user reaches the end of the book.
    var isFinished: Bool

    static func empty(for id: UUID) -> PlaybackProgress {
        .init(bookID: id, position: 0, chapterIndex: 0, updatedAt: .distantPast, isFinished: false)
    }
}

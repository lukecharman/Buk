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
    /// Indices of chapters the user has actually played through to the end. This is
    /// a true record of completion that does not assume linear listening — jumping
    /// to a later chapter never back-fills earlier ones.
    var completedChapters: Set<Int>
    /// Indices of chapters the user has begun (been positioned in) but not finished.
    /// Used to show an "in-progress" state distinct from untouched chapters.
    var startedChapters: Set<Int>

    init(bookID: UUID,
         position: TimeInterval,
         chapterIndex: Int,
         updatedAt: Date,
         isFinished: Bool,
         completedChapters: Set<Int> = [],
         startedChapters: Set<Int> = []) {
        self.bookID = bookID
        self.position = position
        self.chapterIndex = chapterIndex
        self.updatedAt = updatedAt
        self.isFinished = isFinished
        self.completedChapters = completedChapters
        self.startedChapters = startedChapters
    }

    /// Custom decoding so progress saved before per-chapter tracking still loads:
    /// the two chapter sets default to empty when absent.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        bookID = try c.decode(UUID.self, forKey: .bookID)
        position = try c.decode(TimeInterval.self, forKey: .position)
        chapterIndex = try c.decode(Int.self, forKey: .chapterIndex)
        updatedAt = try c.decode(Date.self, forKey: .updatedAt)
        isFinished = try c.decode(Bool.self, forKey: .isFinished)
        completedChapters = try c.decodeIfPresent(Set<Int>.self, forKey: .completedChapters) ?? []
        startedChapters = try c.decodeIfPresent(Set<Int>.self, forKey: .startedChapters) ?? []
    }

    static func empty(for id: UUID) -> PlaybackProgress {
        .init(bookID: id, position: 0, chapterIndex: 0, updatedAt: .distantPast, isFinished: false)
    }
}

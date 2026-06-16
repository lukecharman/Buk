import XCTest
@testable import North

final class ProgressStoreTests: XCTestCase {
    private var tempURL: URL!

    override func setUp() {
        super.setUp()
        tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("progress-\(UUID().uuidString).json")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempURL)
        super.tearDown()
    }

    func testEmptyProgressForUnknownBook() async {
        let store = ProgressStore(fileURL: tempURL)
        let id = UUID()
        let progress = await store.progress(for: id)
        XCTAssertEqual(progress.bookID, id)
        XCTAssertEqual(progress.position, 0, accuracy: 0.001)
        XCTAssertFalse(progress.isFinished)
    }

    func testUpdateAndPersistProgress() async {
        let store = ProgressStore(fileURL: tempURL)
        let id = UUID()
        let value = PlaybackProgress(bookID: id, position: 42.5, chapterIndex: 2, updatedAt: Date(), isFinished: false)
        await store.update(value)

        // Re-read by creating a fresh store backed by the same URL.
        let other = ProgressStore(fileURL: tempURL)
        let restored = await other.progress(for: id)
        XCTAssertEqual(restored.position, 42.5, accuracy: 0.001)
        XCTAssertEqual(restored.chapterIndex, 2)
        XCTAssertFalse(restored.isFinished)
    }

    func testRemoveProgress() async {
        let store = ProgressStore(fileURL: tempURL)
        let id = UUID()
        await store.update(.init(bookID: id, position: 10, chapterIndex: 0, updatedAt: Date(), isFinished: false))
        await store.remove(bookID: id)
        let restored = await ProgressStore(fileURL: tempURL).progress(for: id)
        XCTAssertEqual(restored.position, 0, accuracy: 0.001)
    }

    func testPersistsChapterSets() async {
        let store = ProgressStore(fileURL: tempURL)
        let id = UUID()
        let value = PlaybackProgress(bookID: id, position: 60, chapterIndex: 3, updatedAt: Date(),
                                     isFinished: false, completedChapters: [0, 2], startedChapters: [3])
        await store.update(value)

        let restored = await ProgressStore(fileURL: tempURL).progress(for: id)
        XCTAssertEqual(restored.completedChapters, [0, 2])
        XCTAssertEqual(restored.startedChapters, [3])
    }

    func testDecodesLegacyProgressWithoutChapterSets() throws {
        // Progress saved before per-chapter tracking has no completed/started keys.
        let legacy = """
        {"bookID":"\(UUID().uuidString)","position":12.5,"chapterIndex":1,\
        "updatedAt":0,"isFinished":false}
        """
        let decoded = try JSONDecoder().decode(PlaybackProgress.self, from: Data(legacy.utf8))
        XCTAssertEqual(decoded.position, 12.5, accuracy: 0.001)
        XCTAssertTrue(decoded.completedChapters.isEmpty)
        XCTAssertTrue(decoded.startedChapters.isEmpty)
    }
}

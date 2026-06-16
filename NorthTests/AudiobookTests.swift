import XCTest
@testable import North

final class AudiobookTests: XCTestCase {
    func testChapterEndTime() {
        let chapter = Audiobook.Chapter(id: UUID(), title: "One", startTime: 30, duration: 120)
        XCTAssertEqual(chapter.endTime, 150, accuracy: 0.01)
    }

    func testChapterIndexLookup() {
        let book = Audiobook(
            id: UUID(),
            title: "Test",
            author: nil,
            narrator: nil,
            fileName: "t.m4b",
            artworkFileName: nil,
            duration: 300,
            source: .importedFile,
            dateAdded: Date(),
            chapters: [
                Audiobook.Chapter(id: UUID(), title: "One", startTime: 0,   duration: 100),
                Audiobook.Chapter(id: UUID(), title: "Two", startTime: 100, duration: 100),
                Audiobook.Chapter(id: UUID(), title: "Three", startTime: 200, duration: 100)
            ]
        )
        XCTAssertEqual(book.chapterIndex(containing: 0), 0)
        XCTAssertEqual(book.chapterIndex(containing: 99), 0)
        XCTAssertEqual(book.chapterIndex(containing: 100), 1)
        XCTAssertEqual(book.chapterIndex(containing: 250), 2)
        XCTAssertEqual(book.chapterIndex(containing: 1_000_000), 2)
    }

    func testChapterIndexLookupWithEmptyChapters() {
        let book = Audiobook(
            id: UUID(), title: "T", author: nil, narrator: nil,
            fileName: "t.m4b", artworkFileName: nil, duration: 0,
            source: .importedFile, dateAdded: Date(), chapters: []
        )
        XCTAssertEqual(book.chapterIndex(containing: 0), 0)
        XCTAssertEqual(book.chapterIndex(containing: 100), 0)
    }

    func testCodableRoundtrip() throws {
        let book = Audiobook(
            id: UUID(),
            title: "Roundtrip",
            author: "Alice",
            narrator: "Bob",
            fileName: "r.m4b",
            artworkFileName: "art.jpg",
            duration: 500,
            source: .librivox,
            dateAdded: Date(timeIntervalSince1970: 1_700_000_000),
            chapters: [Audiobook.Chapter(id: UUID(), title: "Ch", startTime: 0, duration: 500)]
        )
        let data = try JSONEncoder().encode(book)
        let decoded = try JSONDecoder().decode(Audiobook.self, from: data)
        XCTAssertEqual(decoded, book)
    }
}

import XCTest
@testable import Buk

final class BukTests: XCTestCase {
    func testArtworkImageConversion() {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1))
        let image = renderer.image { ctx in
            UIColor.red.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        }
        let data = image.pngData()
        let book = Audiobook(id: UUID(), title: "Test", fileName: "t.m4b", artworkData: data, chapters: [])
        XCTAssertNotNil(book.artworkImage)
    }

    func testPlayerChapterNavigation() {
        let chapters = [
            Audiobook.Chapter(id: UUID(), title: "One", startTime: 0),
            Audiobook.Chapter(id: UUID(), title: "Two", startTime: 10)
        ]
        let book = Audiobook(id: UUID(), title: "Test", fileName: "t.m4b", artworkData: nil, chapters: chapters)
        let vm = PlayerViewModel(book: book, startAt: 0)
        XCTAssertEqual(vm.currentChapterIndex, 0)
        vm.nextChapter()
        XCTAssertEqual(vm.currentChapterIndex, 1)
        vm.previousChapter()
        XCTAssertEqual(vm.currentChapterIndex, 0)
    }

    func testSkipForwardBackward() {
        let chapters = [
            Audiobook.Chapter(id: UUID(), title: "One", startTime: 0),
            Audiobook.Chapter(id: UUID(), title: "Two", startTime: 30)
        ]
        let book = Audiobook(id: UUID(), title: "Test", fileName: "t.m4b", artworkData: nil, chapters: chapters)
        let vm = PlayerViewModel(book: book, startAt: 0)
        XCTAssertEqual(vm.elapsedTime, 0, accuracy: 0.01)
        vm.skipForward15()
        XCTAssertEqual(vm.elapsedTime, 15, accuracy: 0.01)
        vm.skipBackward15()
        XCTAssertEqual(vm.elapsedTime, 0, accuracy: 0.01)
    }
}

import XCTest
@testable import Buk

final class HtmlStripTests: XCTestCase {
    func testStripsTags() {
        XCTAssertEqual("<p>Hello <b>world</b></p>".htmlStripped, "Hello world")
    }
    func testDecodesCommonEntities() {
        XCTAssertEqual("Smith&nbsp;&amp;&nbsp;Sons".htmlStripped, "Smith & Sons")
        XCTAssertEqual("&quot;Hi&quot;".htmlStripped, "\"Hi\"")
        XCTAssertEqual("don&#39;t".htmlStripped, "don't")
    }
    func testTrimsWhitespace() {
        XCTAssertEqual("  hello  ".htmlStripped, "hello")
    }
}

final class CatalogProviderTests: XCTestCase {
    func testLibrivoxProviderIdentity() {
        let p = LibrivoxProvider()
        XCTAssertEqual(p.id, "librivox")
        XCTAssertTrue(p.supportsCategories)
        XCTAssertFalse(p.displayName.isEmpty)
        XCTAssertFalse(p.attribution.isEmpty)
    }
    func testOldTimeRadioProviderIdentity() {
        let p = OldTimeRadioProvider()
        XCTAssertEqual(p.id, "oldTimeRadio")
        XCTAssertTrue(p.supportsCategories)
        XCTAssertFalse(p.displayName.isEmpty)
        XCTAssertFalse(p.attribution.isEmpty)
        XCTAssertTrue(p.browseCategories.contains(.mystery))
        XCTAssertFalse(p.browseCategories.contains(.poetry))
    }

    func testCatalogCategoryTitles() {
        XCTAssertEqual(CatalogCategory.featured.title, "Featured")
        XCTAssertEqual(CatalogCategory.scienceFiction.title, "Science Fiction")
        XCTAssertEqual(Set(CatalogCategory.allCases.map(\.id)).count, CatalogCategory.allCases.count)
    }
}

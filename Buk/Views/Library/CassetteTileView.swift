import SwiftUI

/// A small cassette tile for the library grid — an in-place rendering of a tape
/// with the book's label visible. Tapping the tile pushes the book detail.
struct CassetteTileView: View {
    let book: Audiobook
    let progress: Double
    var transitionNamespace: Namespace.ID? = nil
    /// Hide the matched elements while the detail overlay owns them, so we
    /// don't have two views with the same matched id alive at once.
    var isPresentingDetail: Bool = false

    /// Side length of the (square) book on the row.
    private let bookHeight: CGFloat = 88

    var body: some View {
        HStack(spacing: 14) {
            tapeView
                .frame(width: bookHeight, height: bookHeight)

            VStack(alignment: .leading, spacing: 3) {
                titleText
                if let author = book.author {
                    authorText(author)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            progressBadge
        }
    }

    @ViewBuilder
    private var progressBadge: some View {
        if progress >= 0.99 {
            badge("Finished", color: CassettePalette.lcdGreen)
        } else if progress > 0.01 {
            badge(String(format: "%.0f%%", progress * 100), color: CassettePalette.recordRed)
        }
    }

    // MARK: - Pieces with matched-geometry plumbing

    @ViewBuilder
    private var tapeView: some View {
        let book = BookGraphicView(
            title: self.book.title,
            subtitle: nil,
            cover: self.book.artworkImage(in: LibraryPaths.artworkFolder),
            id: self.book.id,
            openness: 0,
            showsLabelText: true
        )
        if let ns = transitionNamespace, !isPresentingDetail {
            book.matchedGeometryEffect(id: MatchedID.tape(self.book.id), in: ns)
        } else {
            book
        }
    }

    @ViewBuilder
    private var titleText: some View {
        Text(book.title)
            .font(CassetteFont.label(16))
            .lineLimit(2)
    }

    @ViewBuilder
    private func authorText(_ author: String) -> some View {
        Text(author)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .lineLimit(1)
    }

    private func badge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(CassetteFont.counter(10, weight: .bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color, in: Capsule())
            .foregroundStyle(.white)
            .shadow(radius: 2)
    }
}

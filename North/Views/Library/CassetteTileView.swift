import SwiftUI

/// A small cassette tile for the library grid — an in-place rendering of a tape
/// with the book's label visible. Tapping the tile pushes the book detail.
struct CassetteTileView: View {
    let book: Audiobook
    let progress: Double
    @StateObject private var settings = SettingsStore.shared
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
        }
    }

    /// Progress ring drawn around the circular artwork: starts at the top and
    /// fills clockwise to the current fraction. Green when finished, accent
    /// otherwise. Casts a soft shadow down into the artwork.
    @ViewBuilder
    private var progressRing: some View {
        if progress > 0.01 {
            let style: AnyShapeStyle = progress >= 0.99
                ? AnyShapeStyle(CassettePalette.lcdGreen)
                : settings.accentStyle
            Circle()
                .inset(by: 2)
                .trim(from: 0, to: min(progress, 1))
                .stroke(style, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: .black.opacity(0.55), radius: 2.5, x: 0, y: 2)
                .clipShape(Circle())
        }
    }

    // MARK: - Pieces with matched-geometry plumbing

    @ViewBuilder
    private var tapeView: some View {
        let icon = circleArtwork
        if let ns = transitionNamespace, !isPresentingDetail {
            icon.matchedGeometryEffect(id: MatchedID.tape(self.book.id), in: ns)
        } else {
            icon
        }
    }

    /// The book's cover art clipped to a circle, with a progress ring. Shares
    /// `CircleCoverArt` with the detail hero so the zoom morph scales one circle
    /// into the other.
    private var circleArtwork: some View {
        CircleCoverArt(book: book)
            .overlay {
                progressRing
            }
            .shadow(color: .black.opacity(0.15), radius: 3, y: 2)
            .accessibilityLabel(Text(book.title))
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
}

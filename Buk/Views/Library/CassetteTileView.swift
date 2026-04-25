import SwiftUI

/// A small cassette tile for the library grid — an in-place rendering of a tape
/// with the book's label visible. Tapping the tile pushes the book detail.
struct CassetteTileView: View {
    let book: Audiobook
    let progress: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                CassetteDeckView(
                    title: book.title,
                    subtitle: book.author,
                    progress: progress,
                    isPlaying: false,
                    cover: book.artworkImage(in: LibraryPaths.artworkFolder)
                )
                if progress >= 0.99 {
                    badge("Finished", color: CassettePalette.lcdGreen)
                        .padding(8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                } else if progress > 0.01 {
                    badge(String(format: "%.0f%%", progress * 100), color: CassettePalette.recordRed)
                        .padding(8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(book.title)
                    .font(CassetteFont.label(15))
                    .lineLimit(2)
                if let author = book.author {
                    Text(author)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
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

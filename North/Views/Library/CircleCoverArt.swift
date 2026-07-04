import SwiftUI

/// The book's cover art (or a deterministic colour fallback) clipped to a circle
/// with a thin rim. Shared by the library tile and the detail-screen hero so the
/// matched-geometry zoom simply scales one circle up into the other.
///
/// The view is deliberately size-flexible (it fills whatever square frame the
/// caller gives it) rather than pinning an intrinsic size. A rigid inner frame
/// would defeat `matchedGeometryEffect`: the effect animates the frame, but a
/// fixed-size child ignores the shrinking proposal and renders full-size, so the
/// hero would slide/fade in at final size instead of scaling up smoothly.
struct CircleCoverArt: View {
    let book: Audiobook

    var body: some View {
        let coverColor = BookGraphicView.coverColor(for: book.id)
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                GeometryReader { geo in
                    let d = min(geo.size.width, geo.size.height)
                    Group {
                        if let cover = book.artworkImage(in: LibraryPaths.artworkFolder) {
                            cover
                                .resizable()
                                .scaledToFill()
                        } else {
                            ZStack {
                                LinearGradient(
                                    colors: [coverColor.opacity(0.95), coverColor, coverColor.opacity(0.75)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                Image(systemName: "book.closed.fill")
                                    .font(.system(size: d * 0.22, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                        }
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipShape(Circle())
                    .overlay {
                        Circle()
                            .strokeBorder(Color.white.opacity(0.25), lineWidth: 1)
                    }
                }
            }
    }
}

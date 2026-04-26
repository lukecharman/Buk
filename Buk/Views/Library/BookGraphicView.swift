import SwiftUI

/// A simple skeuomorphic book — closed by default, opens by hinging its front
/// cover around the spine to reveal the inside (cover artwork). Cover colour is
/// derived deterministically from `id` so each book in the library has its own
/// stable, hardback-style colour.
///
/// Used on the library tile (always closed) and the library detail screen,
/// where it animates open after the matched-geometry morph settles. The Player
/// view continues to use `CassetteDeckView`.
struct BookGraphicView: View {
    let title: String
    let subtitle: String?
    let cover: Image?
    let id: UUID
    /// 0 = fully closed (front cover flat over the inside), 1 = fully open
    /// (cover swung 150° to the left of the spine, revealing the inside).
    var openness: Double = 0
    /// When false, the title isn't drawn on the front cover — handy for tiny
    /// thumbnails where text would be unreadable.
    var showsLabelText: Bool = true

    /// Width / height of the book at rest. Slightly wider than a typical paperback
    /// so titles fit; same shape regardless of context.
    private let aspect: CGFloat = 0.72

    var body: some View {
        let coverColor = BookGraphicView.coverColor(for: id)
        Color.clear
            .aspectRatio(aspect, contentMode: .fit)
            .overlay {
                GeometryReader { geo in
                    let w = geo.size.width
                    let h = geo.size.height
                    ZStack(alignment: .leading) {
                        insideFace(w: w, h: h, accent: coverColor)
                        spine(w: w, h: h, color: coverColor)
                        frontCover(w: w, h: h, color: coverColor)
                            .rotation3DEffect(
                                .degrees(-150 * openness),
                                axis: (x: 0, y: 1, z: 0),
                                anchor: .leading,
                                anchorZ: 0,
                                perspective: 0.7
                            )
                            .shadow(color: .black.opacity(0.35 * (1 - openness)),
                                    radius: 8,
                                    x: 4 * (1 - openness),
                                    y: 6 * (1 - openness))
                    }
                    .frame(width: w, height: h)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text(title))
    }

    // MARK: - Faces

    /// The front cover — coloured cloth with an inset gilt frame line and the
    /// title in serif type. Hinges from the spine when `openness` increases.
    private func frontCover(w: CGFloat, h: CGFloat, color: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(LinearGradient(
                    colors: [color.opacity(0.95), color, color.opacity(0.78)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing))
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .strokeBorder(Color.white.opacity(0.35), lineWidth: 1)
                .padding(max(6, w * 0.08))
            if showsLabelText {
                VStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: max(9, w * 0.10), weight: .semibold, design: .serif))
                        .foregroundStyle(.white.opacity(0.92))
                        .multilineTextAlignment(.center)
                        .lineLimit(4)
                        .minimumScaleFactor(0.5)
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: max(7, w * 0.06), weight: .regular, design: .serif))
                            .foregroundStyle(.white.opacity(0.7))
                            .lineLimit(1)
                    }
                }
                .padding(max(10, w * 0.12))
            }
        }
        .frame(width: w, height: h)
    }

    /// The inside of the book — cream page colour with the cover artwork
    /// printed on it, revealed when the cover swings open.
    private func insideFace(w: CGFloat, h: CGFloat, accent: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color(red: 0.97, green: 0.94, blue: 0.86))
            if let cover {
                cover
                    .resizable()
                    .scaledToFill()
                    .frame(width: w * 0.78, height: h * 0.82)
                    .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
            } else {
                Image(systemName: "book.closed.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: w * 0.4)
                    .foregroundStyle(accent.opacity(0.35))
            }
        }
        .frame(width: w, height: h)
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
    }

    /// A slightly darker strip down the leading edge so the closed book reads
    /// as bound rather than a flat coloured rectangle.
    private func spine(w: CGFloat, h: CGFloat, color: Color) -> some View {
        Rectangle()
            .fill(color.opacity(0.55))
            .frame(width: max(3, w * 0.04), height: h)
    }

    // MARK: - Cover palette

    /// Curated palette of hardback-cloth colours. Picking from a fixed set
    /// keeps the library shelf looking handsome rather than randomly garish.
    private static let coverColors: [Color] = [
        Color(red: 0.55, green: 0.13, blue: 0.18),  // maroon
        Color(red: 0.13, green: 0.20, blue: 0.43),  // navy
        Color(red: 0.18, green: 0.36, blue: 0.25),  // forest
        Color(red: 0.74, green: 0.52, blue: 0.16),  // ochre
        Color(red: 0.39, green: 0.20, blue: 0.39),  // plum
        Color(red: 0.16, green: 0.44, blue: 0.45),  // teal
        Color(red: 0.45, green: 0.17, blue: 0.27),  // burgundy
        Color(red: 0.30, green: 0.34, blue: 0.40),  // slate
        Color(red: 0.62, green: 0.31, blue: 0.18),  // rust
        Color(red: 0.18, green: 0.42, blue: 0.36)   // emerald
    ]

    static func coverColor(for id: UUID) -> Color {
        let sum = withUnsafeBytes(of: id.uuid) { bytes in
            bytes.reduce(0) { $0 &+ Int($1) }
        }
        return coverColors[abs(sum) % coverColors.count]
    }
}

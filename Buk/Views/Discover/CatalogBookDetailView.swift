import SwiftUI

/// Detail view for a `CatalogBook` shown before downloading. Presents the cover,
/// description, attribution, and a Download button with progress.
///
/// Dismissed by pulling down from the top, not by the system back-swipe — see
/// `SwipeBackDisabler`. As the content is pulled the dismiss `×` indicator
/// fades and grows; releasing past `dismissThreshold` pops the screen.
struct CatalogBookDetailView: View {
    let book: CatalogBook
    @ObservedObject var library: LibraryViewModel
    @ObservedObject var viewModel: DiscoverViewModel
    @Environment(\.dismiss) private var dismiss

    /// How far past the top the user has overscrolled, in points. Updated by
    /// the ScrollView's `onScrollGeometryChange`.
    @State private var pullOffset: CGFloat = 0
    @State private var hasDismissed = false

    private let dismissThreshold: CGFloat = 110

    private var pullProgress: CGFloat {
        min(1, max(0, pullOffset / dismissThreshold))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                AsyncImage(url: book.coverURL) { image in
                    image.resizable().scaledToFit()
                } placeholder: {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(CassettePalette.aluminium.opacity(0.25))
                }
                .frame(maxWidth: 220, maxHeight: 220)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                VStack(spacing: 4) {
                    Text(book.title)
                        .font(CassetteFont.label(22))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    if let author = book.author {
                        Text(author)
                            .foregroundStyle(.secondary)
                    }
                    if let duration = book.durationSeconds {
                        Text(formattedDuration(duration))
                            .font(CassetteFont.counter(13))
                            .foregroundStyle(.secondary)
                    }
                }

                downloadButton

                if !book.genres.isEmpty {
                    genreChips
                }

                if let provider = viewModel.providers.first(where: { $0.id == book.providerID }) {
                    Text(provider.attribution)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                }

                if let description = book.description, !description.isEmpty {
                    Text(description)
                        .font(.body)
                        .padding(.horizontal)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.vertical, 24)
        }
        .scrollBounceBehavior(.always)
        .onScrollGeometryChange(for: CGFloat.self) { geo in
            // Positive when the user has dragged the top of the content below
            // the scroll view's top inset (i.e. an over-scroll bounce).
            max(0, -(geo.contentOffset.y + geo.contentInsets.top))
        } action: { _, new in
            pullOffset = new
        }
        .onScrollPhaseChange { _, phase in
            // Drag has ended (or momentum has settled). Commit the dismiss if
            // the user pulled past the threshold; otherwise the bounce snaps
            // back on its own.
            if phase == .idle, pullOffset >= dismissThreshold, !hasDismissed {
                hasDismissed = true
                dismiss()
            }
        }
        .background(alignment: .top) { dismissIndicator }
        .cassetteBackground()
        .toolbar(.hidden, for: .navigationBar)
        .disableSwipeBack()
    }

    /// The growing `×` shown in the gap that opens when the user pulls down.
    /// Sits behind the scroll content so it's revealed by the over-scroll.
    private var dismissIndicator: some View {
        let p = pullProgress
        return ZStack {
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 56, height: 56)
                .opacity(0.85 * p)
            Image(systemName: "xmark")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(p >= 1 ? CassettePalette.recordRed : .primary)
                .opacity(p)
        }
        .scaleEffect(0.6 + 0.6 * p)
        .padding(.top, 24)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var downloadButton: some View {
        if let progress = library.downloadProgress(for: book.id) {
            VStack(spacing: 8) {
                ProgressView(value: progress)
                Text(String(format: "Downloading… %.0f%%", progress * 100))
                    .font(CassetteFont.counter(13))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 24)
        } else {
            Button {
                Task { await viewModel.download(book, library: library) }
            } label: {
                Label("Download", systemImage: "arrow.down.circle.fill")
                    .font(.headline)
                    .padding(.horizontal, 24).padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            .cassetteGlass(cornerRadius: 22, tint: CassettePalette.recordRed.opacity(0.85))
        }
    }

    @ViewBuilder
    private var genreChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(book.genres, id: \.self) { genre in
                    HStack(spacing: 4) {
                        Text(LibrivoxGenres.emoji(for: genre))
                        Text(genre)
                            .font(.caption)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
                }
            }
            .padding(.horizontal, 24)
        }
    }

    private func formattedDuration(_ seconds: TimeInterval) -> String {
        let h = Int(seconds) / 3600
        let m = (Int(seconds) % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }
}

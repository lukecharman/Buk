import SwiftUI

/// The detail screen for a single audiobook — large cassette graphic, resume button,
/// and a chapter list with per-chapter completion indication.
struct BookDetailView: View {
    let book: Audiobook
    @ObservedObject var library: LibraryViewModel
    @State private var showPlayer = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                CassetteDeckView(
                    title: book.title,
                    subtitle: book.author,
                    progress: progressFraction,
                    isPlaying: false,
                    cover: book.artworkImage(in: LibraryPaths.artworkFolder)
                )
                .padding(.horizontal)

                VStack(spacing: 4) {
                    Text(book.title)
                        .font(CassetteFont.label(24))
                        .multilineTextAlignment(.center)
                    if let author = book.author {
                        Text(author)
                            .foregroundStyle(.secondary)
                    }
                    if let narrator = book.narrator {
                        Text("Narrated by \(narrator)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal)

                metricsRow

                NavigationLink {
                    PlayerView(book: book, library: library)
                } label: {
                    Label(progressFraction > 0.01 ? "Resume" : "Play",
                          systemImage: "play.fill")
                        .font(.headline)
                        .padding(.horizontal, 28).padding(.vertical, 12)
                }
                .buttonStyle(.plain)
                .cassetteGlass(cornerRadius: 22, tint: CassettePalette.recordRed.opacity(0.85))

                ChapterListView(book: book,
                                progress: library.progress(for: book),
                                onSelect: nil)
                    .padding(.horizontal)
            }
            .padding(.vertical, 24)
        }
        .cassetteBackground()
        .navigationTitle(book.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var progressFraction: Double {
        let p = library.progress(for: book)
        guard book.duration > 0 else { return 0 }
        return min(1, max(0, p.position / book.duration))
    }

    @ViewBuilder
    private var metricsRow: some View {
        HStack(spacing: 18) {
            metric("Length", value: formattedHours(book.duration))
            metric("Chapters", value: "\(book.chapters.count)")
            metric("Source", value: sourceLabel)
        }
        .padding(.horizontal)
    }

    private func metric(_ title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.headline)
            Text(title).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .cassetteGlass(cornerRadius: 14)
    }

    private var sourceLabel: String {
        switch book.source {
        case .importedFile: "Files"
        case .librivox: "LibriVox"
        case .internetArchive: "Archive"
        case .bundled: "Bundled"
        }
    }

    private func formattedHours(_ seconds: TimeInterval) -> String {
        let h = Int(seconds) / 3600
        let m = (Int(seconds) % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }
}

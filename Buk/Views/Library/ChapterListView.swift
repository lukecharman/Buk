import SwiftUI

/// A list of chapters for a book, used both as a standalone view (in `BookDetailView`)
/// and as a sheet in the player. Highlights the current chapter and shows finished
/// chapters with a check mark.
struct ChapterListView: View {
    let book: Audiobook
    let progress: PlaybackProgress
    /// If non-nil, tapping a chapter calls this closure (used from the player sheet).
    /// If nil, tapping pushes a `PlayerView` starting at that chapter.
    let onSelect: ((Int) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(book.chapters.enumerated()), id: \.1.id) { index, chapter in
                row(index: index, chapter: chapter)
                if index < book.chapters.count - 1 {
                    Divider().opacity(0.4)
                }
            }
        }
        .padding(.vertical, 4)
        .cassetteGlass(cornerRadius: 16)
    }

    @ViewBuilder
    private func row(index: Int, chapter: Audiobook.Chapter) -> some View {
        Button {
            if let onSelect { onSelect(index) }
        } label: {
            HStack(spacing: 12) {
                Text("\(index + 1)")
                    .font(CassetteFont.counter(13, weight: .bold))
                    .frame(width: 28, alignment: .center)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(chapter.title)
                        .font(.body)
                        .lineLimit(2)
                    Text(formatted(chapter.duration))
                        .font(CassetteFont.counter(11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                trailingIcon(for: index, chapter: chapter)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
            .background(currentBackground(for: index))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Chapter \(index + 1): \(chapter.title)")
    }

    @ViewBuilder
    private func trailingIcon(for index: Int, chapter: Audiobook.Chapter) -> some View {
        if progress.position >= chapter.endTime - 0.5 {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(CassettePalette.lcdGreen)
        } else if index == progress.chapterIndex {
            Image(systemName: "speaker.wave.2.fill")
                .foregroundStyle(CassettePalette.recordRed)
        } else {
            Image(systemName: "chevron.right").foregroundStyle(.tertiary)
        }
    }

    private func currentBackground(for index: Int) -> Color {
        index == progress.chapterIndex ? CassettePalette.recordRed.opacity(0.08) : .clear
    }

    private func formatted(_ seconds: TimeInterval) -> String {
        let total = Int(max(0, seconds))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }
}

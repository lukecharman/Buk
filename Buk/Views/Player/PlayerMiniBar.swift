import SwiftUI

/// Permanent mini-player bar that sits above the tab bar whenever a book is
/// current. Tapping the bar opens the expanded `PlayerSheet`. Has no stop
/// affordance — the only way to clear playback is the Stop button inside
/// the expanded sheet's full detent, which keeps the bar truly undismissable
/// from accidental gestures.
struct PlayerMiniBar: View {
    @ObservedObject var viewModel: PlayerViewModel
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            artwork
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.book.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                if let author = viewModel.book.author {
                    Text(author)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 4)
            playPauseButton
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.white.opacity(0.08), lineWidth: 0.5)
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 4)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Now playing: \(viewModel.book.title). Tap to expand.")
    }

    private var artwork: some View {
        Group {
            if let cover = viewModel.book.artworkImage(in: LibraryPaths.artworkFolder) {
                cover.resizable().scaledToFill()
            } else {
                BookGraphicView(
                    title: viewModel.book.title,
                    subtitle: nil,
                    cover: nil,
                    id: viewModel.book.id,
                    openness: 0,
                    showsLabelText: false
                )
            }
        }
        .frame(width: 44, height: 44)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    private var playPauseButton: some View {
        Button {
            viewModel.togglePlay()
        } label: {
            Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: 18, weight: .heavy))
                .frame(width: 40, height: 40)
        }
        .buttonStyle(.plain)
        .cassetteGlassCircle(tint: CassettePalette.recordRed.opacity(0.85))
        .accessibilityLabel(viewModel.isPlaying ? "Pause" : "Play")
        // Stop tap-through to the parent so the play/pause button doesn't
        // accidentally expand the sheet.
        .simultaneousGesture(TapGesture())
    }
}

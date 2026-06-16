import SwiftUI

/// The five-button transport row of a tape deck — previous, skip back, play, skip
/// forward, next. Skip-back/forward labels show the user's chosen interval.
struct TransportControlsView: View {
    @ObservedObject var viewModel: PlayerViewModel
    @StateObject private var settings = SettingsStore.shared

    var body: some View {
        HStack(spacing: 18) {
            cassetteButton(systemImage: "backward.end.fill", size: .small) {
                viewModel.previousChapter()
            }
            .accessibilityLabel("Previous chapter")
            .disabled(viewModel.book.chapters.isEmpty)

            skipButton(seconds: settings.skipBackSeconds, forward: false)

            cassetteButton(systemImage: viewModel.isPlaying ? "pause.fill" : "play.fill",
                            size: .large,
                            tint: settings.accent.opacity(0.85)) {
                viewModel.togglePlay()
            }
            .accessibilityLabel(viewModel.isPlaying ? "Pause" : "Play")

            skipButton(seconds: settings.skipForwardSeconds, forward: true)

            cassetteButton(systemImage: "forward.end.fill", size: .small) {
                viewModel.nextChapter()
            }
            .accessibilityLabel("Next chapter")
            .disabled(viewModel.book.chapters.isEmpty || viewModel.currentChapterIndex >= viewModel.book.chapters.count - 1)
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private func skipButton(seconds: Int, forward: Bool) -> some View {
        Button {
            forward ? viewModel.skipForward() : viewModel.skipBackward()
        } label: {
            ZStack {
                Image(systemName: forward ? "goforward" : "gobackward")
                    .font(.system(size: 30, weight: .semibold))
                Text("\(seconds)")
                    .font(CassetteFont.counter(11, weight: .bold))
                    .offset(y: 1)
            }
            .frame(width: 56, height: 56)
        }
        .buttonStyle(.plain)
        .cassetteGlassCircle()
        .accessibilityLabel(forward ? "Skip forward \(seconds) seconds" : "Skip back \(seconds) seconds")
    }

    @ViewBuilder
    private func cassetteButton(systemImage: String,
                                size: ButtonSize,
                                tint: Color? = nil,
                                action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: size.iconSize, weight: .heavy))
                .frame(width: size.dimension, height: size.dimension)
        }
        .buttonStyle(.plain)
        .cassetteGlassCircle(tint: tint)
    }

    private enum ButtonSize {
        case small, large
        var dimension: CGFloat { self == .large ? 78 : 52 }
        var iconSize: CGFloat { self == .large ? 32 : 22 }
    }
}

import SwiftUI

/// Scrubber bar — allows dragging through the entire book and shows the elapsed and
/// remaining times in monospaced "tape counter" type.
struct ScrubberView: View {
    @ObservedObject var viewModel: PlayerViewModel
    @StateObject private var settings = SettingsStore.shared
    @State private var dragFraction: Double?
    @State private var isDragging = false

    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { proxy in
                let width = proxy.size.width
                let fraction = dragFraction ?? viewModel.bookFraction
                let knobX = max(0, min(width, width * fraction))

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(CassettePalette.aluminium.opacity(0.35))
                        .frame(height: 6)
                    Capsule()
                        .fill(settings.accent)
                        .frame(width: knobX, height: 6)
                    Circle()
                        .fill(.white)
                        .overlay(Circle().strokeBorder(CassettePalette.charcoal.opacity(0.35), lineWidth: 1))
                        .frame(width: 18, height: 18)
                        .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
                        .offset(x: knobX - 9)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            isDragging = true
                            let f = max(0, min(1, value.location.x / width))
                            dragFraction = f
                        }
                        .onEnded { value in
                            let f = max(0, min(1, value.location.x / width))
                            viewModel.seek(toBookFraction: f)
                            dragFraction = nil
                            isDragging = false
                        }
                )
                .accessibilityElement()
                .accessibilityLabel("Playback position")
                .accessibilityValue(formatted(viewModel.elapsedTime))
                .accessibilityAdjustableAction { direction in
                    let delta: TimeInterval = direction == .increment ? 30 : -30
                    viewModel.seek(to: viewModel.elapsedTime + delta)
                }
            }
            .frame(height: 24)

            HStack {
                Text(formatted(displayedElapsed))
                    .font(CassetteFont.counter(13))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("-" + formatted(viewModel.book.duration - displayedElapsed))
                    .font(CassetteFont.counter(13))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
    }

    private var displayedElapsed: TimeInterval {
        if let dragFraction { return dragFraction * viewModel.book.duration }
        return viewModel.elapsedTime
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

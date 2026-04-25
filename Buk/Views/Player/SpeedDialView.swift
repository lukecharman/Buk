import SwiftUI

/// Cassette-deck inspired playback speed control. Surfaces the standard set of
/// allowed rates and updates `PlayerViewModel.playbackRate`.
struct SpeedDialView: View {
    @ObservedObject var viewModel: PlayerViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Speed")
                    .font(CassetteFont.counter(13, weight: .bold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(String(format: "%.2f×", viewModel.playbackRate))
                    .font(CassetteFont.counter(15, weight: .bold))
                    .foregroundStyle(.primary)
                    .monospacedDigit()
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(SettingsStore.allowedRates, id: \.self) { rate in
                        Button {
                            viewModel.playbackRate = rate
                        } label: {
                            Text(rateLabel(rate))
                                .font(CassetteFont.counter(13, weight: .semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                        .cassetteGlass(cornerRadius: 14,
                                       tint: abs(rate - viewModel.playbackRate) < 0.001
                                            ? CassettePalette.recordRed.opacity(0.7)
                                            : nil)
                        .accessibilityLabel("Playback speed \(rateLabel(rate))")
                    }
                }
            }
        }
        .padding(.horizontal)
    }

    private func rateLabel(_ rate: Double) -> String {
        rate == floor(rate) ? String(format: "%.0f×", rate) : String(format: "%.2f×", rate)
    }
}

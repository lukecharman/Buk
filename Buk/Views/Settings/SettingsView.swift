import SwiftUI

struct SettingsView: View {
    @StateObject private var settings = SettingsStore.shared

    var body: some View {
        NavigationStack {
            Form {
                Section("Skip intervals") {
                    Picker("Skip back", selection: $settings.skipBackSeconds) {
                        ForEach(SettingsStore.allowedSkipValues, id: \.self) { value in
                            Text("\(value) seconds").tag(value)
                        }
                    }
                    Picker("Skip forward", selection: $settings.skipForwardSeconds) {
                        ForEach(SettingsStore.allowedSkipValues, id: \.self) { value in
                            Text("\(value) seconds").tag(value)
                        }
                    }
                }
                Section("Playback") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Default speed")
                            Spacer()
                            Text(rateLabel(settings.defaultPlaybackRate))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                        HStack(spacing: 12) {
                            Image(systemName: "tortoise.fill")
                                .foregroundStyle(.secondary)
                                .accessibilityHidden(true)

                            Slider(
                                value: $settings.defaultPlaybackRate,
                                in: 0.5...2.5,
                                step: 0.05
                            )
                            .accessibilityLabel("Default playback speed")
                            .accessibilityValue(rateLabel(settings.defaultPlaybackRate))

                            Image(systemName: "hare.fill")
                                .foregroundStyle(.secondary)
                                .accessibilityHidden(true)
                        }
                    }
                    Toggle("Auto-play next chapter", isOn: $settings.autoPlayNextChapter)
                }
                Section("Appearance") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Tint")
                        HStack(spacing: 12) {
                            ForEach(AppTint.allCases) { tint in
                                Button {
                                    settings.appTint = tint
                                } label: {
                                    Circle()
                                        .fill(tint.color)
                                        .frame(width: 30, height: 30)
                                        .overlay {
                                            Circle()
                                                .strokeBorder(.primary, lineWidth: settings.appTint == tint ? 2.5 : 0)
                                        }
                                        .overlay {
                                            if settings.appTint == tint {
                                                Image(systemName: "checkmark")
                                                    .font(.caption2.weight(.bold))
                                                    .foregroundStyle(.white)
                                            }
                                        }
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(tint.displayName)
                                .accessibilityAddTraits(settings.appTint == tint ? [.isSelected] : [])
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.vertical, 4)
                }
                Section("About") {
                    HStack { Text("Version"); Spacer(); Text(Bundle.main.shortVersion).foregroundStyle(.secondary) }
                    Link("LibriVox", destination: URL(string: "https://librivox.org")!)
                    Link("Internet Archive", destination: URL(string: "https://archive.org")!)
                    Text("Buk respects your privacy. Books and progress are stored on this device.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .scrollContentBackground(.hidden)
            .cassetteBackground()
            .navigationTitle("Settings")
        }
    }

    private func rateLabel(_ rate: Double) -> String {
        rate == floor(rate) ? String(format: "%.0f×", rate) : String(format: "%.2f×", rate)
    }
}

private extension Bundle {
    var shortVersion: String {
        (infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0"
    }
}

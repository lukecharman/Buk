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
                    Picker("Default speed", selection: $settings.defaultPlaybackRate) {
                        ForEach(SettingsStore.allowedRates, id: \.self) { rate in
                            Text(rate == floor(rate) ? String(format: "%.0f×", rate)
                                                     : String(format: "%.2f×", rate))
                                .tag(rate)
                        }
                    }
                    Toggle("Auto-play next chapter", isOn: $settings.autoPlayNextChapter)
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
}

private extension Bundle {
    var shortVersion: String {
        (infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0"
    }
}

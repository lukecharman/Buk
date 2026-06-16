import SwiftUI

/// Full-screen Now Playing view, shown as the content of the dedicated
/// "Now Playing" tab while a book is current. Owns the long-lived
/// `PlayerViewModel` so playback persists across tab switches.
struct NowPlayingView: View {
    @ObservedObject var viewModel: PlayerViewModel
    @ObservedObject var library: LibraryViewModel
    @StateObject private var settings = SettingsStore.shared

    @State private var showSleepSheet = false
    @State private var showChaptersSheet = false
    @State private var showSpeedPopover = false

    init(viewModel: PlayerViewModel, library: LibraryViewModel) {
        _viewModel = ObservedObject(wrappedValue: viewModel)
        _library = ObservedObject(wrappedValue: library)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    artwork(size: 240)
                    titleAuthor
                    ScrubberView(viewModel: viewModel)
                        .padding(.horizontal, -16)
                    TransportControlsView(viewModel: viewModel)
                    supplementaryRow
                }
                .padding(.horizontal, 24)
                .padding(.top, 18)
                .padding(.bottom, 36)
                .frame(maxWidth: .infinity)
            }
            .cassetteBackground()
            .navigationTitle("Now Playing")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onDisappear { /* keep viewModel alive across tab switches */ }
        .sheet(isPresented: $showSleepSheet) {
            sleepTimerSheet.presentationDetents([.medium])
        }
        .sheet(isPresented: $showChaptersSheet) {
            chaptersSheet
        }
        .alert("Playback error",
               isPresented: Binding(get: { viewModel.playbackError != nil },
                                    set: { if !$0 { viewModel.playbackError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(viewModel.playbackError ?? "") }
    }

    // MARK: - Pieces

    private func artwork(size: CGFloat) -> some View {
        Group {
            if let cover = viewModel.book.artworkImage(in: LibraryPaths.artworkFolder) {
                cover
                    .resizable()
                    .scaledToFill()
            } else {
                BookGraphicView(
                    title: viewModel.book.title,
                    subtitle: viewModel.book.author,
                    cover: nil,
                    id: viewModel.book.id,
                    openness: 0,
                    showsLabelText: true
                )
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: max(6, size * 0.06), style: .continuous))
        .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
    }

    private var titleAuthor: some View {
        VStack(spacing: 4) {
            Text(viewModel.book.title)
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)
                .lineLimit(2)
            if let author = viewModel.book.author {
                Text(author)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            if let chapter = viewModel.currentChapter {
                Text(chapter.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private var supplementaryRow: some View {
        HStack(spacing: 12) {
            Button {
                showSleepSheet = true
            } label: {
                Label(sleepLabel, systemImage: "moon.zzz.fill")
                    .padding(.horizontal, 14).padding(.vertical, 10)
            }
            .buttonStyle(.plain)
            .cassetteGlass(cornerRadius: 14)

            Button {
                showChaptersSheet = true
            } label: {
                Label("Chapters", systemImage: "list.bullet")
                    .padding(.horizontal, 14).padding(.vertical, 10)
            }
            .buttonStyle(.plain)
            .cassetteGlass(cornerRadius: 14)

            speedMenu
        }
    }

    private var speedMenu: some View {
        Button {
            showSpeedPopover = true
        } label: {
            Label(rateLabel(viewModel.playbackRate), systemImage: "gauge.with.dots.needle.67percent")
                .monospacedDigit()
                .padding(.horizontal, 14).padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .cassetteGlass(cornerRadius: 14)
        .accessibilityLabel("Playback speed \(rateLabel(viewModel.playbackRate))")
        .popover(isPresented: $showSpeedPopover, arrowEdge: .top) {
            speedSlider
                .presentationCompactAdaptation(.popover)
        }
    }

    private var speedSlider: some View {
        VStack(spacing: 12) {
            Text(rateLabel(viewModel.playbackRate))
                .font(.title3.weight(.semibold))
                .monospacedDigit()

            HStack(spacing: 12) {
                Image(systemName: "tortoise.fill")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)

                Slider(
                    value: $viewModel.playbackRate,
                    in: 0.5...2.5,
                    step: 0.05
                )
                .accessibilityLabel("Playback speed")
                .accessibilityValue(rateLabel(viewModel.playbackRate))

                Image(systemName: "hare.fill")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
        }
        .padding(20)
        .frame(minWidth: 280)
    }

    private func rateLabel(_ rate: Double) -> String {
        rate == floor(rate) ? String(format: "%.0f×", rate) : String(format: "%.2f×", rate)
    }

    private var sleepLabel: String {
        guard let remaining = viewModel.sleepTimerRemaining else { return "Sleep" }
        let mins = max(0, Int(remaining.rounded(.up))) / 60
        let secs = max(0, Int(remaining.rounded(.up))) % 60
        return String(format: "Sleep %d:%02d", mins, secs)
    }

    // MARK: - Inner sheets

    private var sleepTimerSheet: some View {
        NavigationStack {
            List {
                ForEach(SettingsStore.allowedSleepTimers, id: \.self) { minutes in
                    Button {
                        viewModel.setSleepTimer(minutes: minutes)
                        showSleepSheet = false
                    } label: {
                        HStack {
                            Text(minutes == 0 ? "Off" : "\(minutes) minutes")
                            Spacer()
                            if minutes == 0 && viewModel.sleepTimerRemaining == nil {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Sleep Timer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showSleepSheet = false }
                }
            }
        }
    }

    private var chaptersSheet: some View {
        NavigationStack {
            ChapterListView(book: viewModel.book,
                            progress: library.progress(for: viewModel.book),
                            onSelect: { index in
                                viewModel.jumpToChapter(at: index)
                                showChaptersSheet = false
                            })
                .padding()
                .navigationTitle("Chapters")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { showChaptersSheet = false }
                    }
                }
        }
    }
}

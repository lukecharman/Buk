import SwiftUI

/// Multi-detent player sheet. Always presented while a book is current and
/// fully undismissable — the only way to clear playback is the Stop button
/// inside the full detent.
///
/// Three detents:
///   * `bar`   – horizontal mini-player bar (artwork, title/author, play/pause)
///   * `mid`   – artwork, title/author, scrubber, full transport row
///   * `full`  – everything plus speed dial, sleep timer, chapters, and Stop
///
/// The `bar` detent is sized to sit just above the system tab bar; the host
/// uses `presentationBackgroundInteraction(.enabled(upThrough: barDetent))`
/// so the tab bar stays tappable while the bar is showing.
struct PlayerSheet: View {
    @ObservedObject var viewModel: PlayerViewModel
    @ObservedObject var library: LibraryViewModel
    @StateObject private var settings = SettingsStore.shared
    @Binding var detent: PresentationDetent
    let onStop: () -> Void

    @State private var showSleepSheet = false
    @State private var showChaptersSheet = false

    static let barDetent: PresentationDetent = .height(72)
    static let midDetent: PresentationDetent = .fraction(0.55)

    var body: some View {
        Group {
            if detent == Self.barDetent {
                barBody
            } else if detent == .large {
                fullBody
            } else {
                midBody
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.clear.cassetteBackground())
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

    // MARK: - Layouts

    /// Smallest detent. A horizontal mini-player strip sized to sit above the
    /// system tab bar. Tapping anywhere outside the play/pause button expands
    /// the sheet to `mid`.
    private var barBody: some View {
        HStack(spacing: 12) {
            artwork(size: 44)
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
            // Stop tap-through to the row so play/pause doesn't expand the sheet.
            .simultaneousGesture(TapGesture())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                detent = Self.midDetent
            }
        }
    }

    /// Default detent. Big enough for the artwork, scrubber and full transport
    /// row without scrolling.
    private var midBody: some View {
        VStack(spacing: 18) {
            artwork(size: 180)
            titleAuthor
            ScrubberView(viewModel: viewModel)
                .padding(.horizontal, -16)
            TransportControlsView(viewModel: viewModel)
        }
        .padding(.horizontal, 24)
        .padding(.top, 18)
    }

    /// Full-screen detent. Adds speed dial, sleep / chapter buttons, and the
    /// Stop button.
    private var fullBody: some View {
        ScrollView {
            VStack(spacing: 22) {
                artwork(size: 280)
                titleAuthor
                ScrubberView(viewModel: viewModel)
                    .padding(.horizontal, -16)
                TransportControlsView(viewModel: viewModel)
                SpeedDialView(viewModel: viewModel)
                supplementaryRow
                stopButton
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 36)
        }
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
        }
    }

    /// The deliberate, only-on-full-detent escape hatch from playback. Pauses
    /// then signals the host to drop the current player.
    private var stopButton: some View {
        Button(role: .destructive) {
            viewModel.pause()
            onStop()
        } label: {
            Label("Stop Playback", systemImage: "stop.fill")
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 18).padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .cassetteGlass(cornerRadius: 14)
        .padding(.top, 8)
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

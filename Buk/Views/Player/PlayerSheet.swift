import SwiftUI

/// Expanded player sheet — opened by tapping the always-on `PlayerMiniBar`.
///
/// Two detents:
///   * `mid`   – artwork, title/author, scrubber, full transport row
///   * `full`  – everything plus speed dial, sleep timer, chapters, and the
///               Stop button (the only way to fully end playback)
///
/// While `viewModel.isPlaying` is true the sheet is interactively
/// undismissable — users must pause first to swipe it back to the mini bar.
struct PlayerSheet: View {
    @ObservedObject var viewModel: PlayerViewModel
    @ObservedObject var library: LibraryViewModel
    @StateObject private var settings = SettingsStore.shared
    @Binding var detent: PresentationDetent
    let onStop: () -> Void

    @State private var showSleepSheet = false
    @State private var showChaptersSheet = false

    static let midDetent: PresentationDetent = .fraction(0.55)

    var body: some View {
        Group {
            if detent == .large {
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

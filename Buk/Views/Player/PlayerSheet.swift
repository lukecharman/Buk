import SwiftUI

/// Bottom-sheet player. Replaces the old skeuomorphic `WalkmanPlayerView`.
///
/// Lives for as long as `LibraryViewModel.presentingPlayerBook` is non-nil.
/// Has three detents:
///   * `mini`  – a single-line bar (artwork, title, play/pause)
///   * `mid`   – artwork, title/author, scrubber, full transport row
///   * `full`  – everything plus speed control, sleep timer, chapters
///
/// Background interaction is allowed up to and including `mid`, so the user
/// can browse the rest of the app while the sheet is parked. Swiping down
/// past `mini` dismisses the sheet entirely (and tears down playback).
struct PlayerSheet: View {
    @StateObject private var viewModel: PlayerViewModel
    @ObservedObject var library: LibraryViewModel
    @StateObject private var settings = SettingsStore.shared
    @Binding var detent: PresentationDetent

    @State private var showSleepSheet = false
    @State private var showChaptersSheet = false

    static let miniDetent: PresentationDetent = .height(96)
    static let midDetent: PresentationDetent = .fraction(0.55)

    init(book: Audiobook,
         library: LibraryViewModel,
         detent: Binding<PresentationDetent>) {
        _viewModel = StateObject(wrappedValue: PlayerViewModel(book: book, library: library))
        _library = ObservedObject(wrappedValue: library)
        _detent = detent
    }

    var body: some View {
        Group {
            if detent == Self.miniDetent {
                miniBody
            } else if detent == .large {
                fullBody
            } else {
                midBody
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.clear.cassetteBackground())
        .onDisappear { viewModel.tearDown() }
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

    /// Compact one-row bar, designed to clear the tab bar with room to breathe.
    /// Tapping anywhere on it expands the sheet to `mid`.
    private var miniBody: some View {
        HStack(spacing: 12) {
            artwork(size: 56)
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
            playPauseButton(size: 44)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                detent = Self.midDetent
            }
        }
    }

    /// The default detent. Big enough for the artwork, scrubber and full
    /// transport row without scrolling.
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

    /// Full-screen detent. Adds the speed dial and access to sleep / chapters.
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
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 36)
        }
    }

    // MARK: - Pieces

    /// Square cover image when the book has artwork; otherwise a closed
    /// `BookGraphicView` so the look stays consistent with the library.
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

    private func playPauseButton(size: CGFloat) -> some View {
        Button {
            viewModel.togglePlay()
        } label: {
            Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: size * 0.45, weight: .heavy))
                .frame(width: size, height: size)
        }
        .buttonStyle(.plain)
        .cassetteGlassCircle(tint: CassettePalette.recordRed.opacity(0.85))
        .accessibilityLabel(viewModel.isPlaying ? "Pause" : "Play")
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

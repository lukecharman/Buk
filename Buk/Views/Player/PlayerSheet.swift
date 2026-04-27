import SwiftUI

/// Multi-detent player sheet. Presented when the user taps the dedicated
/// "Now Playing" tab in the tab bar.
///
/// Two detents:
///   * `mid`   – artwork, title/author, scrubber, full transport row
///   * `full`  – everything plus speed dial, sleep timer, chapters, and the
///               Stop button (the only way to fully end playback)
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
        GeometryReader { proxy in
            let h = proxy.size.height
            // Full extras (speed dial / sleep / chapters / Stop) bloom in once
            // the sheet pushes past the mid layout's natural height.
            let fullExtraOpacity = Self.opacityRising(in: 420...560, height: h)
            expandedBody(fullExtraOpacity: fullExtraOpacity)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
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

    /// Single expanded layout used for both mid and full detents. The artwork
    /// grows with available height and the speed dial / supplementary row /
    /// Stop button cross-fade in once the sheet pushes past mid.
    private func expandedBody(fullExtraOpacity: Double) -> some View {
        GeometryReader { proxy in
            let h = proxy.size.height
            // Artwork grows from ~150 at mid to ~280 at full, capped to a
            // sensible portion of the available height.
            let artworkSize = min(280, max(150, h * 0.42))

            ScrollView {
                VStack(spacing: 22) {
                    artwork(size: artworkSize)
                    titleAuthor
                    ScrubberView(viewModel: viewModel)
                        .padding(.horizontal, -16)
                    TransportControlsView(viewModel: viewModel)

                    // Cross-faded extras — kept in the layout so the bloom
                    // stays in sync with the sheet's own resize.
                    VStack(spacing: 22) {
                        SpeedDialView(viewModel: viewModel)
                        supplementaryRow
                        stopButton
                    }
                    .opacity(fullExtraOpacity)
                    .scaleEffect(0.95 + 0.05 * fullExtraOpacity, anchor: .top)
                    .allowsHitTesting(fullExtraOpacity > 0.5)
                }
                .padding(.horizontal, 24)
                .padding(.top, 18)
                .padding(.bottom, 36)
                .frame(maxWidth: .infinity)
            }
            .scrollDisabled(h < 560)
        }
    }

    // MARK: - Easing helpers

    /// 0 → 1 across `range`.
    private static func opacityRising(in range: ClosedRange<CGFloat>, height: CGFloat) -> Double {
        let t = (height - range.lowerBound) / (range.upperBound - range.lowerBound)
        return Double(clamp(t, 0, 1))
    }

    private static func clamp(_ x: CGFloat, _ lo: CGFloat, _ hi: CGFloat) -> CGFloat {
        min(hi, max(lo, x))
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

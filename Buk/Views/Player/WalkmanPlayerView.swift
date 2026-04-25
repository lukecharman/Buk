import SwiftUI

/// A skeuomorphic Walkman-style player. Slides in from the right of the screen
/// over a blurred backdrop. The cassette rotates 90° as it loads into the slot
/// and starts spinning when playback begins. Transport buttons live on the
/// device itself (right side); supporting controls (scrubber, speed, sleep
/// timer, chapters, close) sit on the left over the blurred background.
struct WalkmanPlayerView: View {
    @StateObject private var viewModel: PlayerViewModel
    @ObservedObject var library: LibraryViewModel
    @StateObject private var settings = SettingsStore.shared
    let onClose: () -> Void

    @State private var deckOffset: CGFloat = 800
    @State private var cassetteRotation: Angle = .zero
    @State private var cassetteInsertion: CGFloat = -1.0 // -1 = above slot, 0 = inserted
    @State private var showSleepTimerSheet = false
    @State private var showChaptersSheet = false

    init(book: Audiobook, library: LibraryViewModel, onClose: @escaping () -> Void) {
        _library = ObservedObject(wrappedValue: library)
        _viewModel = StateObject(wrappedValue: PlayerViewModel(book: book, library: library))
        self.onClose = onClose
    }

    var body: some View {
        ZStack {
            backdrop

            GeometryReader { proxy in
                let isCompact = proxy.size.width < 520
                let deckWidth = min(max(proxy.size.width * (isCompact ? 0.55 : 0.45), 220), 360)

                HStack(alignment: .top, spacing: 16) {
                    leftPanel
                        .frame(maxWidth: .infinity, alignment: .leading)

                    walkmanDeck(width: deckWidth)
                        .frame(width: deckWidth)
                        .offset(x: deckOffset)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 24)
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
            }
        }
        .task { await runEntryAnimation() }
        .onDisappear { viewModel.tearDown() }
        .alert("Playback error",
               isPresented: Binding(get: { viewModel.playbackError != nil },
                                    set: { if !$0 { viewModel.playbackError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(viewModel.playbackError ?? "") }
        .sheet(isPresented: $showSleepTimerSheet) {
            SleepTimerSheet(viewModel: viewModel)
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showChaptersSheet) {
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
            }
        }
    }

    // MARK: - Backdrop

    private var backdrop: some View {
        Rectangle()
            .fill(.black.opacity(0.35))
            .background(.ultraThinMaterial)
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .onTapGesture { dismissAnimated() }
    }

    // MARK: - Left panel

    private var leftPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Button {
                    dismissAnimated()
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 16, weight: .bold))
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                .cassetteGlassCircle()
                .accessibilityLabel("Close player")

                Spacer()
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Now Playing")
                    .font(CassetteFont.counter(11, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(.secondary)
                Text(viewModel.currentChapter?.title ?? viewModel.book.title)
                    .font(CassetteFont.label(20))
                    .lineLimit(2)
                if let author = viewModel.book.author {
                    Text(author)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            ScrubberView(viewModel: viewModel)
                .padding(.horizontal, -16) // ScrubberView already adds horizontal padding
            SpeedDialView(viewModel: viewModel)
                .padding(.horizontal, -16)

            HStack(spacing: 10) {
                Button {
                    showSleepTimerSheet = true
                } label: {
                    Label(sleepTimerLabel, systemImage: "moon.zzz.fill")
                        .font(.subheadline)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                .cassetteGlass(cornerRadius: 14)

                Button {
                    showChaptersSheet = true
                } label: {
                    Label("Chapters", systemImage: "list.bullet")
                        .font(.subheadline)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                .cassetteGlass(cornerRadius: 14)
            }

            Spacer(minLength: 0)
        }
    }

    private var sleepTimerLabel: String {
        if let remaining = viewModel.sleepTimerRemaining {
            let mins = max(0, Int(remaining.rounded(.up))) / 60
            let secs = max(0, Int(remaining.rounded(.up))) % 60
            return String(format: "Sleep %d:%02d", mins, secs)
        }
        return "Sleep timer"
    }

    // MARK: - Walkman device

    private func walkmanDeck(width: CGFloat) -> some View {
        // Geometry: a tall portrait device. The cassette is loaded vertically
        // (rotated 90°) into a slot at the top.
        let bodyW = width
        let bodyH = bodyW * 1.85
        let slotW = bodyW * 0.74
        // A horizontal cassette is 1 : 0.62. Rotated 90°, the visible bounding
        // box is 0.62 : 1, so the slot height for a given visible cassette
        // width is slotW / 0.62.
        let slotH = slotW / 0.62

        return ZStack {
            walkmanShell(width: bodyW, height: bodyH)

            VStack(spacing: 0) {
                cassetteSlot(width: bodyW, slotW: slotW, slotH: slotH)
                    .padding(.top, bodyW * 0.06)

                lcdReadout(width: bodyW)
                    .padding(.top, bodyW * 0.05)
                    .padding(.horizontal, bodyW * 0.10)

                Spacer(minLength: 0)

                transportRow(width: bodyW)
                    .padding(.bottom, bodyW * 0.10)
                    .padding(.horizontal, bodyW * 0.06)

                brandStrip(width: bodyW)
                    .padding(.bottom, bodyW * 0.05)
            }
            .frame(width: bodyW, height: bodyH)
        }
        .frame(width: bodyW, height: bodyH)
        .shadow(color: .black.opacity(0.45), radius: 26, x: -8, y: 18)
    }

    private func walkmanShell(width: CGFloat, height: CGFloat) -> some View {
        let r = width * 0.10
        return RoundedRectangle(cornerRadius: r, style: .continuous)
            .fill(
                LinearGradient(colors: [
                    Color(red: 0.30, green: 0.32, blue: 0.36),
                    Color(red: 0.18, green: 0.19, blue: 0.22),
                    Color(red: 0.10, green: 0.11, blue: 0.13)
                ], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .overlay(
                RoundedRectangle(cornerRadius: r, style: .continuous)
                    .fill(LinearGradient(colors: [.white.opacity(0.18), .clear],
                                         startPoint: .top, endPoint: .center))
                    .blendMode(.plusLighter)
                    .padding(1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: r, style: .continuous)
                    .strokeBorder(.white.opacity(0.12), lineWidth: 0.8)
            )
    }

    private func cassetteSlot(width bodyW: CGFloat, slotW: CGFloat, slotH: CGFloat) -> some View {
        // The slot is a recessed window. The cassette starts above the slot
        // (cassetteInsertion = -1) and slides down into it (= 0) once rotated.
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.black.opacity(0.85))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(.black, lineWidth: 1)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(LinearGradient(colors: [.black.opacity(0.6), .clear],
                                             startPoint: .top, endPoint: .center))
                        .blendMode(.multiply)
                )
                .frame(width: slotW + 14, height: slotH + 14)

            // The cassette itself. CassetteDeckView lays out at its natural
            // landscape aspect; we give it a frame matching the *unrotated*
            // size that, after rotating 90°, fills the slot.
            CassetteDeckView(
                title: viewModel.book.title,
                subtitle: viewModel.book.author,
                progress: viewModel.bookFraction,
                isPlaying: viewModel.isPlaying,
                cover: viewModel.book.artworkImage(in: LibraryPaths.artworkFolder)
            )
            .frame(width: slotH, height: slotW)
            .rotationEffect(cassetteRotation)
            .frame(width: slotW, height: slotH)
            .offset(y: cassetteInsertion * (slotH * 0.55 + 24))
        }
        .frame(width: slotW + 14, height: slotH + 14)
    }

    private func lcdReadout(width: CGFloat) -> some View {
        let elapsed = viewModel.elapsedTime
        let remaining = max(0, viewModel.book.duration - elapsed)
        return HStack(spacing: 8) {
            Circle()
                .fill(viewModel.isPlaying ? CassettePalette.recordRed : CassettePalette.recordRed.opacity(0.25))
                .frame(width: 8, height: 8)
                .shadow(color: viewModel.isPlaying ? CassettePalette.recordRed : .clear, radius: 4)
            Text(viewModel.isPlaying ? "▶ PLAY" : "❚❚ PAUSE")
                .font(CassetteFont.counter(10, weight: .bold))
                .foregroundStyle(CassettePalette.lcdGreen)
            Spacer()
            Text(format(elapsed) + " / -" + format(remaining))
                .font(CassetteFont.counter(10, weight: .bold))
                .foregroundStyle(CassettePalette.lcdGreen)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color(red: 0.06, green: 0.10, blue: 0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .strokeBorder(.black, lineWidth: 0.5)
                )
        )
    }

    private func transportRow(width: CGFloat) -> some View {
        // Two rows of chunky push-buttons.
        let buttonW = width * 0.18
        let buttonH = buttonW * 0.95
        return VStack(spacing: 8) {
            HStack(spacing: 6) {
                walkmanButton(systemImage: "backward.end.fill", width: buttonW, height: buttonH) {
                    viewModel.previousChapter()
                }
                .accessibilityLabel("Previous chapter")
                .disabled(viewModel.book.chapters.isEmpty)

                walkmanButton(systemImage: "gobackward", width: buttonW, height: buttonH,
                              corner: "\(settings.skipBackSeconds)") {
                    viewModel.skipBackward()
                }
                .accessibilityLabel("Skip back \(settings.skipBackSeconds) seconds")

                walkmanButton(systemImage: "gobackward",
                              width: buttonW, height: buttonH,
                              hidden: true) { }
                    .opacity(0)

                walkmanButton(systemImage: "goforward", width: buttonW, height: buttonH,
                              corner: "\(settings.skipForwardSeconds)") {
                    viewModel.skipForward()
                }
                .accessibilityLabel("Skip forward \(settings.skipForwardSeconds) seconds")

                walkmanButton(systemImage: "forward.end.fill", width: buttonW, height: buttonH) {
                    viewModel.nextChapter()
                }
                .accessibilityLabel("Next chapter")
                .disabled(viewModel.book.chapters.isEmpty || viewModel.currentChapterIndex >= viewModel.book.chapters.count - 1)
            }

            walkmanButton(systemImage: viewModel.isPlaying ? "pause.fill" : "play.fill",
                          width: width * 0.66, height: buttonH * 1.1,
                          tint: CassettePalette.recordRed.opacity(0.85)) {
                viewModel.togglePlay()
            }
            .accessibilityLabel(viewModel.isPlaying ? "Pause" : "Play")
        }
    }

    @ViewBuilder
    private func walkmanButton(systemImage: String,
                               width: CGFloat,
                               height: CGFloat,
                               corner: String? = nil,
                               tint: Color? = nil,
                               hidden: Bool = false,
                               action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(
                        LinearGradient(colors: [
                            Color(red: 0.55, green: 0.55, blue: 0.58),
                            Color(red: 0.32, green: 0.32, blue: 0.34)
                        ], startPoint: .top, endPoint: .bottom)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(.black.opacity(0.6), lineWidth: 0.7)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(LinearGradient(colors: [.white.opacity(0.45), .clear],
                                                 startPoint: .top, endPoint: .center))
                            .blendMode(.plusLighter)
                            .padding(1)
                    )
                    .overlay(
                        tint.map { color in
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(color)
                                .blendMode(.multiply)
                        }
                    )
                Image(systemName: systemImage)
                    .font(.system(size: min(width, height) * 0.42, weight: .heavy))
                    .foregroundStyle(.black.opacity(0.8))
                if let corner {
                    Text(corner)
                        .font(CassetteFont.counter(9, weight: .bold))
                        .foregroundStyle(.black.opacity(0.7))
                        .padding(3)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                }
            }
            .frame(width: width, height: height)
            .shadow(color: .black.opacity(0.45), radius: 2, y: 2)
        }
        .buttonStyle(.plain)
        .opacity(hidden ? 0 : 1)
    }

    private func brandStrip(width: CGFloat) -> some View {
        VStack(spacing: 1) {
            Text("BUKMAN")
                .font(CassetteFont.transport(width * 0.12))
                .foregroundStyle(.white.opacity(0.85))
                .tracking(2)
            Text("STEREO CASSETTE PLAYER")
                .font(CassetteFont.counter(width * 0.034, weight: .bold))
                .tracking(1.5)
                .foregroundStyle(.white.opacity(0.5))
        }
    }

    // MARK: - Animation

    private func runEntryAnimation() async {
        // Initial state: deck off-screen right, cassette horizontal above the slot.
        deckOffset = 800
        cassetteRotation = .zero
        cassetteInsertion = -1.0

        withAnimation(.spring(response: 0.55, dampingFraction: 0.85)) {
            deckOffset = 0
        }
        try? await Task.sleep(nanoseconds: 500_000_000)
        withAnimation(.easeInOut(duration: 0.45)) {
            cassetteRotation = .degrees(90)
        }
        try? await Task.sleep(nanoseconds: 500_000_000)
        withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
            cassetteInsertion = 0
        }
    }

    private func dismissAnimated() {
        withAnimation(.easeInOut(duration: 0.25)) {
            cassetteInsertion = -1.0
        }
        withAnimation(.easeIn(duration: 0.35).delay(0.15)) {
            deckOffset = 800
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            onClose()
        }
    }

    private func format(_ seconds: TimeInterval) -> String {
        let total = Int(max(0, seconds))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }
}

private struct SleepTimerSheet: View {
    @ObservedObject var viewModel: PlayerViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(SettingsStore.allowedSleepTimers, id: \.self) { minutes in
                    Button {
                        viewModel.setSleepTimer(minutes: minutes)
                        dismiss()
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
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

import SwiftUI

/// The detail screen for a single audiobook — large cassette graphic, resume button,
/// and a chapter list with per-chapter completion indication.
///
/// Designed to be presented as a full-bleed overlay (not a navigation push) so
/// that `matchedGeometryEffect` ids can bridge the source row in the Library
/// and the cassette/title/author in the detail view, all in the same view
/// hierarchy.
struct BookDetailView: View {
    let book: Audiobook
    @ObservedObject var library: LibraryViewModel
    let transitionNamespace: Namespace.ID?
    /// External close trigger — when this token changes, run our dismiss
    /// animation. Lets the parent's toolbar button drive the same fade/morph
    /// as if the user had tapped a local close control.
    let closeRequest: UUID?
    let onClose: () -> Void

    /// Drives the title/author slide-down + fade-in after the cassette enter
    /// morph has settled. On dismiss we run this in reverse with a blur.
    @State private var titleVisible = false
    /// Drives the metrics / Play / chapters block sliding up from the bottom
    /// after the title has appeared. Reverses on dismiss.
    @State private var detailsVisible = false
    /// Fades the opaque detail background in during the enter morph and back
    /// out on dismiss, so the blurred/scaled library underneath is visible
    /// while the cassette is travelling.
    @State private var backgroundVisible = false
    /// While true, the cassette carries its matched-geometry ID. We turn this
    /// off once the enter morph has settled so the matched system isn't
    /// tracking the cassette's frame every render — that frame tracking is
    /// what was making the drag jank.
    @State private var matchActive = true

    /// Live horizontal translation while the user is dragging right to dismiss.
    @State private var dragX: CGFloat = 0
    /// Direction lock for the active touch: once we know which axis the user
    /// is on, we commit to it so vertical scrolling and horizontal dismiss
    /// don't fight each other.
    @State private var dragAxis: DragAxis?

    private enum DragAxis { case horizontal, vertical }

    /// Distance the title block sits "behind" the tape before it slides down.
    private let titleSlideDistance: CGFloat = 70
    /// How far the user must drag right to commit to a dismiss.
    private let dismissThreshold: CGFloat = 120

    init(book: Audiobook,
         library: LibraryViewModel,
         transitionNamespace: Namespace.ID? = nil,
         closeRequest: UUID? = nil,
         onClose: @escaping () -> Void = {}) {
        self.book = book
        self._library = ObservedObject(wrappedValue: library)
        self.transitionNamespace = transitionNamespace
        self.closeRequest = closeRequest
        self.onClose = onClose
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            cassetteBackgroundFill
                .ignoresSafeArea()
                .opacity(backgroundVisible ? 1 : 0)

            VStack(spacing: 20) {
                cassette
                    .padding(.horizontal)
                    .padding(.top, 56)
                    // Render on top so the title block can slide out from
                    // behind it on enter / tuck back behind it on dismiss.
                    .zIndex(1)

                titleBlock
                    .offset(y: titleVisible ? 0 : -titleSlideDistance)
                    .opacity(titleVisible ? 1 : 0)
                    .blur(radius: titleVisible ? 0 : 18)
                    .zIndex(0)

                detailsBlock
                    .opacity(detailsVisible ? 1 : 0)
                    .offset(y: detailsVisible ? 0 : 60)
                    .blur(radius: detailsVisible ? 0 : 12)
            }
            .offset(x: max(0, dragX))
            .opacity(1 - min(0.4, max(0, dragX) / 600))
            .simultaneousGesture(dismissDrag)
            .task {
                // Fade the opaque background in alongside the matched-geometry
                // morph so the recede/blur on the library underneath is
                // visible while the cassette travels.
                withAnimation(.easeOut(duration: 0.45)) {
                    backgroundVisible = true
                }
                // Wait for the matched-geometry zoom to settle, then slide the
                // title/author down from behind the tape.
                try? await Task.sleep(nanoseconds: 350_000_000)
                withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                    titleVisible = true
                }
                // Drop the matched ID now that the enter morph is done. While
                // at rest, the cassette is just a regular view — drags don't
                // fight the matched-geometry frame tracker.
                try? await Task.sleep(nanoseconds: 200_000_000)
                matchActive = false
                // Bring the rest of the detail content up after the title has
                // landed.
                withAnimation(.spring(response: 0.55, dampingFraction: 0.85)) {
                    detailsVisible = true
                }
            }
            .onChange(of: closeRequest) { _, newValue in
                guard newValue != nil else { return }
                closeAnimated()
            }
        }
    }

    // MARK: - Pieces

    @ViewBuilder
    private var cassette: some View {
        let deck = CassetteDeckView(
            title: book.title,
            subtitle: book.author,
            progress: progressFraction,
            isPlaying: false,
            cover: book.artworkImage(in: LibraryPaths.artworkFolder),
            showsLabelText: false
        )
        if let ns = transitionNamespace, matchActive {
            deck.matchedGeometryEffect(id: MatchedID.tape(book.id), in: ns)
        } else {
            deck
        }
    }

    private var titleBlock: some View {
        VStack(spacing: 4) {
            Text(book.title)
                .font(CassetteFont.label(24))
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
            if let author = book.author {
                Text(author)
                    .foregroundStyle(.secondary)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let narrator = book.narrator {
                Text("Narrated by \(narrator)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
    }

    /// The metrics row, Play/Resume button, and chapter list. Slides up from
    /// the bottom after the title has appeared, and reverses on close.
    private var detailsBlock: some View {
        ScrollView {
            VStack(spacing: 20) {
                metricsRow

                Button {
                    library.presentingPlayerBook = book
                } label: {
                    Label(progressFraction > 0.01 ? "Resume" : "Play",
                          systemImage: "play.fill")
                        .font(.headline)
                        .padding(.horizontal, 28).padding(.vertical, 12)
                }
                .buttonStyle(.plain)
                .cassetteGlass(cornerRadius: 22, tint: CassettePalette.recordRed.opacity(0.85))

                ChapterListView(book: book,
                                progress: library.progress(for: book),
                                onSelect: nil)
                    .padding(.horizontal)
            }
            .padding(.top, 4)
            .padding(.bottom, 32)
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollDisabled(dragAxis == .horizontal)
    }

    @ViewBuilder
    private var metricsRow: some View {
        HStack(spacing: 18) {
            metric("Length", value: formattedHours(book.duration))
            metric("Chapters", value: "\(book.chapters.count)")
            metric("Source", value: sourceLabel)
        }
        .padding(.horizontal)
    }

    private func metric(_ title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.headline)
            Text(title).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .cassetteGlass(cornerRadius: 14)
    }

    private var sourceLabel: String {
        switch book.source {
        case .importedFile: "Files"
        case .librivox: "LibriVox"
        case .internetArchive: "Old-Time Radio"
        case .bundled: "Bundled"
        }
    }

    private func formattedHours(_ seconds: TimeInterval) -> String {
        let h = Int(seconds) / 3600
        let m = (Int(seconds) % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }

    /// Animate every dismiss-time effect in one go: title blurring back behind
    /// the tape, the background fading out, and (via the parent's withAnimation
    /// in `onClose`) the cassette morphing home — all in a single transaction
    /// so the screen comes apart in one motion rather than two stages.
    private func closeAnimated() {
        // Re-arm the matched ID synchronously (no animation), so the parent's
        // morph driven by `onClose` has a destination to morph back from.
        matchActive = true
        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
            titleVisible = false
            detailsVisible = false
            backgroundVisible = false
        }
        onClose()
    }

    /// Horizontal swipe-from-anywhere to dismiss back to the library. Tracks
    /// the finger live and commits if the user passes the threshold or flicks.
    private var dismissDrag: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if dragAxis == nil {
                    let dx = abs(value.translation.width)
                    let dy = abs(value.translation.height)
                    guard max(dx, dy) > 6 else { return }
                    // Only treat as a dismiss swipe if it starts from the left
                    // edge of the screen, like the system back gesture.
                    let fromEdge = value.startLocation.x <= 24
                    dragAxis = (fromEdge && dx > dy) ? .horizontal : .vertical
                }
                guard dragAxis == .horizontal, value.translation.width > 0 else { return }
                dragX = value.translation.width
            }
            .onEnded { value in
                let wasHorizontal = dragAxis == .horizontal
                dragAxis = nil
                guard wasHorizontal else { return }
                let committed = value.translation.width > dismissThreshold
                    || value.predictedEndTranslation.width > 240
                if committed {
                    closeAnimated()
                } else {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        dragX = 0
                    }
                }
            }
    }

    private var cassetteBackgroundFill: some View {
        Color.clear.cassetteBackground()
    }

    private var progressFraction: Double {
        let p = library.progress(for: book)
        guard book.duration > 0 else { return 0 }
        return min(1, max(0, p.position / book.duration))
    }
}

/// Stable, namespaced ids so the source row and detail screen agree on which
/// element matches which. Only the tape id is currently used — title/author
/// no longer use matched geometry; they slide down from behind the tape.
enum MatchedID {
    static func tape(_ id: UUID) -> String { "tape-\(id.uuidString)" }
}

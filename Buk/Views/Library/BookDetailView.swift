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
    let onClose: () -> Void

    /// Drives the title/author slide-down + fade-in after the cassette enter
    /// morph has settled. On dismiss we run this in reverse with a blur.
    @State private var titleVisible = false
    /// While true, the cassette carries its matched-geometry ID. We turn this
    /// off once the enter morph has settled so the matched system isn't
    /// tracking the cassette's frame every render — that frame tracking is
    /// what was making the drag jank.
    @State private var matchActive = true
    /// Live drag distance during a gesture. `@GestureState` resets to zero
    /// automatically when the gesture ends, and updates without triggering a
    /// full state-mutation rebuild cycle each frame.
    @GestureState private var dragTranslation: CGFloat = 0
    /// Persists the drag distance after the gesture ends so we can spring it
    /// back to zero (or hand off to dismiss).
    @State private var settledDragOffset: CGFloat = 0

    private var dragOffset: CGFloat { dragTranslation + settledDragOffset }

    /// Drag distance at which a release will dismiss the screen.
    private let dismissThreshold: CGFloat = 120
    /// Distance the title block sits "behind" the tape before it slides down.
    private let titleSlideDistance: CGFloat = 70

    init(book: Audiobook,
         library: LibraryViewModel,
         transitionNamespace: Namespace.ID? = nil,
         onClose: @escaping () -> Void = {}) {
        self.book = book
        self._library = ObservedObject(wrappedValue: library)
        self.transitionNamespace = transitionNamespace
        self.onClose = onClose
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            cassetteBackgroundFill
                .ignoresSafeArea()

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

                Spacer(minLength: 0)
            }
            .offset(y: dragOffset)
            .animation(nil, value: dragTranslation)
            .simultaneousGesture(dragToDismiss)
            .task {
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
            }

            closeButton
                .padding(.horizontal, 16)
                .padding(.top, 12)
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

    private var closeButton: some View {
        Button(action: closeAnimated) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .overlay(Circle().strokeBorder(.white.opacity(0.15), lineWidth: 0.5))
                Image(systemName: "chevron.down")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
            }
            .frame(width: 40, height: 40)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Close")
    }

    /// Blur the title block back behind the tape, then re-arm matched geometry
    /// and hand off to the parent for the cassette morph back to the row.
    private func closeAnimated() {
        withAnimation(.easeIn(duration: 0.22)) {
            titleVisible = false
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 220_000_000)
            // Re-arm the matched ID so the parent's withAnimation morphs the
            // cassette back to the row instead of just fading.
            matchActive = true
            try? await Task.sleep(nanoseconds: 16_000_000)
            onClose()
        }
    }

    // MARK: - Drag-to-dismiss

    private var dragToDismiss: some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .local)
            .updating($dragTranslation) { value, state, transaction in
                // Disable any ambient animation so the offset tracks the
                // finger 1:1 instead of being interpolated each frame.
                transaction.animation = nil
                let raw = value.translation.height
                state = raw > 0 ? raw : raw / 6
            }
            .onEnded { value in
                let projected = value.predictedEndTranslation.height
                if projected > dismissThreshold || value.translation.height > dismissThreshold {
                    // User has physically pulled the cassette away — fade
                    // dismiss without re-arming the matched morph (otherwise
                    // the cassette would yank back up before morphing).
                    settledDragOffset = value.translation.height
                    onClose()
                } else {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                        settledDragOffset = 0
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

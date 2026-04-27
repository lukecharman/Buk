import SwiftUI

/// Owns the `PlayerViewModel` for the lifetime of playback and renders the
/// multi-detent `PlayerSheet`. Lives inside `.sheet(item:)`, keyed by book
/// id, so switching books spins up a fresh view-model.
struct PlayerSheetContainer: View {
    @StateObject private var viewModel: PlayerViewModel
    @ObservedObject var library: LibraryViewModel

    @State private var detent: PresentationDetent = PlayerSheet.barDetent

    let onStop: () -> Void

    init(book: Audiobook, library: LibraryViewModel, onStop: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: PlayerViewModel(book: book, library: library))
        _library = ObservedObject(wrappedValue: library)
        self.onStop = onStop
    }

    var body: some View {
        PlayerSheet(
            viewModel: viewModel,
            library: library,
            detent: $detent,
            onStop: {
                onStop()
            }
        )
        .presentationDetents(
            [PlayerSheet.barDetent, PlayerSheet.midDetent, .large],
            selection: $detent
        )
        // Tab bar stays interactive while the sheet sits at the bar detent.
        .presentationBackgroundInteraction(.enabled(upThrough: PlayerSheet.barDetent))
        .presentationDragIndicator(detent == PlayerSheet.barDetent ? .hidden : .visible)
        .presentationContentInteraction(.scrolls)
        // The sheet is the player — it's only ever cleared by the Stop button
        // inside the full detent, never by a swipe-down.
        .interactiveDismissDisabled(true)
        .onDisappear { viewModel.tearDown() }
    }
}

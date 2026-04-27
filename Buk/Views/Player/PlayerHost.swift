import SwiftUI

/// Owns the `PlayerViewModel` for the currently-playing book, renders the
/// always-on mini bar (intended for a `safeAreaInset`), and presents the
/// expanded `PlayerSheet` when the bar is tapped.
///
/// Lifecycle: created when `LibraryViewModel.presentingPlayerBook` becomes
/// non-nil, torn down when it goes back to nil. The expanded sheet can come
/// and go (collapsing it returns to the mini bar) without affecting playback.
struct PlayerHost: View {
    @StateObject private var viewModel: PlayerViewModel
    @ObservedObject var library: LibraryViewModel

    @State private var isExpanded = false
    @State private var sheetDetent: PresentationDetent = PlayerSheet.midDetent

    let onStop: () -> Void

    init(book: Audiobook, library: LibraryViewModel, onStop: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: PlayerViewModel(book: book, library: library))
        _library = ObservedObject(wrappedValue: library)
        self.onStop = onStop
    }

    var body: some View {
        PlayerMiniBar(viewModel: viewModel) {
            sheetDetent = PlayerSheet.midDetent
            isExpanded = true
        }
        .onDisappear { viewModel.tearDown() }
        .sheet(isPresented: $isExpanded) {
            PlayerSheet(
                viewModel: viewModel,
                library: library,
                detent: $sheetDetent,
                onStop: {
                    isExpanded = false
                    onStop()
                }
            )
            .presentationDetents([PlayerSheet.midDetent, .large], selection: $sheetDetent)
            .presentationDragIndicator(.visible)
            .presentationContentInteraction(.scrolls)
            // Undismissable while audio is playing — the user must pause
            // first to swipe the sheet back down to the mini bar.
            .interactiveDismissDisabled(viewModel.isPlaying)
        }
    }
}

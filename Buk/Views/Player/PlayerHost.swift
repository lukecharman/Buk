import SwiftUI

/// Invisible host that owns the long-lived `PlayerViewModel` for a single
/// book. Lives for as long as the book is the current "now playing" entry,
/// so the expanded `PlayerSheet` can come and go (collapse / re-expand)
/// without tearing playback down.
struct PlayerHost: View {
    @StateObject private var viewModel: PlayerViewModel
    @ObservedObject var library: LibraryViewModel

    @Binding var isExpanded: Bool
    @State private var detent: PresentationDetent = PlayerSheet.midDetent

    let onStop: () -> Void

    init(
        book: Audiobook,
        library: LibraryViewModel,
        isExpanded: Binding<Bool>,
        onStop: @escaping () -> Void
    ) {
        _viewModel = StateObject(wrappedValue: PlayerViewModel(book: book, library: library))
        _library = ObservedObject(wrappedValue: library)
        _isExpanded = isExpanded
        self.onStop = onStop
    }

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .allowsHitTesting(false)
            .onDisappear { viewModel.tearDown() }
            .sheet(isPresented: $isExpanded) {
                PlayerSheet(
                    viewModel: viewModel,
                    library: library,
                    detent: $detent,
                    onStop: onStop
                )
                .presentationDetents(
                    [PlayerSheet.midDetent, .large],
                    selection: $detent
                )
                .presentationDragIndicator(.visible)
                .presentationContentInteraction(.scrolls)
            }
    }
}

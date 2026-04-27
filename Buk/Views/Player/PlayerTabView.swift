import SwiftUI

/// Content of the Player tab. Shows `NowPlayingView` when a book is current,
/// otherwise an empty-state prompting the user to pick something to play.
struct PlayerTabView: View {
    @ObservedObject var library: LibraryViewModel
    let onPickFromLibrary: () -> Void
    let onStop: () -> Void

    var body: some View {
        if let book = library.presentingPlayerBook {
            NowPlayingView(book: book, library: library, onStop: onStop)
                .id(book.id)
        } else {
            NavigationStack {
                EmptyPlayerView(onPickFromLibrary: onPickFromLibrary)
                    .cassetteBackground()
                    .navigationTitle("Player")
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
    }
}

private struct EmptyPlayerView: View {
    let onPickFromLibrary: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "headphones")
                .font(.system(size: 64, weight: .regular))
                .foregroundStyle(.secondary)
            Text("Nothing playing")
                .font(CassetteFont.label(22))
            Text("Pick a book from your library to start listening.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)
            Button {
                onPickFromLibrary()
            } label: {
                Label("Open Library", systemImage: "books.vertical.fill")
                    .padding(.horizontal, 18).padding(.vertical, 10)
            }
            .buttonStyle(.plain)
            .cassetteGlass(cornerRadius: 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

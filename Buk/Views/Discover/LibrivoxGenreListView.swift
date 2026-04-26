import SwiftUI

/// "Browse by Genre" landing screen for the LibriVox provider — shows the full
/// genre vocabulary grouped into sensible sections. Tapping a genre pushes a
/// `LibrivoxGenreBooksView` that lazy-loads books for that genre.
struct LibrivoxGenreListView: View {
    @ObservedObject var library: LibraryViewModel
    @ObservedObject var viewModel: DiscoverViewModel

    var body: some View {
        List {
            ForEach(LibrivoxGenres.groups) { group in
                Section(group.title) {
                    ForEach(group.genres, id: \.self) { genre in
                        NavigationLink {
                            LibrivoxGenreBooksView(genre: genre,
                                                   library: library,
                                                   viewModel: viewModel)
                        } label: {
                            Text(genre)
                        }
                        .listRowBackground(Color.clear)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .cassetteBackground()
        .navigationTitle("Genres")
        .navigationBarTitleDisplayMode(.inline)
    }
}

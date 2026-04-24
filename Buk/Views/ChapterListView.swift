import SwiftUI

struct ChapterListView: View {
    let book: Audiobook

    var body: some View {
        List {
            if book.chapters.isEmpty {
                NavigationLink("Play") {
                    PlayerView(book: book, startIndex: 0)
                }
            } else {
                ForEach(Array(book.chapters.enumerated()), id: \.1.id) { index, chapter in
                    NavigationLink(chapter.title) {
                        PlayerView(book: book, startIndex: index)
                    }
                }
            }
        }
        .navigationTitle(book.title)
    }
}

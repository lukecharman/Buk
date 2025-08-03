import SwiftUI

struct ChapterListView: View {
    let book: Audiobook

    var body: some View {
        List {
            ForEach(Array(book.chapters.enumerated()), id: \.1.id) { index, chapter in
                NavigationLink(chapter.title) {
                    PlayerView(book: book, startIndex: index)
                }
            }
        }
        .navigationTitle(book.title)
    }
}

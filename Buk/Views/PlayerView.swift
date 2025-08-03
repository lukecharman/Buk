import SwiftUI

struct PlayerView: View {
    @StateObject private var viewModel: PlayerViewModel

    init(book: Audiobook, startIndex: Int) {
        _viewModel = StateObject(wrappedValue: PlayerViewModel(book: book, startAt: startIndex))
    }

    var body: some View {
        VStack(spacing: 20) {
            if let image = viewModel.book.artworkImage {
                image
                    .resizable()
                    .scaledToFit()
                    .frame(height: 200)
            }
            Text(viewModel.book.title).font(.title)
            Text(viewModel.book.chapters[viewModel.currentChapterIndex].title)
            HStack(spacing: 40) {
                Button(action: viewModel.previousChapter) {
                    Image(systemName: "backward.end.fill")
                }.disabled(viewModel.currentChapterIndex == 0)

                Button(action: viewModel.togglePlay) {
                    Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                        .font(.largeTitle)
                }

                Button(action: viewModel.nextChapter) {
                    Image(systemName: "forward.end.fill")
                }.disabled(viewModel.currentChapterIndex == viewModel.book.chapters.count - 1)
            }
        }
        .padding()
    }
}

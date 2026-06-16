import SwiftUI

/// Vertical card used in the Discover browse rows.
struct CatalogBookCard: View {
    let book: CatalogBook
    @ObservedObject var library: LibraryViewModel
    @ObservedObject var viewModel: DiscoverViewModel

    var body: some View {
        NavigationLink {
            CatalogBookDetailView(book: book, library: library, viewModel: viewModel)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                AsyncImage(url: book.coverURL) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    coverPlaceholder
                }
                .frame(width: 160, height: 160)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(.white.opacity(0.15), lineWidth: 0.5)
                )

                Text(book.title)
                    .font(CassetteFont.label(14))
                    .lineLimit(2)
                    .foregroundStyle(.primary)
                if let author = book.author {
                    Text(author)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var coverPlaceholder: some View {
        ZStack {
            CassettePalette.aluminium.opacity(0.25)
            Image(systemName: "books.vertical")
                .font(.title)
                .foregroundStyle(.secondary)
        }
    }
}

/// Row used in search results.
struct CatalogBookRow: View {
    let book: CatalogBook
    @ObservedObject var library: LibraryViewModel
    @ObservedObject var viewModel: DiscoverViewModel

    var body: some View {
        NavigationLink {
            CatalogBookDetailView(book: book, library: library, viewModel: viewModel)
        } label: {
            HStack(spacing: 12) {
                AsyncImage(url: book.coverURL) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Color.secondary.opacity(0.2)
                }
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(book.title)
                        .font(.body)
                        .lineLimit(2)
                    if let author = book.author {
                        Text(author)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
                if let progress = library.downloadProgress(for: book.id) {
                    ProgressView(value: progress).frame(width: 60)
                } else {
                    Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}

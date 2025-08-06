import Combine
import Foundation

@MainActor
final class LibrivoxViewModel: ObservableObject {
    @Published var query: String = ""
    @Published private(set) var books: [LibrivoxBook] = []
    @Published var isLoading = false

    func search() async {
        guard !query.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        let term = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        guard let url = URL(string: "https://librivox.org/api/feed/audiobooks?format=json&title=\(term)") else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(LibrivoxResponse.self, from: data)
            books = response.books
        } catch {
            books = []
        }
    }

    func download(_ book: LibrivoxBook, library: LibraryViewModel) async {
        do {
            let (metaData, _) = try await URLSession.shared.data(from: book.metadataURL)
            let archive = try JSONDecoder().decode(ArchiveMetadata.self, from: metaData)
            guard let file = archive.files.first(where: { $0.name.hasSuffix(".m4b") }),
                  let url = URL(string: file.name, relativeTo: book.downloadBaseURL) else { return }
            let (tempURL, _) = try await URLSession.shared.download(from: url)
            try await library.importBook(from: tempURL)
        } catch {
            // handle errors silently for now
        }
    }
}

private struct ArchiveMetadata: Decodable {
    struct File: Decodable { let name: String }
    let files: [File]
}

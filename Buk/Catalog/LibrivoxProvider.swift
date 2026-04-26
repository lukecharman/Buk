import Foundation

/// LibriVox catalog provider — searches the LibriVox API and resolves the underlying
/// Internet Archive `.m4b` file for download. LibriVox audiobooks are public domain.
///
/// API reference: https://librivox.org/api/info
nonisolated struct LibrivoxProvider: CatalogProvider {
    let id = "librivox"
    let displayName = "LibriVox"
    let attribution = "Public domain · LibriVox volunteers"
    let supportsCategories = true

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - CatalogProvider

    func search(query: String, limit: Int) async throws -> [CatalogBook] {
        var components = URLComponents(string: "https://librivox.org/api/feed/audiobooks")!
        components.queryItems = [
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "title", value: query),
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "extended", value: "1")
        ]
        return try await fetchBooks(at: components.url!)
    }

    func books(in category: CatalogCategory, limit: Int) async throws -> [CatalogBook] {
        var components = URLComponents(string: "https://librivox.org/api/feed/audiobooks")!
        var items: [URLQueryItem] = [
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "extended", value: "1")
        ]
        switch category {
        case .featured, .popular:
            // LibriVox doesn't have a popularity endpoint; "completed" books, sorted by
            // newest, gives a reasonable Featured experience without slowing the UI.
            items.append(URLQueryItem(name: "status", value: "complete"))
        case .fiction:
            items.append(URLQueryItem(name: "genre", value: "Fiction"))
        case .nonFiction:
            items.append(URLQueryItem(name: "genre", value: "Non-fiction"))
        case .childrens:
            items.append(URLQueryItem(name: "genre", value: "Children"))
        case .poetry:
            items.append(URLQueryItem(name: "genre", value: "Poetry"))
        case .mystery:
            items.append(URLQueryItem(name: "genre", value: "Mystery"))
        case .scienceFiction:
            items.append(URLQueryItem(name: "genre", value: "Science Fiction"))
        // Categories that aren't part of LibriVox's browse list — return nothing
        // so a misrouted request degrades gracefully instead of crashing.
        case .comedy, .drama, .western, .horror:
            return []
        }
        components.queryItems = items
        return try await fetchBooks(at: components.url!)
    }

    func resolveDownloadURL(for book: CatalogBook) async throws -> URL {
        if let direct = book.downloadHandle.directURL { return direct }
        let identifier = book.downloadHandle.identifier
        let metadataURL = URL(string: "https://archive.org/metadata/\(identifier)")!
        let (data, _) = try await session.data(from: metadataURL)
        let metadata = try JSONDecoder().decode(ArchiveMetadata.self, from: data)
        // Prefer 64kb m4b (LibriVox's standard distribution), falling back to any m4b.
        let preferred = metadata.files.first { $0.name.lowercased().hasSuffix("_64kb.m4b") }
            ?? metadata.files.first { $0.name.lowercased().hasSuffix(".m4b") }
        guard let file = preferred else {
            throw CatalogError.noDownloadableFile
        }
        return URL(string: "https://archive.org/download/\(identifier)/\(file.name)")!
    }

    // MARK: - Networking

    private func fetchBooks(at url: URL) async throws -> [CatalogBook] {
        let (data, response) = try await session.data(from: url)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw CatalogError.badStatus(http.statusCode)
        }
        let decoded = try JSONDecoder().decode(LibrivoxResponse.self, from: data)
        return decoded.books.compactMap(map(_:))
    }

    private func map(_ book: LibrivoxAPIBook) -> CatalogBook? {
        guard let archiveURL = URL(string: book.url_iarchive ?? "") else { return nil }
        let identifier = archiveURL.lastPathComponent
        let coverURL = URL(string: "https://archive.org/services/img/\(identifier)")
        let author = book.authors?.compactMap { author -> String? in
            let parts = [author.first_name, author.last_name].compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            let joined = parts.filter { !$0.isEmpty }.joined(separator: " ")
            return joined.isEmpty ? nil : joined
        }.joined(separator: ", ")
        let duration = book.totaltimesecs.flatMap { TimeInterval(exactly: $0) }
        return CatalogBook(
            id: "\(id):\(book.id)",
            title: book.title,
            author: (author?.isEmpty == false) ? author : nil,
            narrator: nil,
            description: book.description?.htmlStripped,
            durationSeconds: duration,
            coverURL: coverURL,
            providerID: id,
            downloadHandle: .init(identifier: identifier, directURL: nil, providerID: id)
        )
    }
}

// MARK: - Wire types

private struct LibrivoxResponse: Decodable {
    let books: [LibrivoxAPIBook]
}

private struct LibrivoxAPIBook: Decodable {
    // LibriVox returns numeric fields as JSON strings (e.g. "id": "47"),
    // so decode as String to avoid a typeMismatch that would fail the whole feed.
    let id: String
    let title: String
    let description: String?
    let url_iarchive: String?
    let url_zip: String?
    let totaltimesecs: Int?
    let authors: [Author]?

    struct Author: Decodable {
        let first_name: String?
        let last_name: String?
    }
}

private struct ArchiveMetadata: Decodable {
    struct File: Decodable { let name: String }
    let files: [File]
}

// MARK: - Helpers

extension String {
    /// Quick-and-tidy HTML strip used to clean up LibriVox descriptions for display.
    var htmlStripped: String {
        let withoutTags = replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        return withoutTags
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum CatalogError: LocalizedError {
    case badStatus(Int)
    case noDownloadableFile

    var errorDescription: String? {
        switch self {
        case .badStatus(let code): return "Server returned status \(code)."
        case .noDownloadableFile: return "Couldn't find a downloadable audiobook file."
        }
    }
}

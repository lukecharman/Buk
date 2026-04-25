import Foundation

/// Internet Archive provider — direct catalog search using `archive.org/advancedsearch.php`.
/// Useful for finding audiobooks beyond LibriVox (e.g. Old Time Radio, public-domain
/// dramatisations). Filters to items with at least one m4b file.
nonisolated struct InternetArchiveProvider: CatalogProvider {
    let id = "internetArchive"
    let displayName = "Internet Archive"
    let attribution = "Public-domain audio · archive.org"
    let supportsCategories = true

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func search(query: String, limit: Int) async throws -> [CatalogBook] {
        let q = "(\(query)) AND mediatype:(audio) AND format:(\"m4b\")"
        return try await fetch(query: q, sort: "downloads desc", limit: limit)
    }

    func books(in category: CatalogCategory, limit: Int) async throws -> [CatalogBook] {
        let baseFilter = "mediatype:(audio) AND format:(\"m4b\")"
        let extra: String?
        switch category {
        case .featured, .popular: extra = nil
        case .fiction:            extra = "subject:(fiction)"
        case .nonFiction:         extra = "subject:(\"non-fiction\")"
        case .childrens:          extra = "subject:(children)"
        case .poetry:             extra = "subject:(poetry)"
        case .mystery:            extra = "subject:(mystery)"
        case .scienceFiction:     extra = "subject:(\"science fiction\")"
        }
        let q = extra.map { "\(baseFilter) AND \($0)" } ?? baseFilter
        return try await fetch(query: q, sort: "downloads desc", limit: limit)
    }

    func resolveDownloadURL(for book: CatalogBook) async throws -> URL {
        if let direct = book.downloadHandle.directURL { return direct }
        let identifier = book.downloadHandle.identifier
        let metadataURL = URL(string: "https://archive.org/metadata/\(identifier)")!
        let (data, _) = try await session.data(from: metadataURL)
        let metadata = try JSONDecoder().decode(ArchiveMetadata.self, from: data)
        let preferred = metadata.files.first { $0.name.lowercased().hasSuffix("_64kb.m4b") }
            ?? metadata.files.first { $0.name.lowercased().hasSuffix(".m4b") }
            ?? metadata.files.first { $0.name.lowercased().hasSuffix(".mp3") }
        guard let file = preferred else { throw CatalogError.noDownloadableFile }
        return URL(string: "https://archive.org/download/\(identifier)/\(file.name)")!
    }

    // MARK: - Networking

    private func fetch(query: String, sort: String, limit: Int) async throws -> [CatalogBook] {
        var components = URLComponents(string: "https://archive.org/advancedsearch.php")!
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "fl[]", value: "identifier"),
            URLQueryItem(name: "fl[]", value: "title"),
            URLQueryItem(name: "fl[]", value: "creator"),
            URLQueryItem(name: "fl[]", value: "description"),
            URLQueryItem(name: "fl[]", value: "runtime"),
            URLQueryItem(name: "sort[]", value: sort),
            URLQueryItem(name: "rows", value: String(limit)),
            URLQueryItem(name: "page", value: "1"),
            URLQueryItem(name: "output", value: "json")
        ]
        let (data, response) = try await session.data(from: components.url!)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw CatalogError.badStatus(http.statusCode)
        }
        let decoded = try JSONDecoder().decode(SearchResponse.self, from: data)
        return decoded.response.docs.map(map(_:))
    }

    private func map(_ doc: SearchResponse.Doc) -> CatalogBook {
        let creator: String?
        switch doc.creator {
        case .string(let s): creator = s
        case .array(let xs): creator = xs.first
        case .none: creator = nil
        }
        let description: String?
        switch doc.description {
        case .string(let s): description = s.htmlStripped
        case .array(let xs): description = xs.first?.htmlStripped
        case .none: description = nil
        }
        let cover = URL(string: "https://archive.org/services/img/\(doc.identifier)")
        let duration: TimeInterval? = doc.runtime.flatMap(parseRuntime(_:))
        return CatalogBook(
            id: "\(id):\(doc.identifier)",
            title: doc.title ?? doc.identifier,
            author: creator,
            narrator: nil,
            description: description,
            durationSeconds: duration,
            coverURL: cover,
            providerID: id,
            downloadHandle: .init(identifier: doc.identifier, directURL: nil, providerID: id)
        )
    }

    /// Internet Archive `runtime` is typically "HH:MM:SS" or "MM:SS".
    private func parseRuntime(_ runtime: String) -> TimeInterval? {
        let parts = runtime.split(separator: ":").compactMap { Double($0) }
        guard !parts.isEmpty else { return nil }
        switch parts.count {
        case 3: return parts[0] * 3600 + parts[1] * 60 + parts[2]
        case 2: return parts[0] * 60 + parts[1]
        case 1: return parts[0]
        default: return nil
        }
    }
}

// MARK: - Wire types

private struct SearchResponse: Decodable {
    let response: Inner
    struct Inner: Decodable { let docs: [Doc] }

    struct Doc: Decodable {
        let identifier: String
        let title: String?
        let creator: StringOrArray?
        let description: StringOrArray?
        let runtime: String?
    }

    /// Internet Archive returns some fields as either a string or an array of strings.
    enum StringOrArray: Decodable {
        case string(String)
        case array([String])
        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let s = try? container.decode(String.self) { self = .string(s); return }
            if let xs = try? container.decode([String].self) { self = .array(xs); return }
            throw DecodingError.typeMismatch(StringOrArray.self,
                .init(codingPath: container.codingPath,
                      debugDescription: "Expected String or [String]"))
        }
    }
}

private struct ArchiveMetadata: Decodable {
    struct File: Decodable { let name: String }
    let files: [File]
}

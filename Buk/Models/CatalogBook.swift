import Foundation

/// A book surfaced by an online catalog provider (Librivox, Internet Archive, …).
/// Decoupled from `Audiobook` so we can present results before they exist locally.
struct CatalogBook: Identifiable, Hashable {
    let id: String
    let title: String
    let author: String?
    let narrator: String?
    let description: String?
    let durationSeconds: TimeInterval?
    let coverURL: URL?
    let providerID: String
    /// Provider-specific payload used to start a download.
    let downloadHandle: DownloadHandle

    struct DownloadHandle: Hashable {
        /// Internet Archive identifier or other provider-specific opaque key.
        let identifier: String
        /// Optional direct file URL (e.g. when we already know the m4b URL).
        let directURL: URL?
        let providerID: String
    }
}

/// Light category used by some providers for a Discover landing screen.
enum CatalogCategory: String, CaseIterable, Identifiable, Hashable {
    case featured
    case popular
    case fiction
    case nonFiction = "non-fiction"
    case childrens
    case poetry
    case mystery
    case scienceFiction = "science-fiction"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .featured: "Featured"
        case .popular: "Most Popular"
        case .fiction: "Fiction"
        case .nonFiction: "Non-Fiction"
        case .childrens: "Children's"
        case .poetry: "Poetry"
        case .mystery: "Mystery"
        case .scienceFiction: "Science Fiction"
        }
    }
}

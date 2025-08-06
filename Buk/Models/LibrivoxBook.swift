import Foundation

struct LibrivoxBook: Identifiable, Decodable {
    let id: Int
    let title: String
    let url_iarchive: URL

    var archiveIdentifier: String { url_iarchive.lastPathComponent }

    var metadataURL: URL {
        URL(string: "https://archive.org/metadata/\(archiveIdentifier)")!
    }

    var downloadBaseURL: URL {
        URL(string: "https://archive.org/download/\(archiveIdentifier)")!
    }
}

struct LibrivoxResponse: Decodable {
    let books: [LibrivoxBook]
}

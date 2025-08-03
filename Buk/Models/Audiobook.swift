import Foundation
import SwiftUI

struct Audiobook: Identifiable, Codable {
    struct Chapter: Identifiable, Codable {
        let id: UUID
        let title: String
        let startTime: TimeInterval
    }

    let id: UUID
    let title: String
    let fileName: String
    let artworkData: Data?
    let chapters: [Chapter]

    var artworkImage: Image? {
        guard let artworkData, let uiImage = UIImage(data: artworkData) else { return nil }
        return Image(uiImage: uiImage)
    }
}

import Foundation
import AVFoundation
import SwiftUI

@MainActor
final class LibraryViewModel: ObservableObject {
    @Published private(set) var books: [Audiobook] = []

    private static let storageKey = "audiobooks"

    static let libraryFolder: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!.appendingPathComponent("Audiobooks", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    init() {
        load()
    }

    private func load() {
        guard
            let data = UserDefaults.standard.data(forKey: Self.storageKey),
            let decoded = try? JSONDecoder().decode([Audiobook].self, from: data)
        else { return }
        books = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(books) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }

    func importBook(from url: URL) async throws {
        let destination = Self.libraryFolder.appendingPathComponent(url.lastPathComponent)
        if !FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.copyItem(at: url, to: destination)
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try? destination.setResourceValues(values)
        }

        let asset = AVURLAsset(url: destination)
        let metadata = try await asset.load(.commonMetadata)
        let title: String
        if let item = metadata.first(where: { $0.commonKey?.rawValue == "title" }),
           let value = try? await item.load(.stringValue) {
            title = value
        } else {
            title = destination.deletingPathExtension().lastPathComponent
        }

        let artworkData: Data?
        if let item = metadata.first(where: { $0.commonKey?.rawValue == "artwork" }),
           let data = try? await item.load(.dataValue) {
            artworkData = data
        } else {
            artworkData = nil
        }

        let chapters = try await Self.loadChapters(for: asset)
        let book = Audiobook(id: UUID(), title: title, fileName: destination.lastPathComponent, artworkData: artworkData, chapters: chapters)
        books.append(book)
        save()
    }

    private static func loadChapters(for asset: AVURLAsset) async throws -> [Audiobook.Chapter] {
        var result: [Audiobook.Chapter] = []
        let locales = try await asset.load(.availableChapterLocales)
        guard let locale = locales.first else { return result }
        let groups = try await asset.chapterMetadataGroups(withTitleLocale: locale)
        for (index, group) in groups.enumerated() {
            let items = try await group.load(.items)
            let title = (try? await items.first(where: { $0.commonKey?.rawValue == "title" })?.load(.stringValue)) ?? "Chapter \(index + 1)"
            let timeRange = try await group.load(.timeRange)
            result.append(.init(id: UUID(), title: title, startTime: timeRange.start.seconds))
        }
        return result
    }
}

import Foundation
import AVFoundation

/// Reads metadata, chapters and artwork out of a local audio file and produces a
/// description ready to be turned into an `Audiobook`.
///
/// Chapter resolution strategy, in order:
/// 1. `availableChapterLocales` + `loadChapterMetadataGroups` (works for properly
///    authored .m4b files).
/// 2. Best-matching chapter metadata for the user's preferred languages.
/// 3. A single synthetic chapter spanning the whole asset, so the rest of the app
///    has a consistent shape to render.
enum BookImporter {
    struct Result {
        let title: String
        let author: String?
        let narrator: String?
        let duration: TimeInterval
        let chapters: [Audiobook.Chapter]
        let artworkData: Data?
    }

    static func read(asset: AVURLAsset) async throws -> Result {
        async let metadataAsync = asset.load(.commonMetadata)
        async let durationAsync = asset.load(.duration)
        let metadata = try await metadataAsync
        let durationCMTime = try await durationAsync
        let duration = durationCMTime.seconds.isFinite ? durationCMTime.seconds : 0

        let title = (await stringValue(for: .commonKeyTitle, in: metadata))
            ?? asset.url.deletingPathExtension().lastPathComponent
        let author = await stringValue(for: .commonKeyArtist, in: metadata)
        let narrator = await loadNarrator(asset: asset, common: metadata)

        var artworkData: Data?
        if let item = metadata.first(where: { $0.commonKey == .commonKeyArtwork }) {
            artworkData = try? await item.load(.dataValue)
        }

        let chapters = await loadChapters(from: asset, totalDuration: duration)

        return Result(
            title: title,
            author: author,
            narrator: narrator,
            duration: duration,
            chapters: chapters,
            artworkData: artworkData
        )
    }

    // MARK: - Chapters

    static func loadChapters(from asset: AVURLAsset, totalDuration: TimeInterval) async -> [Audiobook.Chapter] {
        let groups = await chapterGroups(from: asset)
        if !groups.isEmpty {
            let chapters = await makeChapters(from: groups, totalDuration: totalDuration)
            if !chapters.isEmpty { return chapters }
        }
        return [Audiobook.Chapter(id: UUID(), title: "Audiobook", startTime: 0, duration: totalDuration)]
    }

    private static func chapterGroups(from asset: AVURLAsset) async -> [AVTimedMetadataGroup] {
        if let locales = try? await asset.load(.availableChapterLocales), let locale = locales.first {
            if let groups = try? await asset.loadChapterMetadataGroups(withTitleLocale: locale), !groups.isEmpty {
                return groups
            }
        }
        if let groups = try? await asset.loadChapterMetadataGroups(bestMatchingPreferredLanguages: Locale.preferredLanguages), !groups.isEmpty {
            return groups
        }
        return []
    }

    private static func makeChapters(from groups: [AVTimedMetadataGroup], totalDuration: TimeInterval) async -> [Audiobook.Chapter] {
        var result: [Audiobook.Chapter] = []
        for (index, group) in groups.enumerated() {
            let titleItem = group.items.first { $0.commonKey == .commonKeyTitle }
            let title: String
            if let titleItem, let value = try? await titleItem.load(.stringValue) {
                title = value
            } else {
                title = "Chapter \(index + 1)"
            }
            let start = group.timeRange.start.seconds
            let dur = group.timeRange.duration.seconds
            let safeDur = (dur.isFinite && dur > 0) ? dur : max(0, totalDuration - start)
            result.append(Audiobook.Chapter(id: UUID(), title: title, startTime: start, duration: safeDur))
        }
        return result
    }

    // MARK: - Metadata helpers

    private static func stringValue(for key: AVMetadataKey, in items: [AVMetadataItem]) async -> String? {
        guard let item = items.first(where: { $0.commonKey == key }) else { return nil }
        return try? await item.load(.stringValue)
    }

    private static func loadNarrator(asset: AVURLAsset, common: [AVMetadataItem]) async -> String? {
        // iTunes metadata uses freeform identifiers for narrator on m4b files.
        if let items = try? await asset.loadMetadata(for: .iTunesMetadata) {
            let candidateIdentifiers = ["com.apple.iTunes.NARRATEDBY",
                                        "com.apple.iTunes.NARRATOR",
                                        "com.apple.iTunes.READBY"]
            for key in candidateIdentifiers {
                if let item = items.first(where: { $0.identifier?.rawValue == key }),
                   let value = try? await item.load(.stringValue) {
                    return value
                }
            }
        }
        // As a final fallback, common author/composer metadata.
        if let item = common.first(where: { $0.commonKey == .commonKeyAuthor }),
           let value = try? await item.load(.stringValue) {
            return value
        }
        return nil
    }
}

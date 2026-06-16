import Foundation

/// Hand-off point between the Share extension and the main app.
///
/// The Share extension copies shared audio files into a per-share directory inside
/// the App Group container's `Inbox/` folder, optionally writing a `.buktitle`
/// sidecar with the audiobook title. The main app drains the inbox on launch /
/// activation, turning each pending directory into an `Audiobook`.
///
/// Lives in both the app and the Share extension targets, so the two sides agree on
/// the container layout and the set of audio file types.
enum SharedInbox {
    /// Must match the `com.apple.security.application-groups` entitlement in both
    /// the app and the Share extension.
    static let appGroupID = "group.com.lukecharman.Buk"

    /// File extensions treated as importable audio across the app and extension.
    static let audioExtensions: Set<String> = [
        "mp3", "m4a", "m4b", "aac", "wav", "aif", "aiff", "caf", "flac"
    ]

    private static let titleFileName = ".buktitle"

    nonisolated static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
    }

    nonisolated static var inboxURL: URL? {
        containerURL?.appendingPathComponent("Inbox", isDirectory: true)
    }

    nonisolated static func isAudioFile(_ url: URL) -> Bool {
        audioExtensions.contains(url.pathExtension.lowercased())
    }

    nonisolated static func naturalSort(_ urls: [URL]) -> [URL] {
        urls.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }

    /// Returns the audio files contained anywhere within `folder` (recursively),
    /// sorted in natural order so "Track 2" precedes "Track 10".
    nonisolated static func audioFiles(in folder: URL) -> [URL] {
        let keys: [URLResourceKey] = [.isRegularFileKey]
        guard let enumerator = FileManager.default.enumerator(
            at: folder,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var files: [URL] = []
        for case let url as URL in enumerator where isAudioFile(url) {
            files.append(url)
        }
        return naturalSort(files)
    }

    // MARK: - Extension side

    /// Creates a fresh, unique directory in the inbox for one shared item.
    nonisolated static func makeGroupDirectory() throws -> URL {
        guard let inboxURL else {
            throw CocoaError(.fileWriteUnknown)
        }
        let dir = inboxURL.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    nonisolated static func writeTitle(_ title: String, to groupDir: URL) {
        let url = groupDir.appendingPathComponent(titleFileName)
        try? title.write(to: url, atomically: true, encoding: .utf8)
    }

    // MARK: - App side

    /// All pending share directories, oldest first.
    nonisolated static func pendingGroups() -> [URL] {
        guard let inboxURL,
              let contents = try? FileManager.default.contentsOfDirectory(
                at: inboxURL,
                includingPropertiesForKeys: [.isDirectoryKey, .creationDateKey],
                options: [.skipsHiddenFiles]
              ) else { return [] }
        return contents
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false }
            .sorted {
                let a = (try? $0.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? .distantPast
                let b = (try? $1.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? .distantPast
                return a < b
            }
    }

    nonisolated static func title(in groupDir: URL) -> String? {
        let url = groupDir.appendingPathComponent(titleFileName)
        guard let title = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    nonisolated static func remove(_ groupDir: URL) {
        try? FileManager.default.removeItem(at: groupDir)
    }
}

import Foundation

/// Downloads an audio file from a remote URL with progress reporting and writes it
/// to the temporary directory. The caller (typically `LibraryViewModel.importBook`)
/// then ingests the temporary file into the library.
actor DownloadManager {
    static let shared = DownloadManager()

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Downloads `url` into a temporary file, calling `progress` on the main actor with
    /// fractional progress between 0 and 1. The returned URL points at a file that the
    /// caller is responsible for moving or deleting.
    func download(_ url: URL, progress: @MainActor @Sendable @escaping (Double) -> Void) async throws -> URL {
        let (bytes, response) = try await session.bytes(from: url)
        let total = response.expectedContentLength
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(url.pathExtension.isEmpty ? "m4b" : url.pathExtension)

        FileManager.default.createFile(atPath: tempURL.path, contents: nil)
        let handle = try FileHandle(forWritingTo: tempURL)
        defer { try? handle.close() }

        var buffer = Data()
        buffer.reserveCapacity(64 * 1024)
        var received: Int64 = 0
        var lastReport: Double = -1

        for try await byte in bytes {
            buffer.append(byte)
            received &+= 1
            if buffer.count >= 64 * 1024 {
                try handle.write(contentsOf: buffer)
                buffer.removeAll(keepingCapacity: true)
            }
            if total > 0 {
                let fraction = Double(received) / Double(total)
                let bucket = (fraction * 100).rounded() / 100
                if bucket != lastReport {
                    lastReport = bucket
                    await progress(fraction)
                }
            }
        }
        if !buffer.isEmpty { try handle.write(contentsOf: buffer) }
        await progress(1.0)
        return tempURL
    }
}

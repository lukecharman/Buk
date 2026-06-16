import UIKit
import UniformTypeIdentifiers

/// Principal class for the "North" Share extension.
///
/// Copies the shared audio (a folder of tracks, or one or more loose audio files)
/// into the App Group inbox, records a suggested title, then opens the host app so
/// it can import immediately with visible progress.
final class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear

        let label = UILabel()
        label.text = "Adding to North…"
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])

        Task { await processAndFinish() }
    }

    private func processAndFinish() async {
        defer {
            openHostApp()
            extensionContext?.completeRequest(returningItems: nil)
        }

        guard let groupDir = try? SharedInbox.makeGroupDirectory() else { return }

        let items = (extensionContext?.inputItems as? [NSExtensionItem]) ?? []
        var folderTitle: String?
        var firstFileBaseName: String?
        var copiedFiles = 0

        for item in items {
            for provider in item.attachments ?? [] {
                guard let typeID = preferredTypeIdentifier(for: provider) else { continue }
                let result = await copy(provider: provider, typeID: typeID, into: groupDir)
                copiedFiles += result.count
                if let folder = result.folderName { folderTitle = folder }
                if firstFileBaseName == nil { firstFileBaseName = result.firstBaseName }
            }
        }

        guard copiedFiles > 0 else {
            SharedInbox.remove(groupDir)
            return
        }

        if let title = folderTitle ?? (copiedFiles > 1 ? firstFileBaseName : nil) {
            SharedInbox.writeTitle(title, to: groupDir)
        }
    }

    /// Picks the registered type identifier we know how to handle: a folder, or any
    /// audio type. Folders take priority so a shared folder is expanded in full.
    private func preferredTypeIdentifier(for provider: NSItemProvider) -> String? {
        let ids = provider.registeredTypeIdentifiers
        if let folder = ids.first(where: { conforms($0, to: .folder) }) { return folder }
        return ids.first { conforms($0, to: .audio) }
    }

    private func conforms(_ identifier: String, to type: UTType) -> Bool {
        guard let uti = UTType(identifier) else { return false }
        return uti.conforms(to: type)
    }

    private struct CopyResult {
        var count = 0
        var folderName: String?
        var firstBaseName: String?
    }

    /// Loads the item from the provider and copies its audio contents into `dir`.
    /// The provider's file representation is only valid inside the completion
    /// handler, so all copying happens synchronously there.
    private func copy(provider: NSItemProvider, typeID: String, into dir: URL) async -> CopyResult {
        await withCheckedContinuation { (continuation: CheckedContinuation<CopyResult, Never>) in
            provider.loadFileRepresentation(forTypeIdentifier: typeID) { url, _ in
                var result = CopyResult()
                guard let url else { continuation.resume(returning: result); return }

                let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
                if isDirectory {
                    result.folderName = url.lastPathComponent
                    for file in SharedInbox.audioFiles(in: url) {
                        if self.copyFile(file, into: dir) {
                            result.count += 1
                            if result.firstBaseName == nil {
                                result.firstBaseName = file.deletingPathExtension().lastPathComponent
                            }
                        }
                    }
                } else if SharedInbox.isAudioFile(url) {
                    if self.copyFile(url, into: dir) {
                        result.count = 1
                        result.firstBaseName = url.deletingPathExtension().lastPathComponent
                    }
                }
                continuation.resume(returning: result)
            }
        }
    }

    private func copyFile(_ source: URL, into dir: URL) -> Bool {
        let destination = uniqueDestination(for: source.lastPathComponent, in: dir)
        do {
            try FileManager.default.copyItem(at: source, to: destination)
            return true
        } catch {
            return false
        }
    }

    private func uniqueDestination(for name: String, in dir: URL) -> URL {
        var candidate = dir.appendingPathComponent(name)
        let base = (name as NSString).deletingPathExtension
        let ext = (name as NSString).pathExtension
        var index = 1
        while FileManager.default.fileExists(atPath: candidate.path) {
            let next = ext.isEmpty ? "\(base)-\(index)" : "\(base)-\(index).\(ext)"
            candidate = dir.appendingPathComponent(next)
            index += 1
        }
        return candidate
    }

    /// Opens the host app via its custom URL scheme by walking the responder chain,
    /// the only supported way for a Share extension to launch its container app.
    private func openHostApp() {
        guard let url = URL(string: "north://import") else { return }
        let selector = sel_registerName("openURL:")
        var responder: UIResponder? = self
        while let current = responder {
            if current.responds(to: selector) {
                _ = current.perform(selector, with: url)
                return
            }
            responder = current.next
        }
    }
}

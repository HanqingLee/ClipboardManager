import Foundation

public final class HistoryStore {
    public private(set) var items: [ClipboardItem] = []
    public let capacity: Int

    private let directory: URL
    private let imagesDirectory: URL
    private let historyFile: URL

    public init(capacity: Int = 100, directory: URL) {
        self.capacity = capacity
        self.directory = directory
        self.imagesDirectory = directory.appendingPathComponent("images", isDirectory: true)
        self.historyFile = directory.appendingPathComponent("history.json")
    }

    public static func defaultDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory,
                                            in: .userDomainMask).first!
        return base.appendingPathComponent("ClipboardManager", isDirectory: true)
    }

    @discardableResult
    public func record(_ content: CapturedContent) -> Bool {
        switch content.kind {
        case .text:
            guard let text = content.text, !text.isEmpty else { return false }
            let hash = ClipboardItem.makeHash(kind: .text, text: text, fileURL: nil, imageBytes: nil)
            guard items.first?.contentHash != hash else { return false }
            insert(ClipboardItem(kind: .text, text: text,
                                 sourceAppName: content.sourceAppName, contentHash: hash))
            return true

        case .file:
            guard let path = content.fileURL else { return false }
            let hash = ClipboardItem.makeHash(kind: .file, text: nil, fileURL: path, imageBytes: nil)
            guard items.first?.contentHash != hash else { return false }
            insert(ClipboardItem(kind: .file, fileURL: path,
                                 sourceAppName: content.sourceAppName, contentHash: hash))
            return true

        case .image:
            guard let data = content.imageData else { return false }
            let hash = ClipboardItem.makeHash(kind: .image, text: nil, fileURL: nil, imageBytes: data)
            guard items.first?.contentHash != hash else { return false }
            let id = UUID()
            let ref = persistImage(data, id: id)
            insert(ClipboardItem(id: id, kind: .image, imageRef: ref,
                                 sourceAppName: content.sourceAppName, contentHash: hash))
            return true
        }
    }

    private func insert(_ item: ClipboardItem) {
        items.insert(item, at: 0)
        if items.count > capacity {
            for removed in items[capacity...] { deleteImage(for: removed) }
            items.removeSubrange(capacity...)
        }
    }

    public func removeAll() {
        for item in items { deleteImage(for: item) }
        items.removeAll()
        save()
    }

    // MARK: - Image persistence

    private func persistImage(_ data: Data, id: UUID) -> String? {
        do {
            try FileManager.default.createDirectory(at: imagesDirectory,
                                                    withIntermediateDirectories: true)
            let ref = "\(id.uuidString).png"
            try data.write(to: imagesDirectory.appendingPathComponent(ref))
            return ref
        } catch {
            NSLog("ClipboardManager: failed to persist image: \(error)")
            return nil
        }
    }

    public func imageData(forRef ref: String) -> Data? {
        try? Data(contentsOf: imagesDirectory.appendingPathComponent(ref))
    }

    private func deleteImage(for item: ClipboardItem) {
        guard let ref = item.imageRef else { return }
        try? FileManager.default.removeItem(at: imagesDirectory.appendingPathComponent(ref))
    }

    // MARK: - JSON persistence

    public func save() {
        do {
            try FileManager.default.createDirectory(at: directory,
                                                    withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(items)
            try data.write(to: historyFile, options: .atomic)
        } catch {
            NSLog("ClipboardManager: failed to save history: \(error)")
        }
    }

    public func load() {
        do {
            let data = try Data(contentsOf: historyFile)
            items = try JSONDecoder().decode([ClipboardItem].self, from: data)
        } catch {
            items = []
        }
    }
}

import Foundation
import CryptoKit

public enum ClipboardItemKind: String, Codable {
    case text
    case file
    case image
}

public struct ClipboardItem: Codable, Equatable, Identifiable {
    public let id: UUID
    public let kind: ClipboardItemKind
    public let text: String?
    public let imageRef: String?
    public let fileURL: String?
    public let sourceAppName: String?
    public let sourceAppBundleID: String?
    public let createdAt: Date
    public let contentHash: String

    public init(id: UUID = UUID(),
                kind: ClipboardItemKind,
                text: String? = nil,
                imageRef: String? = nil,
                fileURL: String? = nil,
                sourceAppName: String? = nil,
                sourceAppBundleID: String? = nil,
                createdAt: Date = Date(),
                contentHash: String) {
        self.id = id
        self.kind = kind
        self.text = text
        self.imageRef = imageRef
        self.fileURL = fileURL
        self.sourceAppName = sourceAppName
        self.sourceAppBundleID = sourceAppBundleID
        self.createdAt = createdAt
        self.contentHash = contentHash
    }

    public static func makeHash(kind: ClipboardItemKind,
                                text: String?,
                                fileURL: String?,
                                imageBytes: Data?) -> String {
        var hasher = SHA256()
        hasher.update(data: Data(kind.rawValue.utf8))
        if let text { hasher.update(data: Data(text.utf8)) }
        if let fileURL { hasher.update(data: Data(fileURL.utf8)) }
        if let imageBytes { hasher.update(data: imageBytes) }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    /// 返回一个仅 `createdAt` 不同、其余字段完全一致的副本。
    public func withCreatedAt(_ date: Date) -> ClipboardItem {
        ClipboardItem(id: id, kind: kind, text: text, imageRef: imageRef, fileURL: fileURL,
                      sourceAppName: sourceAppName, sourceAppBundleID: sourceAppBundleID,
                      createdAt: date, contentHash: contentHash)
    }

    public var preview: String {
        switch kind {
        case .text:
            let trimmed = (text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "(empty)" : String(trimmed.prefix(120))
        case .file:
            return (fileURL as NSString?)?.lastPathComponent ?? "(file)"
        case .image:
            return "(image)"
        }
    }
}

public struct CapturedContent {
    public enum Kind { case text, file, image }
    public let kind: Kind
    public let text: String?
    public let fileURL: String?
    public let imageData: Data?
    public let sourceAppName: String?
    public let sourceAppBundleID: String?

    public init(kind: Kind,
                text: String? = nil,
                fileURL: String? = nil,
                imageData: Data? = nil,
                sourceAppName: String? = nil,
                sourceAppBundleID: String? = nil) {
        self.kind = kind
        self.text = text
        self.fileURL = fileURL
        self.imageData = imageData
        self.sourceAppName = sourceAppName
        self.sourceAppBundleID = sourceAppBundleID
    }
}

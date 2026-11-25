import Foundation

public struct ChatMessage: Identifiable, Codable, Equatable {
    public var id: UUID
    public var role: String // "user" or "assistant"
    public var content: String
    public var timestamp: Date
    public var attachedFiles: [FinderFileItem]
    
    public init(
        id: UUID = UUID(),
        role: String,
        content: String,
        timestamp: Date = Date.now,
        attachedFiles: [FinderFileItem] = []
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.attachedFiles = attachedFiles
    }
}

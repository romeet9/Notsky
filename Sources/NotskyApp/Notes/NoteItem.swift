import Foundation

public struct NoteItem: Identifiable, Codable, Equatable {
    public var id: UUID
    public var text: String
    public var isCompleted: Bool
    
    public init(
        id: UUID = UUID(),
        text: String,
        isCompleted: Bool = false
    ) {
        self.id = id
        self.text = text
        self.isCompleted = isCompleted
    }
}

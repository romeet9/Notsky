import Foundation

public struct NotePage: Identifiable, Codable, Equatable {
    public var id: UUID
    public var title: String
    public var content: String
    
    public init(
        id: UUID = UUID(),
        title: String = String(localized: "Untitled"),
        content: String = ""
    ) {
        self.id = id
        self.title = title
        self.content = content
    }
}

import Foundation

public struct FinderFileItem: Identifiable, Codable, Equatable {
    public var id: UUID
    public var name: String
    public var path: String
    public var fileSize: String
    public var fileType: String
    public var summary: String
    public var formattedDate: String
    
    public init(
        id: UUID = UUID(),
        name: String,
        path: String,
        fileSize: String = "",
        fileType: String = "",
        summary: String = "",
        formattedDate: String = ""
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.fileSize = fileSize
        self.fileType = fileType
        self.summary = summary
        self.formattedDate = formattedDate
    }
}

import Foundation

public struct ParsedTaskResult {
    public let cleanText: String
    public let dateTag: String?
    public let dueDate: Date?
    public let isToday: Bool
    public let isTomorrow: Bool
}

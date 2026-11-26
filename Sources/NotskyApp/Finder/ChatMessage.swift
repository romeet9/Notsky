import Foundation

/// A change the assistant made (shown as a chip under its reply, with a short-lived Undo).
public struct ChatAction: Identifiable, Codable, Equatable {
    public var id: UUID
    public var label: String

    public init(id: UUID = UUID(), label: String) {
        self.id = id
        self.label = label
    }
}

/// A destructive step the assistant wants to take; runs only when the user taps the confirm button.
public struct ChatConfirmation: Identifiable, Codable, Equatable {
    public enum Status: String, Codable { case pending, confirmed, cancelled }

    public var id: UUID
    public var prompt: String
    public var confirmLabel: String
    public var toolName: String
    public var argumentsJSON: String
    public var status: Status

    public init(
        id: UUID = UUID(),
        prompt: String,
        confirmLabel: String = String(localized: "Delete"),
        toolName: String,
        argumentsJSON: String,
        status: Status = .pending
    ) {
        self.id = id
        self.prompt = prompt
        self.confirmLabel = confirmLabel
        self.toolName = toolName
        self.argumentsJSON = argumentsJSON
        self.status = status
    }
}

public struct ChatMessage: Identifiable, Codable, Equatable {
    public var id: UUID
    public var role: String // "user" or "assistant"
    public var content: String
    public var timestamp: Date
    public var attachedFiles: [FinderFileItem]
    /// New in Notsky AI; optional so workspaces saved before it still decode.
    public var actions: [ChatAction]?
    public var confirmations: [ChatConfirmation]?
    public var isError: Bool?

    public init(
        id: UUID = UUID(),
        role: String,
        content: String,
        timestamp: Date = Date.now,
        attachedFiles: [FinderFileItem] = [],
        actions: [ChatAction]? = nil,
        confirmations: [ChatConfirmation]? = nil,
        isError: Bool? = nil
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.attachedFiles = attachedFiles
        self.actions = actions
        self.confirmations = confirmations
        self.isError = isError
    }
}

extension Array where Element == ChatMessage {
    /// Chat history is capped so the saved workspace stays small.
    mutating func capChatHistory(_ limit: Int = 50) {
        if count > limit { removeFirst(count - limit) }
    }
}

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

public enum CardType: String, Codable, Equatable {
    case tasks
    case notes
    case finder
}

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
        timestamp: Date = Date(),
        attachedFiles: [FinderFileItem] = []
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.attachedFiles = attachedFiles
    }
}

public struct NotePage: Identifiable, Codable, Equatable {
    public var id: UUID
    public var title: String
    public var content: String
    
    public init(
        id: UUID = UUID(),
        title: String = "Untitled",
        content: String = ""
    ) {
        self.id = id
        self.title = title
        self.content = content
    }
}

public struct NoteCard: Identifiable, Codable, Equatable {
    public var id: UUID
    public var cardType: CardType
    public var title: String
    public var noteContent: String
    public var pages: [NotePage]
    public var activePageIndex: Int
    public var headerImagePath: String
    public var items: [NoteItem]
    public var chatMessages: [ChatMessage]
    public var gridCol: Int
    public var gridRow: Int
    public var positionX: Double
    public var positionY: Double
    public var width: Double
    public var height: Double
    public var timerDuration: Int
    public var timeRemaining: Int
    public var isTimerRunning: Bool
    public var isPinned: Bool
    
    public init(
        id: UUID = UUID(),
        cardType: CardType = .tasks,
        title: String = "Design Iterations",
        noteContent: String = "",
        pages: [NotePage] = [],
        activePageIndex: Int = 0,
        headerImagePath: String = WallpaperPackManager.defaultFallbackPath,
        items: [NoteItem] = [],
        chatMessages: [ChatMessage] = [],
        gridCol: Int = 0,
        gridRow: Int = 0,
        positionX: Double = 0,
        positionY: Double = 0,
        width: Double = 281,
        height: Double = 364,
        timerDuration: Int = 25 * 60,
        timeRemaining: Int = 25 * 60,
        isTimerRunning: Bool = false,
        isPinned: Bool = false
    ) {
        self.id = id
        self.cardType = cardType
        self.title = title
        self.noteContent = noteContent
        if pages.isEmpty && cardType == .notes {
            self.pages = [NotePage(title: title, content: noteContent)]
        } else {
            self.pages = pages
        }
        self.activePageIndex = activePageIndex
        self.headerImagePath = headerImagePath
        self.items = items
        self.chatMessages = chatMessages
        self.gridCol = gridCol
        self.gridRow = gridRow
        self.positionX = positionX
        self.positionY = positionY
        self.width = width
        self.height = height
        self.timerDuration = timerDuration
        self.timeRemaining = timeRemaining
        self.isTimerRunning = isTimerRunning
        self.isPinned = isPinned
    }
}


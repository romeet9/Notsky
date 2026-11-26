import Foundation

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
    public var folderId: UUID?
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
    /// Display UUID (CGDisplayCreateUUIDFromDisplayID) the card lives on. nil == primary display.
    public var screenID: String?
    /// Base size in grid cells (persisted). nil == the card type's default. Pixel width/height are derived at layout time.
    public var colSpan: Int?
    public var rowSpan: Int?
    
    public static func defaultSpans(for type: CardType) -> (c: Int, r: Int) {
        switch type {
        case .tasks, .folders, .nowPlaying, .voiceOpen: return (1, 1)
        case .notes, .finder, .linear: return (2, 1)
        }
    }
    
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
        folderId: UUID? = nil,
        gridCol: Int = 0,
        gridRow: Int = 0,
        positionX: Double = 0,
        positionY: Double = 0,
        width: Double = 281,
        height: Double = 364,
        timerDuration: Int = 25 * 60,
        timeRemaining: Int = 25 * 60,
        isTimerRunning: Bool = false,
        isPinned: Bool = false,
        screenID: String? = nil,
        colSpan: Int? = nil,
        rowSpan: Int? = nil
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
        self.folderId = folderId
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
        self.screenID = screenID
        self.colSpan = colSpan
        self.rowSpan = rowSpan
    }
}

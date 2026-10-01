import SwiftUI
import AppKit

@MainActor
public struct FoldersCardView: View {
    @Binding public var note: NoteCard
    @Environment(\.colorScheme) private var colorScheme
    
    public var onSpawnWidget: () -> Void = {}
    public var onDelete: () -> Void = {}
    
    @ObservedObject private var manager = WidgetWindowManager.shared
    private var settings: AppSettings { AppSettings.shared }
    
    @State private var selectedFolderId: UUID? = nil
    @State private var isCreatingFolder: Bool = false
    @State private var newFolderName: String = ""
    @FocusState private var isNewFolderFocused: Bool
    
    @State private var renamingFolderId: UUID? = nil
    @State private var renameText: String = ""
    @FocusState private var isRenameFocused: Bool
    
    @State private var isHoveringPlus: Bool = false
    @State private var isHoveringTools: Bool = false
    @State private var isHoveringBack: Bool = false
    
    // Drag initial dimensions for smooth resizing
    @State private var dragInitialWidth: Double? = nil
    @State private var dragInitialHeight: Double? = nil
    @State private var isHoveringResizeW: Bool = false
    @State private var isHoveringResizeH: Bool = false
    @State private var isHoveringResizeCorner: Bool = false
    
    // MARK: - Layout Constants Matching Notsky Spec
    private var cardWidth: CGFloat { CGFloat(note.width) }
    private var cardHeight: CGFloat { CGFloat(note.height) }
    private let headerHeight: CGFloat = 53
    private var sheetHeight: CGFloat { max(100, cardHeight - headerHeight) }
    private let cornerRadius: CGFloat = 40
    
    private let minCardWidth: Double = 281
    private let maxCardWidth: Double = 586
    private let minCardHeight: Double = 260
    private let maxCardHeight: Double = 752
    
    private var isDark: Bool {
        if let override = settings.preferredColorScheme {
            return override == .dark
        }
        return colorScheme == .dark
    }
    
    private var sheetBackgroundColor: Color {
        let opacity = settings.backgroundOpacity
        return isDark ? Color(white: 0.12).opacity(opacity) : Color.white.opacity(opacity)
    }
    
    private func buttonBackgroundColor(hovering: Bool) -> Color {
        if isDark {
            return hovering ? Color(white: 0.16).opacity(0.90) : sheetBackgroundColor
        } else {
            return hovering ? Color.white.opacity(0.98) : sheetBackgroundColor
        }
    }
    
    private var specularBorderGradient: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: Color.white.opacity(isDark ? 0.35 : 0.70), location: 0.0),
                .init(color: Color.white.opacity(isDark ? 0.12 : 0.25), location: 0.5),
                .init(color: Color.white.opacity(isDark ? 0.02 : 0.08), location: 1.0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    private var currentFolder: NoteFolder? {
        manager.store.folder(for: selectedFolderId)
    }
    
    private var notesInCurrentFolder: [NoteCard] {
        manager.store.notes(in: selectedFolderId)
    }
    
    private var gridColumns: [GridItem] {
        if cardWidth >= 520 {
            return [
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8)
            ]
        } else {
            return [
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8)
            ]
        }
    }
    
    public init(
        note: Binding<NoteCard>,
        onSpawnWidget: @escaping () -> Void = {},
        onDelete: @escaping () -> Void = {}
    ) {
        self._note = note
        self.onSpawnWidget = onSpawnWidget
        self.onDelete = onDelete
    }
    
    public var body: some View {
        ZStack(alignment: .top) {
            // 1. Full-Card Background Image
            HeaderImageView(imagePath: note.headerImagePath)
                .frame(width: cardWidth, height: cardHeight)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            
            // 2. Foreground Content Sheet
            ZStack(alignment: .top) {
                sheetBackgroundColor
                    .background(.ultraThinMaterial)
                
                VStack(spacing: 0) {
                    topToolbar
                        .padding(.top, 12)
                        .padding(.horizontal, 16)
                    
                    if isCreatingFolder {
                        newFolderInputField
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                            .transition(.asymmetric(
                                insertion: .move(edge: .top).combined(with: .opacity),
                                removal: .move(edge: .top).combined(with: .opacity)
                            ))
                    }
                    
                    contentGridView
                        .padding(.horizontal, 16)
                        .padding(.top, 6)
                }
                .animation(.spring(response: 0.32, dampingFraction: 0.82), value: isCreatingFolder)
            }
            .frame(width: cardWidth, height: sheetHeight)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(specularBorderGradient, lineWidth: 0.75)
            )
            .offset(y: headerHeight)
            .zIndex(1)
            
            // 3. Top Header Space (53pt Height with Centered Capsules)
            headerTitleCapsules
                .frame(width: cardWidth, height: headerHeight)
                .zIndex(10)
            
            // 4. Resize Handles
            resizeHandles
                .zIndex(100)
        }
        .frame(width: cardWidth, height: cardHeight)
    }
    
    // MARK: - Header Capsules
    private var headerTitleCapsules: some View {
        HStack(spacing: 8) {
            if let folder = currentFolder {
                // Back Button & Folder Name Capsule
                Button(action: {
                    SensoryFeedback.buttonClicked()
                    withAnimation(.spring(response: 0.30, dampingFraction: 0.82)) {
                        selectedFolderId = nil
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(isDark ? .white : .black)
                        
                        Image(systemName: "folder.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.blue)
                        
                        Text(folder.name)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(isDark ? .white : .black)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 36)
                    .background(buttonBackgroundColor(hovering: isHoveringBack), in: Capsule())
                    .overlay(Capsule().strokeBorder(specularBorderGradient, lineWidth: 0.75))
                    .shadow(color: Color.black.opacity(0.35), radius: 6, y: 2)
                }
                .buttonStyle(.plain)
                .onHover { isHoveringBack = $0 }
                .help("Back to All Folders")
                
                // Notes Count Capsule
                HStack(spacing: 5) {
                    Circle()
                        .fill(notesInCurrentFolder.isEmpty ? Color.gray : Color.blue)
                        .frame(width: 7, height: 7)
                    
                    Text("\(notesInCurrentFolder.count) \(notesInCurrentFolder.count == 1 ? "note" : "notes")")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(isDark ? .white.opacity(0.9) : .black.opacity(0.8))
                }
                .padding(.horizontal, 12)
                .frame(height: 36)
                .background(buttonBackgroundColor(hovering: false), in: Capsule())
                .overlay(Capsule().strokeBorder(specularBorderGradient, lineWidth: 0.75))
                .shadow(color: Color.black.opacity(0.35), radius: 6, y: 2)
            } else {
                // Folders Title Capsule
                HStack(spacing: 6) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.blue)
                    
                    Text("Folders")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(isDark ? .white : .black)
                }
                .padding(.horizontal, 16)
                .frame(height: 36)
                .background(buttonBackgroundColor(hovering: false), in: Capsule())
                .overlay(Capsule().strokeBorder(specularBorderGradient, lineWidth: 0.75))
                .shadow(color: Color.black.opacity(0.35), radius: 6, y: 2)
                
                // Folders Count Capsule
                HStack(spacing: 5) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 7, height: 7)
                    
                    Text("\(manager.store.folders.count) \(manager.store.folders.count == 1 ? "folder" : "folders")")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(isDark ? .white.opacity(0.9) : .black.opacity(0.8))
                }
                .padding(.horizontal, 12)
                .frame(height: 36)
                .background(buttonBackgroundColor(hovering: false), in: Capsule())
                .overlay(Capsule().strokeBorder(specularBorderGradient, lineWidth: 0.75))
                .shadow(color: Color.black.opacity(0.35), radius: 6, y: 2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
    
    // MARK: - Top Toolbar
    private var topToolbar: some View {
        HStack {
            // Plus Button (36 × 36 pt)
            Button(action: {
                SensoryFeedback.buttonClicked()
                if selectedFolderId != nil {
                    // Create a new note inside this folder
                    manager.spawnNewFreeformNoteWidget()
                    if let lastCreated = manager.store.notes.last {
                        let idx = manager.store.notes.count - 1
                        manager.store.notes[idx].folderId = selectedFolderId
                    }
                } else {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isCreatingFolder.toggle()
                        if isCreatingFolder {
                            newFolderName = ""
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                isNewFolderFocused = true
                            }
                        }
                    }
                }
            }) {
                Image(systemName: isCreatingFolder ? "xmark" : "plus")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(isDark ? .white.opacity(0.9) : .black.opacity(0.75))
                    .frame(width: 36, height: 36)
                    .background(buttonBackgroundColor(hovering: isHoveringPlus), in: Circle())
                    .overlay(Circle().strokeBorder(specularBorderGradient, lineWidth: 0.75))
            }
            .buttonStyle(.plain)
            .onHover { isHoveringPlus = $0 }
            .help(selectedFolderId != nil ? "Add Note in this Folder" : (isCreatingFolder ? "Cancel" : "New Folder"))
            
            Spacer()
            
            // Action Cluster Pill
            HStack(spacing: 11) {
                // Pin Button (Pin on Top / Floating)
                Button(action: {
                    SensoryFeedback.buttonClicked()
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        note.isPinned.toggle()
                        WidgetWindowManager.shared.setPinned(note.isPinned, for: note.id)
                    }
                }) {
                    Image(systemName: note.isPinned ? "pin.fill" : "pin")
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundColor(note.isPinned ? Color.orange : (isDark ? .white.opacity(0.85) : .black.opacity(0.75)))
                }
                .buttonStyle(.plain)
                .help(note.isPinned ? "Unpin (Desktop Canvas)" : "Pin on Top (Floating)")
                
                // Cycle Wallpaper Button
                Button(action: {
                    cycleWallpaper()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundColor(isDark ? .white.opacity(0.85) : .black.opacity(0.75))
                }
                .buttonStyle(.plain)
                .help("Next Wallpaper in Pack")
                
                // Custom Header Image / Wallpaper Picker
                Button(action: {
                    SensoryFeedback.buttonClicked()
                    selectCustomHeaderImage()
                }) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundColor(isDark ? .white.opacity(0.85) : .black.opacity(0.75))
                }
                .buttonStyle(.plain)
                .help("Change Header Image")
                
                // Delete Widget Button
                Button(action: {
                    SensoryFeedback.buttonClicked()
                    onDelete()
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundColor(isDark ? .white.opacity(0.85) : .black.opacity(0.75))
                }
                .buttonStyle(.plain)
                .help("Delete Widget")
            }
            .padding(.horizontal, 12)
            .frame(height: 36)
            .background(buttonBackgroundColor(hovering: isHoveringTools), in: Capsule())
            .overlay(Capsule().strokeBorder(specularBorderGradient, lineWidth: 0.75))
            .onHover { isHoveringTools = $0 }
        }
    }
    
    // MARK: - New Folder Input Field
    private var newFolderInputField: some View {
        HStack(spacing: 8) {
            Image(systemName: "folder.fill.badge.plus")
                .font(.system(size: 14))
                .foregroundColor(.blue)
            
            TextField("Folder Name", text: $newFolderName)
                .textFieldStyle(.plain)
                .font(.system(size: 13, weight: .medium))
                .focused($isNewFolderFocused)
                .onSubmit {
                    commitNewFolder()
                }
            
            Button("Create") {
                commitNewFolder()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(.horizontal, 14)
        .frame(height: 40)
        .background(
            isDark ? Color(white: 0.18).opacity(0.9) : Color.white.opacity(0.9),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(specularBorderGradient, lineWidth: 0.75)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 6, y: 2)
    }
    
    private func commitNewFolder() {
        let trimmed = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            manager.store.createFolder(name: trimmed)
            SensoryFeedback.taskAdded()
        }
        newFolderName = ""
        withAnimation(.easeInOut(duration: 0.2)) {
            isCreatingFolder = false
        }
    }
    
    // MARK: - Content Grid View
    private var contentGridView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            if let folder = currentFolder {
                // Display notes inside selected folder
                if notesInCurrentFolder.isEmpty {
                    emptyFolderNotesView(folder: folder)
                        .padding(.top, 24)
                } else {
                    LazyVGrid(columns: gridColumns, spacing: 12) {
                        ForEach(notesInCurrentFolder) { noteItem in
                            noteSquareCard(noteItem)
                        }
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
            } else {
                // Display all folders
                if manager.store.folders.isEmpty {
                    emptyFoldersView
                        .padding(.top, 24)
                } else {
                    LazyVGrid(columns: gridColumns, spacing: 12) {
                        ForEach(manager.store.folders) { folder in
                            folderSquareCard(folder)
                        }
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
            }
        }
        .contentEdgeFade(top: 10, bottom: 20)
    }
    
    // MARK: - Square Folder Tile (Matching North Sky AI Card Spec)
    private func folderSquareCard(_ folder: NoteFolder) -> some View {
        let notesCount = manager.store.notes(in: folder.id).count
        let isRenaming = (renamingFolderId == folder.id)
        
        return Button(action: {
            SensoryFeedback.buttonClicked()
            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                selectedFolderId = folder.id
            }
        }) {
            VStack(alignment: .leading, spacing: 0) {
                // Top Row: Folder Icon + Note Count Badge
                HStack(alignment: .center) {
                    Image(systemName: folder.icon.contains(".fill") ? folder.icon : "\(folder.icon).fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.blue)
                    
                    Spacer(minLength: 4)
                    
                    Text("\(notesCount) \(notesCount == 1 ? "note" : "notes")")
                        .font(.system(size: 10.5, weight: .medium, design: .rounded))
                        .foregroundColor(isDark ? Color.white.opacity(0.5) : Color.black.opacity(0.5))
                }
                
                Spacer(minLength: 8)
                
                // Bottom Row: Folder Name + Creation Date
                if isRenaming {
                    TextField("Folder Name", text: $renameText)
                        .font(.system(size: 13, weight: .medium, design: .default))
                        .textFieldStyle(.plain)
                        .focused($isRenameFocused)
                        .onSubmit {
                            manager.store.renameFolder(id: folder.id, newName: renameText)
                            renamingFolderId = nil
                        }
                } else {
                    HStack(alignment: .bottom, spacing: 4) {
                        Text(folder.name)
                            .font(.system(size: 13, weight: .semibold, design: .default))
                            .tracking(-0.3)
                            .foregroundStyle(isDark ? Color.white : Color.black)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .bottomLeading)
                        
                        Text(formattedDate(folder.createdAt))
                            .font(.system(size: 9.5, weight: .medium, design: .rounded))
                            .foregroundColor(isDark ? Color.white.opacity(0.45) : Color.black.opacity(0.40))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .bottomLeading)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: 96, maxHeight: 116)
            .background(sheetBackgroundColor, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(specularBorderGradient, lineWidth: 0.75)
            )
            .shadow(color: Color.black.opacity(isDark ? 0.06 : 0.03), radius: 5, x: 0, y: 1.5)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Open Folder") {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                    selectedFolderId = folder.id
                }
            }
            Button("Rename Folder") {
                renameText = folder.name
                renamingFolderId = folder.id
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    isRenameFocused = true
                }
            }
            Divider()
            Button(role: .destructive, action: {
                manager.store.deleteFolder(id: folder.id)
                SensoryFeedback.taskDeleted()
            }) {
                Label("Delete Folder", systemImage: "trash")
            }
        }
    }
    
    // MARK: - Square Note Tile (Inside a Folder)
    private func noteSquareCard(_ card: NoteCard) -> some View {
        let isTasks = (card.cardType == .tasks)
        let subtitle: String = {
            if isTasks {
                return "\(card.items.count) \(card.items.count == 1 ? "task" : "tasks")"
            } else {
                let text = card.pages.first?.content ?? card.noteContent
                let count = text.split { $0.isWhitespace || $0.isNewline }.count
                return "\(count) words"
            }
        }()
        
        return Button(action: {
            SensoryFeedback.buttonClicked()
            manager.focusWidget(for: card.id)
        }) {
            VStack(alignment: .leading, spacing: 0) {
                // Top Row: Icon + Word/Task count
                HStack(alignment: .center) {
                    Image(systemName: isTasks ? "checklist" : "doc.text.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(isTasks ? Color.orange.opacity(0.9) : Color.indigo.opacity(0.9))
                    
                    Spacer(minLength: 4)
                    
                    Text(subtitle)
                        .font(.system(size: 10.5, weight: .medium, design: .rounded))
                        .foregroundColor(isDark ? Color.white.opacity(0.5) : Color.black.opacity(0.5))
                }
                
                Spacer(minLength: 8)
                
                // Bottom Row: Note Title & Snippet Preview
                VStack(alignment: .leading, spacing: 2) {
                    Text(card.title.isEmpty ? (isTasks ? "Tasks" : "Note") : card.title)
                        .font(.system(size: 13, weight: .semibold, design: .default))
                        .tracking(-0.3)
                        .foregroundStyle(isDark ? Color.white : Color.black)
                        .multilineTextAlignment(.leading)
                        .lineLimit(1)
                    
                    let snippet = card.noteContent.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !snippet.isEmpty {
                        Text(snippet.replacingOccurrences(of: "\n", with: " "))
                            .font(.system(size: 10, weight: .regular))
                            .foregroundColor(isDark ? Color.white.opacity(0.5) : Color.black.opacity(0.45))
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .bottomLeading)
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: 96, maxHeight: 116)
            .background(sheetBackgroundColor, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(specularBorderGradient, lineWidth: 0.75)
            )
            .shadow(color: Color.black.opacity(isDark ? 0.06 : 0.03), radius: 5, x: 0, y: 1.5)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Bring to Front") {
                manager.focusWidget(for: card.id)
            }
            
            Menu("Move to Folder") {
                Button("None (Uncategorized)") {
                    if let idx = manager.store.notes.firstIndex(where: { $0.id == card.id }) {
                        manager.store.notes[idx].folderId = nil
                    }
                }
                Divider()
                ForEach(manager.store.folders) { f in
                    Button(f.name) {
                        if let idx = manager.store.notes.firstIndex(where: { $0.id == card.id }) {
                            manager.store.notes[idx].folderId = f.id
                        }
                    }
                }
            }
            
            Divider()
            
            Button("Remove from Folder") {
                if let idx = manager.store.notes.firstIndex(where: { $0.id == card.id }) {
                    manager.store.notes[idx].folderId = nil
                }
            }
        }
        .help("Click to focus this note on desktop")
    }
    
    // MARK: - Empty States
    private var emptyFoldersView: some View {
        VStack(spacing: 12) {
            Image(systemName: "folder.fill.badge.questionmark")
                .font(.system(size: 36, weight: .light))
                .foregroundColor(isDark ? Color.white.opacity(0.4) : Color.black.opacity(0.35))
            
            Text("No Folders Yet")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(isDark ? .white : .black)
            
            Text("Click the + button above to create your first folder.")
                .font(.system(size: 12.5, weight: .regular))
                .foregroundColor(isDark ? Color.white.opacity(0.55) : Color.black.opacity(0.50))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
    
    private func emptyFolderNotesView(folder: NoteFolder) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 36, weight: .light))
                .foregroundColor(isDark ? Color.white.opacity(0.4) : Color.black.opacity(0.35))
            
            Text("No Notes in \"\(folder.name)\"")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(isDark ? .white : .black)
            
            Text("Assign a note to this folder using the folder menu on any note card, or click + above to add one.")
                .font(.system(size: 12.5, weight: .regular))
                .foregroundColor(isDark ? Color.white.opacity(0.55) : Color.black.opacity(0.50))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
    
    // MARK: - Helpers
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
    
    private func cycleWallpaper() {
        SensoryFeedback.buttonClicked()
        let nextPath = WallpaperPackManager.shared.cycleNextWallpaper(after: note.headerImagePath)
        withAnimation(.easeInOut(duration: 0.2)) {
            note.headerImagePath = nextPath
        }
    }
    
    private func selectCustomHeaderImage() {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.image, .heic, .png, .jpeg]
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canChooseFiles = true
        openPanel.title = "Select Folders Card Background Image"
        
        if openPanel.runModal() == .OK, let url = openPanel.url {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                note.headerImagePath = url.path
            }
            SensoryFeedback.buttonClicked()
        }
    }
    
    // MARK: - Resize Drag Handles
    @ViewBuilder
    private var resizeHandles: some View {
        // Right Edge
        HStack {
            Spacer()
            Rectangle()
                .fill(Color.clear)
                .frame(width: 20, height: max(20, cardHeight - 20))
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 1)
                        .onChanged { value in
                            if dragInitialWidth == nil { dragInitialWidth = note.width }
                            let base = dragInitialWidth ?? note.width
                            let newW = max(minCardWidth, min(maxCardWidth, base + Double(value.translation.width)))
                            if abs(note.width - newW) >= 0.5 {
                                note.width = newW
                                WidgetWindowManager.shared.updateWindowSize(for: note.id, newWidth: newW, newHeight: note.height)
                            }
                        }
                        .onEnded { _ in
                            dragInitialWidth = nil
                            SensoryFeedback.buttonClicked()
                        }
                )
                .onHover { inside in
                    isHoveringResizeW = inside
                    if inside {
                        NSCursor.resizeLeftRight.push()
                    } else {
                        NSCursor.pop()
                    }
                }
        }
        .frame(width: cardWidth, height: cardHeight, alignment: .topTrailing)

        // Bottom Edge
        VStack {
            Spacer()
            Rectangle()
                .fill(Color.clear)
                .frame(width: max(20, cardWidth - 20), height: 20)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 1)
                        .onChanged { value in
                            if dragInitialHeight == nil { dragInitialHeight = note.height }
                            let base = dragInitialHeight ?? note.height
                            let newH = max(minCardHeight, min(maxCardHeight, base + Double(value.translation.height)))
                            if abs(note.height - newH) >= 0.5 {
                                note.height = newH
                                WidgetWindowManager.shared.updateWindowSize(for: note.id, newWidth: note.width, newHeight: newH)
                            }
                        }
                        .onEnded { _ in
                            dragInitialHeight = nil
                            SensoryFeedback.buttonClicked()
                        }
                )
                .onHover { inside in
                    isHoveringResizeH = inside
                    if inside {
                        NSCursor.resizeUpDown.push()
                    } else {
                        NSCursor.pop()
                    }
                }
        }
        .frame(width: cardWidth, height: cardHeight, alignment: .bottomLeading)

        // Bottom-Right Corner
        VStack {
            Spacer()
            HStack {
                Spacer()
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: 26, height: 26)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 1)
                        .onChanged { value in
                            if dragInitialWidth == nil { dragInitialWidth = note.width }
                            if dragInitialHeight == nil { dragInitialHeight = note.height }
                            let baseW = dragInitialWidth ?? note.width
                            let baseH = dragInitialHeight ?? note.height
                            let newW = max(minCardWidth, min(maxCardWidth, baseW + Double(value.translation.width)))
                            let newH = max(minCardHeight, min(maxCardHeight, baseH + Double(value.translation.height)))
                            if abs(note.width - newW) >= 0.5 || abs(note.height - newH) >= 0.5 {
                                note.width = newW
                                note.height = newH
                                WidgetWindowManager.shared.updateWindowSize(for: note.id, newWidth: newW, newHeight: newH)
                            }
                        }
                        .onEnded { _ in
                            dragInitialWidth = nil
                            dragInitialHeight = nil
                            SensoryFeedback.buttonClicked()
                        }
                )
                .onHover { inside in
                    isHoveringResizeCorner = inside
                    if inside {
                        NSCursor.crosshair.push()
                    } else {
                        NSCursor.pop()
                    }
                }
            }
        }
        .frame(width: cardWidth, height: cardHeight, alignment: .bottomTrailing)
    }
}

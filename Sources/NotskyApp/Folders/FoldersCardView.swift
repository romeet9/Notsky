import SwiftUI
import AppKit

@MainActor
public struct FoldersCardView: View {
    @Binding public var note: NoteCard
    @Environment(\.colorScheme) private var colorScheme
    
    public var onSpawnWidget: () -> Void = {}
    public var onDelete: () -> Void = {}
    
    private var manager = WidgetWindowManager.shared
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
                    .background(.cardMaterial)
                
                VStack(spacing: 0) {
                    topToolbar
                        .padding(.top, 12)
                        .padding(.horizontal, 16)
                    
                    if isCreatingFolder {
                        newFolderInputField
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                            .motionTransition(.asymmetric(
                                insertion: .move(edge: .top).combined(with: .opacity),
                                removal: .move(edge: .top).combined(with: .opacity)
                            ))
                    }
                    
                    contentGridView
                        .padding(.horizontal, 16)
                        .padding(.top, 6)
                }
                .motionAnimation(.spring(response: 0.32, dampingFraction: 0.82), value: isCreatingFolder)
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
            CardResizeHandles(
                note: $note,
                cardWidth: cardWidth,
                cardHeight: cardHeight,
                widthRange: minCardWidth...maxCardWidth,
                heightRange: minCardHeight...maxCardHeight
            )
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
                    withMotion(.spring(response: 0.30, dampingFraction: 0.82)) {
                        selectedFolderId = nil
                    }
                }) {
                    HStack(spacing: 6) {
                        RemixImage(.arrowLeftSLine, scaledSize: 12.5)
                            .foregroundStyle(isDark ? .white : .black)
                        
                        RemixImage(.folderFill, scaledSize: 14)
                            .foregroundStyle(.blue)
                        
                        Text(folder.name)
                            .scaledFont(size: 13, weight: .medium)
                            .foregroundStyle(isDark ? .white : .black)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 36)
                    .background(buttonBackgroundColor(hovering: isHoveringBack), in: Capsule())
                    .overlay { Capsule().strokeBorder(specularBorderGradient, lineWidth: 0.75) }
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
                    
                    Text("\(notesInCurrentFolder.count) notes")
                        .scaledFont(size: 12, weight: .medium, design: .rounded)
                        .foregroundStyle(isDark ? .white.opacity(0.9) : .black.opacity(0.8))
                }
                .padding(.horizontal, 12)
                .frame(height: 36)
                .background(buttonBackgroundColor(hovering: false), in: Capsule())
                .overlay { Capsule().strokeBorder(specularBorderGradient, lineWidth: 0.75) }
                .shadow(color: Color.black.opacity(0.35), radius: 6, y: 2)
            } else {
                // Folders Title Capsule
                HStack(spacing: 6) {
                    RemixImage(.folderFill, scaledSize: 14)
                        .foregroundStyle(.blue)
                    
                    Text("Folders")
                        .scaledFont(size: 13, weight: .medium)
                        .foregroundStyle(isDark ? .white : .black)
                }
                .padding(.horizontal, 16)
                .frame(height: 36)
                .background(buttonBackgroundColor(hovering: false), in: Capsule())
                .overlay { Capsule().strokeBorder(specularBorderGradient, lineWidth: 0.75) }
                .shadow(color: Color.black.opacity(0.35), radius: 6, y: 2)
                
                // Folders Count Capsule
                HStack(spacing: 5) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 7, height: 7)
                    
                    Text("\(manager.store.folders.count) folders")
                        .scaledFont(size: 12, weight: .medium, design: .rounded)
                        .foregroundStyle(isDark ? .white.opacity(0.9) : .black.opacity(0.8))
                }
                .padding(.horizontal, 12)
                .frame(height: 36)
                .background(buttonBackgroundColor(hovering: false), in: Capsule())
                .overlay { Capsule().strokeBorder(specularBorderGradient, lineWidth: 0.75) }
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
                    withMotion(.easeInOut(duration: 0.2)) {
                        isCreatingFolder.toggle()
                        if isCreatingFolder {
                            newFolderName = ""
                            Task { @MainActor in
                                try? await Task.sleep(for: .seconds(0.05))
                                isNewFolderFocused = true
                            }
                        }
                    }
                }
            }) {
                RemixImage(isCreatingFolder ? .closeLine : .addLine, scaledSize: 15)
                    .foregroundStyle(isDark ? .white.opacity(0.9) : .black.opacity(0.75))
                    .frame(width: 36, height: 36)
                    .background(buttonBackgroundColor(hovering: isHoveringPlus), in: Circle())
                    .overlay { Circle().strokeBorder(specularBorderGradient, lineWidth: 0.75) }
            }
            .buttonStyle(.plain)
            .onHover { isHoveringPlus = $0 }
            .help(selectedFolderId != nil ? LocalizedStringKey("Add Note in this Folder") : (isCreatingFolder ? LocalizedStringKey("Cancel") : LocalizedStringKey("New Folder")))
            
            Spacer()
            
            // Action Cluster Pill
            HStack(spacing: 11) {
                // Pin Button (Pin on Top / Floating)
                Button(action: {
                    SensoryFeedback.buttonClicked()
                    withMotion(.spring(response: 0.25, dampingFraction: 0.8)) {
                        note.isPinned.toggle()
                        WidgetWindowManager.shared.setPinned(note.isPinned, for: note.id)
                    }
                }) {
                    RemixImage(note.isPinned ? .pushpinFill : .pushpinLine, scaledSize: 14.5)
                        .foregroundStyle(note.isPinned ? Color.orange : (isDark ? .white.opacity(0.85) : .black.opacity(0.75)))
                }
                .buttonStyle(.plain)
                .help(note.isPinned ? LocalizedStringKey("Unpin (Desktop Canvas)") : LocalizedStringKey("Pin on Top (Floating)"))
                
                // Cycle Wallpaper Button
                Button(action: {
                    cycleWallpaper()
                }) {
                    RemixImage(.refreshLine, scaledSize: 14.5)
                        .foregroundStyle(isDark ? .white.opacity(0.85) : .black.opacity(0.75))
                }
                .buttonStyle(.plain)
                .help("Next Wallpaper in Pack")
                
                // Custom Header Image / Wallpaper Picker
                Button(action: {
                    SensoryFeedback.buttonClicked()
                    selectCustomHeaderImage()
                }) {
                    RemixImage(.imageLine, scaledSize: 14.5)
                        .foregroundStyle(isDark ? .white.opacity(0.85) : .black.opacity(0.75))
                }
                .buttonStyle(.plain)
                .help("Change Header Image")
                
                // Delete Widget Button
                Button(action: {
                    SensoryFeedback.buttonClicked()
                    onDelete()
                }) {
                    RemixImage(.deleteBinLine, scaledSize: 14.5)
                        .foregroundStyle(isDark ? .white.opacity(0.85) : .black.opacity(0.75))
                }
                .buttonStyle(.plain)
                .help("Delete Widget")
            }
            .padding(.horizontal, 12)
            .frame(height: 36)
            .background(buttonBackgroundColor(hovering: isHoveringTools), in: Capsule())
            .overlay { Capsule().strokeBorder(specularBorderGradient, lineWidth: 0.75) }
            .onHover { isHoveringTools = $0 }
        }
    }
    
    // MARK: - New Folder Input Field
    private var newFolderInputField: some View {
        HStack(spacing: 8) {
            RemixImage(.folderAddFill, scaledSize: 16)
                .foregroundStyle(.blue)
            
            TextField("Folder Name", text: $newFolderName)
                .textFieldStyle(.plain)
                .scaledFont(size: 13, weight: .medium)
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
        .background(.cardMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
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
        withMotion(.easeInOut(duration: 0.2)) {
            isCreatingFolder = false
        }
    }
    
    // MARK: - Content Grid View
    private var contentGridView: some View {
        ScrollView(.vertical) {
            if let folder = currentFolder {
                // Display notes inside selected folder
                if notesInCurrentFolder.isEmpty {
                    FolderNotesEmptyState(folder: folder, isDark: isDark)
                        .padding(.top, 24)
                } else {
                    LazyVGrid(columns: gridColumns, spacing: 12) {
                        ForEach(notesInCurrentFolder) { noteItem in
                            FolderNoteTile(card: noteItem, isDark: isDark, sheetBackgroundColor: sheetBackgroundColor, specularBorderGradient: specularBorderGradient)
                        }
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
            } else {
                // Display all folders
                if manager.store.folders.isEmpty {
                    FoldersEmptyState(isDark: isDark)
                        .padding(.top, 24)
                } else {
                    LazyVGrid(columns: gridColumns, spacing: 12) {
                        ForEach(manager.store.folders) { folder in
                            FolderTile(folder: folder, isDark: isDark, sheetBackgroundColor: sheetBackgroundColor, specularBorderGradient: specularBorderGradient, selectedFolderId: $selectedFolderId, renamingFolderId: $renamingFolderId, renameText: $renameText, isRenameFocused: $isRenameFocused)
                        }
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
            }
        }
        .scrollIndicators(.hidden)
        .contentEdgeFade(top: 10, bottom: 20)
    }
    
    // MARK: - Square Folder Tile (Matching North Sky AI Card Spec)
    
    // MARK: - Square Note Tile (Inside a Folder)
    
    // MARK: - Empty States
    
    
    // MARK: - Helpers
    private func formattedDate(_ date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated).day())
    }
    
    private func cycleWallpaper() {
        CardWallpaperActions.cycle($note)
    }
    
    private func selectCustomHeaderImage() {
        CardWallpaperActions.chooseCustomImage($note, panelTitle: String(localized: "Select Folders Card Background Image"))
    }
    
    // MARK: - Resize Drag Handles
}

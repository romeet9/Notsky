import SwiftUI
import AppKit

// MARK: - Native macOS Behind-Window Visual Effect Blur

public struct VisualEffectBlur: NSViewRepresentable {
    public var material: NSVisualEffectView.Material = .hudWindow
    public var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow
    public var state: NSVisualEffectView.State = .active
    
    public init(
        material: NSVisualEffectView.Material = .hudWindow,
        blendingMode: NSVisualEffectView.BlendingMode = .behindWindow,
        state: NSVisualEffectView.State = .active
    ) {
        self.material = material
        self.blendingMode = blendingMode
        self.state = state
    }
    
    public func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = state
        view.wantsLayer = true
        return view
    }
    
    public func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = state
    }
}

// MARK: - Drawer Shelf View

@MainActor
public struct DrawerShelfView: View {
    @ObservedObject private var manager = WidgetWindowManager.shared
    @ObservedObject private var drawerManager = DrawerWindowManager.shared
    @Bindable private var settings = AppSettings.shared
    public let onClose: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    private var isDark: Bool {
        settings.appearanceMode == "Dark" || (settings.appearanceMode == "System" && colorScheme == .dark)
    }
    
    // Exact symmetrical padding
    private let horizontalPadding: CGFloat = 36.0
    private let bottomPadding: CGFloat = 36.0
    
    // Balanced neutral dark gradient (sweet spot coverage around bottom 60%)
    private var neutralDarkGradient: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: Color.black.opacity(0.0), location: 0.0),
                .init(color: Color.black.opacity(0.0), location: 0.36),
                .init(color: Color.black.opacity(isDark ? 0.25 : 0.12), location: 0.48),
                .init(color: Color.black.opacity(isDark ? 0.58 : 0.32), location: 0.68),
                .init(color: Color.black.opacity(isDark ? 0.82 : 0.55), location: 0.84),
                .init(color: Color.black.opacity(isDark ? 0.92 : 0.68), location: 1.0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    public init(onClose: @escaping () -> Void = {}) {
        self.onClose = onClose
    }
    
    public var body: some View {
        ZStack(alignment: .bottom) {
            // 1. Deep Behind-Window Native macOS Blur (Balanced height mask)
            VisualEffectBlur(material: isDark ? .hudWindow : .underWindowBackground, blendingMode: .behindWindow)
                .mask(
                    LinearGradient(
                        stops: [
                            .init(color: Color.black.opacity(0.0), location: 0.0),
                            .init(color: Color.black.opacity(0.0), location: 0.36),
                            .init(color: Color.black.opacity(0.50), location: 0.52),
                            .init(color: Color.black.opacity(0.88), location: 0.72),
                            .init(color: Color.black.opacity(1.00), location: 0.92)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .ignoresSafeArea()
                .opacity(drawerManager.isContentVisible ? 1.0 : 0.0)
                .animation(.easeInOut(duration: 0.30), value: drawerManager.isContentVisible)
            
            // 2. Extra High-Diffusion Optical Layer (Balanced height mask)
            Color.black.opacity(0.01)
                .background(.ultraThinMaterial)
                .mask(
                    LinearGradient(
                        stops: [
                            .init(color: Color.black.opacity(0.0), location: 0.0),
                            .init(color: Color.black.opacity(0.0), location: 0.38),
                            .init(color: Color.black.opacity(0.40), location: 0.55),
                            .init(color: Color.black.opacity(0.80), location: 0.75),
                            .init(color: Color.black.opacity(1.00), location: 0.92)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .ignoresSafeArea()
                .opacity(drawerManager.isContentVisible ? 1.0 : 0.0)
                .animation(.easeInOut(duration: 0.30), value: drawerManager.isContentVisible)
            
            // 3. Pure Deep Dark Neutral Gradient Scrim (Balanced height mask)
            neutralDarkGradient
                .ignoresSafeArea()
                .opacity(drawerManager.isContentVisible ? 1.0 : 0.0)
                .animation(.easeInOut(duration: 0.30), value: drawerManager.isContentVisible)
            
            // 4. Pure Cards Horizontal Shelf at Bottom
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                
                if manager.store.notes.isEmpty {
                    emptyShelfState
                        .padding(.bottom, bottomPadding)
                        .padding(.horizontal, horizontalPadding)
                        .opacity(drawerManager.isContentVisible ? 1.0 : 0.0)
                        .blur(radius: drawerManager.isContentVisible ? 0 : 40)
                        .brightness(drawerManager.isContentVisible ? 0.0 : -0.30)
                } else {
                    cardsHorizontalScrollView
                        .padding(.bottom, bottomPadding)
                        .opacity(drawerManager.isContentVisible ? 1.0 : 0.0)
                        .scaleEffect(drawerManager.isContentVisible ? 1.0 : 0.93, anchor: .bottom)
                        .offset(y: drawerManager.isContentVisible ? 0 : 50)
                        .blur(radius: drawerManager.isContentVisible ? 0 : 48)
                        .brightness(drawerManager.isContentVisible ? 0.0 : -0.32)
                        .animation(
                            .spring(response: 0.38, dampingFraction: 0.84, blendDuration: 0.15),
                            value: drawerManager.isContentVisible
                        )
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            drawerManager.hideDrawer()
        }
        .preferredColorScheme(settings.preferredColorScheme)
    }
    
    // MARK: - Cards Horizontal Carousel
    
    @ViewBuilder
    private var cardsHorizontalScrollView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .bottom, spacing: 24) {
                ForEach($manager.store.notes) { $note in
                    VStack(spacing: 0) {
                        if note.cardType == .finder {
                            FinderCardView(
                                note: $note,
                                onSpawnWidget: {
                                    let origin = manager.windowOrigin(for: note.id)
                                    manager.spawnNewWidget(near: origin)
                                },
                                onDelete: {
                                    manager.closeWidget(noteId: note.id)
                                }
                            )
                        } else if note.cardType == .notes {
                            FreeformNoteCardView(
                                note: $note,
                                onSpawnWidget: {
                                    let origin = manager.windowOrigin(for: note.id)
                                    manager.spawnNewFreeformNoteWidget(near: origin)
                                },
                                onDelete: {
                                    manager.closeWidget(noteId: note.id)
                                }
                            )
                        } else {
                            NoteCardView(
                                note: $note,
                                onSpawnWidget: {
                                    let origin = manager.windowOrigin(for: note.id)
                                    manager.spawnNewWidget(near: origin)
                                },
                                onDelete: {
                                    manager.closeWidget(noteId: note.id)
                                }
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, horizontalPadding)
        }
    }
    
    // MARK: - Empty State
    
    @ViewBuilder
    private var emptyShelfState: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.stack.3d.up.slash")
                .font(.system(size: 42, weight: .light))
                .foregroundStyle(isDark ? Color.white.opacity(0.35) : Color.black.opacity(0.30))
            
            Text("Your Shelf is Empty")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(isDark ? Color.white.opacity(0.85) : Color.black.opacity(0.75))
            
            Text("Create your first task checklist or notes card.")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(isDark ? Color.white.opacity(0.5) : Color.black.opacity(0.45))
            
            HStack(spacing: 14) {
                Button(action: {
                    SensoryFeedback.widgetSpawned()
                    manager.spawnNewWidget()
                }) {
                    Text("Add Task Group")
                        .font(.system(size: 13, weight: .medium))
                        .padding(.horizontal, 16)
                        .frame(height: 36)
                        .background(Color.blue, in: Capsule())
                        .foregroundStyle(Color.white)
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    SensoryFeedback.widgetSpawned()
                    manager.spawnNewFreeformNoteWidget()
                }) {
                    Text("Add Notes Card")
                        .font(.system(size: 13, weight: .medium))
                        .padding(.horizontal, 16)
                        .frame(height: 36)
                        .background(isDark ? Color.white.opacity(0.15) : Color.black.opacity(0.08), in: Capsule())
                        .foregroundStyle(isDark ? Color.white : Color.black)
                }
                .buttonStyle(.plain)

                Button(action: {
                    SensoryFeedback.widgetSpawned()
                    manager.spawnNewFinderWidget()
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 11))
                        Text("Add AI Finder")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 36)
                    .background(Color.cyan.opacity(0.85), in: Capsule())
                    .foregroundStyle(Color.white)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 4)
        }
    }
}

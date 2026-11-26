import SwiftUI
import AppKit

/// Voice card: hold the hot key (or the orb) and say what to do in Notsky: add a task, add a note, control music.
@MainActor
public struct VoiceOpenCardView: View {
    @Binding public var note: NoteCard
    @Environment(\.colorScheme) private var colorScheme

    public var onSpawnWidget: () -> Void = {}
    public var onDelete: () -> Void = {}

    private var service = VoiceOpenService.shared
    private var settings: AppSettings { AppSettings.shared }

    @State private var isHoveringCard = false
    @State private var isWindowVisible = true
    @State private var isHoldingOrb = false

    private var cardWidth: CGFloat { CGFloat(note.width) }
    private var cardHeight: CGFloat { CGFloat(note.height) }
    private let headerHeight: CGFloat = 53
    private var sheetHeight: CGFloat { max(100, cardHeight - headerHeight) }
    private let cornerRadius: CGFloat = 40

    private var isDark: Bool {
        if let override = settings.preferredColorScheme { return override == .dark }
        return colorScheme == .dark
    }

    private var sheetBackgroundColor: Color {
        let opacity = settings.backgroundOpacity
        return isDark ? Color(white: 0.12).opacity(opacity) : Color.white.opacity(opacity)
    }

    private var specularBorderGradient: LinearGradient { WidgetCardDesign.specularBorder(isDark: isDark) }
    private var primaryText: Color { isDark ? .white : .black }
    private var secondaryText: Color { isDark ? .white.opacity(0.6) : .black.opacity(0.5) }
    private var accent: Color { ImageLuminanceDetector.dominantAccentColor(at: note.headerImagePath) }
    private var hotKey: String { service.hotKeyPreset.display }

    private var orbMode: VoiceOrbMode {
        switch service.phase {
        case .listening: return .listening
        case .thinking: return .thinking
        case .done: return .success
        case .failed: return .error
        default: return .idle
        }
    }

    /// Animate only when someone can see it: never while occluded, and when idle only while
    /// Notsky Next is frontmost or the pointer is over the card. Hot-key use from other apps
    /// leaves the idle state, so the orb comes alive then too.
    private var orbAnimating: Bool {
        guard isWindowVisible else { return false }
        switch service.phase {
        case .listening, .thinking, .done, .failed: return true
        default: return service.appIsActive || isHoveringCard
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
            // 1. Wallpaper header
            HeaderImageView(imagePath: note.headerImagePath)
                .frame(width: cardWidth, height: cardHeight)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))

            // 2. Glass sheet
            ZStack(alignment: .top) {
                sheetBackgroundColor
                    .background(.ultraThinMaterial)

                Group {
                    if service.phase == .needsPermission, let issue = service.permissionIssue {
                        permissionState(issue)
                    } else {
                        heroContent
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 18)
            }
            .frame(width: cardWidth, height: sheetHeight)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(specularBorderGradient, lineWidth: 0.75)
            )
            .offset(y: headerHeight)
            .zIndex(1)

            // 3. Header pills
            headerPills
                .frame(width: cardWidth, height: headerHeight)
                .zIndex(10)
        }
        .frame(width: cardWidth, height: cardHeight)
        .background(WindowVisibilityReader { isWindowVisible = $0 })
        .onHover { isHoveringCard = $0 }
        .onAppear { service.refreshPermissions() }
        .onChange(of: service.phase) { _, phase in
            if phase != .listening { isHoldingOrb = false }
        }
        .contextMenu { contextMenuItems }
    }

    // MARK: - Header pills

    private var headerPills: some View {
        HStack(spacing: 8) {
            WidgetHeaderCapsule(isDark: isDark, baseOpacity: settings.backgroundOpacity) {
                HStack(spacing: 6) {
                    Image(systemName: "waveform")
                        .scaledFont(size: 12, weight: .semibold)
                        .foregroundStyle(accent)
                    Text("Voice")
                        .scaledFont(size: 13, weight: .medium)
                        .foregroundStyle(primaryText)
                        .lineLimit(1)
                }
            }

            WidgetHeaderCapsule(isDark: isDark, baseOpacity: settings.backgroundOpacity) {
                HStack(spacing: 5) {
                    if service.isActive && !service.hotKeyRegistered {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .scaledFont(size: 10, weight: .semibold)
                            .foregroundStyle(.orange)
                    }
                    Text(hotKey)
                        .scaledFont(size: 12, weight: .medium, design: .rounded)
                        .foregroundStyle(isDark ? .white.opacity(0.9) : .black.opacity(0.8))
                }
            }
            .contentShape(Capsule())
            .onTapGesture { SettingsWindowManager.shared.showSettings(item: .voice) }
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(Text("Push-to-talk shortcut \(hotKey)"))
            .help(Text("Change the push-to-talk shortcut"))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    // MARK: - Orb

    private func orb(diameter: CGFloat, dimmed: Bool = false) -> some View {
        VoiceOrbView(
            mode: orbMode,
            diameter: diameter,
            level: { VoiceOpenService.shared.level },
            animating: orbAnimating,
            dimmed: dimmed
        )
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard !isHoldingOrb else { return }
                    isHoldingOrb = true
                    service.beginListeningFromPointer()
                }
                .onEnded { _ in
                    isHoldingOrb = false
                    service.endListening()
                }
        )
        .accessibilityElement()
        .accessibilityLabel(Text("Voice, hold \(hotKey) to talk"))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: Text("Start or stop listening")) {
            if service.phase == .listening { service.endListening() } else { service.beginListening() }
        }
        .help(Text("Hold to talk"))
    }

    // MARK: - Hero (idle, listening, thinking, done, failed)

    private var heroContent: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            orb(diameter: 116)
                .padding(.bottom, 24)

            Text(transcriptText)
                .scaledFont(size: 15, weight: service.transcript.isEmpty ? .medium : .semibold)
                .foregroundStyle(service.transcript.isEmpty ? primaryText.opacity(0.7) : primaryText)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .truncationMode(.head)
                .frame(maxWidth: .infinity, minHeight: 40, alignment: .center)
                .contentTransition(.opacity)
                .motionAnimation(.easeOut(duration: 0.15), value: service.transcript, fadeWhenReduced: true)
                .accessibilityLabel(Text(transcriptText))

            statusLine
                .padding(.top, 6)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
    }

    private var transcriptText: String {
        if !service.transcript.isEmpty { return service.transcript }
        switch service.phase {
        case .listening: return String(localized: "Listening…")
        default: return String(localized: "What should I do?")
        }
    }

    @ViewBuilder
    private var statusLine: some View {
        Group {
            switch service.phase {
            case .done where !service.pendingConfirmations.isEmpty:
                VStack(spacing: 8) {
                    Text(service.pendingConfirmations[0].prompt)
                        .foregroundStyle(primaryText.opacity(0.9))
                        .lineLimit(2)
                    HStack(spacing: 8) {
                        Button {
                            service.cancelPending()
                        } label: {
                            Text("Cancel")
                                .padding(.horizontal, 14)
                                .frame(height: 30)
                                .background(sheetBackgroundColor, in: Capsule())
                                .overlay { Capsule().strokeBorder(specularBorderGradient, lineWidth: 0.75) }
                                .foregroundStyle(primaryText)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Cancel")
                        Button {
                            service.confirmPending()
                        } label: {
                            Text("Confirm")
                                .padding(.horizontal, 14)
                                .frame(height: 30)
                                .background(Color.red.opacity(0.85), in: Capsule())
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Confirm")
                    }
                }
            case .done:
                HStack(spacing: 8) {
                    Text(service.confirmation ?? "")
                        .foregroundStyle(primaryText.opacity(0.85))
                        .lineLimit(2)
                        .truncationMode(.middle)
                    if service.canUndo {
                        Button {
                            service.undo()
                        } label: {
                            Text("Undo")
                                .underline()
                                .foregroundStyle(accent)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Undo")
                    }
                }
            case .failed:
                Text(service.failureMessage ?? String(localized: "Something went wrong"))
                    .foregroundStyle(secondaryText)
            case .listening:
                Text("Release to send")
                    .foregroundStyle(secondaryText)
            case .thinking:
                Text("Working on it…")
                    .foregroundStyle(secondaryText)
            default:
                if GroqAccount.shared.hasKey {
                    Text("Hold \(hotKey) · Ask Notsky AI anything")
                        .foregroundStyle(secondaryText)
                } else {
                    Text("Hold \(hotKey) · Add a task, a note, or control music")
                        .foregroundStyle(secondaryText)
                }
            }
        }
        .scaledFont(size: 12, weight: .medium)
        .multilineTextAlignment(.center)
        .lineLimit(3)
        .frame(maxWidth: .infinity, minHeight: 18)
        .motionTransition(.opacity)
    }

    // MARK: - Permission

    private func permissionState(_ issue: VoiceOpenService.PermissionIssue) -> some View {
        VStack(spacing: 12) {
            Spacer(minLength: 0)
            orb(diameter: 76, dimmed: true)
                .padding(.bottom, 6)
            Text(issue == .microphone
                 ? "Allow Notsky Next to use the microphone in System Settings › Privacy & Security › Microphone"
                 : "Allow Notsky Next to use speech recognition in System Settings › Privacy & Security › Speech Recognition")
                .scaledFont(size: 13, weight: .regular)
                .foregroundStyle(primaryText.opacity(0.8))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                SensoryFeedback.buttonClicked()
                service.openPrivacySettings(issue)
            } label: {
                Text("Open System Settings")
                    .scaledFont(size: 13, weight: .medium)
                    .foregroundStyle(primaryText)
                    .padding(.horizontal, 16)
                    .frame(height: 36)
                    .background(sheetBackgroundColor, in: Capsule())
                    .overlay { Capsule().strokeBorder(specularBorderGradient, lineWidth: 0.75) }
            }
            .buttonStyle(.plain)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Context menu

    @ViewBuilder
    private var contextMenuItems: some View {
        Button {
            CardWallpaperActions.chooseCustomImage($note, panelTitle: String(localized: "Select Voice Card Background Image"))
        } label: {
            Label("Change Header Image...", systemImage: "photo.on.rectangle")
        }
        Button {
            CardWallpaperActions.cycle($note)
        } label: {
            Label("Next Wallpaper in Pack", systemImage: "arrow.clockwise")
        }
        Button {
            CardActions.togglePinned($note, haptic: false)
        } label: {
            Label(note.isPinned ? LocalizedStringKey("Unpin (Wallpaper Canvas Mode)") : LocalizedStringKey("Pin on Top (Floating)"), systemImage: note.isPinned ? "pin.slash" : "pin")
        }
        Button {
            SettingsWindowManager.shared.showSettings(item: .voice)
        } label: {
            Label("Voice Settings...", systemImage: "waveform")
        }
        Divider()
        Button("New Voice Card") { onSpawnWidget() }
        Button(role: .destructive) {
            SensoryFeedback.taskDeleted()
            onDelete()
        } label: {
            Label("Delete Widget", systemImage: "trash")
        }
    }
}

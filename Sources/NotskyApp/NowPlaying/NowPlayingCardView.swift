import SwiftUI
import AppKit

@MainActor
public struct NowPlayingCardView: View {
    @Binding public var note: NoteCard
    @Environment(\.colorScheme) private var colorScheme

    public var onSpawnWidget: () -> Void = {}
    public var onDelete: () -> Void = {}

    private var service = NowPlayingService.shared
    private var settings: AppSettings { AppSettings.shared }

    @State private var scrubFraction: Double? = nil
    @State private var isHoveringBar = false
    @State private var isHoveringCard = false

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

    private var artworkSize: CGFloat { max(90, min(cardWidth - 64, sheetHeight - 168)) }

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
            // 1. Full-card header image (album artwork when available, wallpaper otherwise)
            Group {
                if let art = service.artwork, service.hasTrack {
                    Image(nsImage: art)
                        .resizable()
                        .interpolation(.high)
                        .antialiased(true)
                        .aspectRatio(contentMode: .fill)
                        .blur(radius: 24)
                        .scaleEffect(1.3)
                } else {
                    HeaderImageView(imagePath: note.headerImagePath)
                }
            }
            .frame(width: cardWidth, height: cardHeight)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .motionAnimation(.easeInOut(duration: 0.3), value: service.artwork == nil)

            // 2. Foreground content sheet
            ZStack(alignment: .top) {
                sheetBackgroundColor
                    .background(.ultraThinMaterial)

                Group {
                    if let denied = service.permissionDeniedSource {
                        permissionState(denied)
                    } else if service.hasTrack {
                        playerContent
                    } else {
                        emptyState
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

            // 3. Header pill row
            headerPills
                .frame(width: cardWidth, height: headerHeight)
                .zIndex(10)
        }
        .frame(width: cardWidth, height: cardHeight)
        .onHover { isHoveringCard = $0 }
        .onAppear { service.viewDidAppear() }
        .onDisappear { service.viewDidDisappear() }
        .contextMenu { contextMenuItems }
    }

    // MARK: - Header pills

    private var headerPills: some View {
        HStack(spacing: 8) {
            WidgetHeaderCapsule(isDark: isDark, baseOpacity: settings.backgroundOpacity) {
                HStack(spacing: 6) {
                    if let icon = service.sourceIcon {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 16, height: 16)
                    } else {
                        RemixImage(.music2Line, scaledSize: 14)
                            .foregroundStyle(accent)
                    }
                    Text(service.sourceName ?? "Now Playing")
                        .scaledFont(size: 13, weight: .medium)
                        .foregroundStyle(primaryText)
                        .lineLimit(1)
                }
            }
            .contentShape(Capsule())
            .onTapGesture { if service.hasTrack { service.activateSource() } }
            .accessibilityAddTraits(.isButton)

            if service.hasTrack {
                WidgetHeaderCapsule(isDark: isDark, baseOpacity: settings.backgroundOpacity) {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(service.isPlaying ? Color.green : Color.gray)
                            .frame(width: 7, height: 7)
                        Text(service.isPlaying ? "Playing" : "Paused")
                            .scaledFont(size: 12, weight: .medium, design: .rounded)
                            .foregroundStyle(isDark ? .white.opacity(0.9) : .black.opacity(0.8))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    // MARK: - Player

    private var playerContent: some View {
        VStack(spacing: 0) {
            artworkView
                .frame(width: artworkSize, height: artworkSize)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(specularBorderGradient, lineWidth: 0.75)
                )
                .shadow(color: .black.opacity(isDark ? 0.35 : 0.18), radius: 10, y: 4)
                .padding(.bottom, 12)

            VStack(spacing: 2) {
                Text(service.title)
                    .scaledFont(size: 15, weight: .semibold)
                    .foregroundStyle(primaryText)
                    .lineLimit(1)
                Text(service.artist)
                    .scaledFont(size: 13, weight: .regular)
                    .foregroundStyle(secondaryText)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)

            Spacer(minLength: 6)

            progressBar
            Spacer(minLength: 4)
            controls
        }
    }

    @ViewBuilder
    private var artworkView: some View {
        if let art = service.artwork {
            Image(nsImage: art)
                .resizable()
                .interpolation(.high)
                .antialiased(true)
                .aspectRatio(contentMode: .fill)
        } else {
            ZStack {
                HeaderImageView(imagePath: note.headerImagePath)
                RemixImage(.music2Line, scaledSize: (artworkSize * 0.3) * 1.15)
                    .foregroundStyle(.white.opacity(0.9))
            }
        }
    }

    private var progressBar: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { context in
            let duration = max(service.duration, 0)
            let live = service.position(at: context.date)
            let fraction = scrubFraction ?? (duration > 0 ? live / duration : 0)
            let shown = scrubFraction.map { $0 * duration } ?? live
            let height: CGFloat = (isHoveringBar || scrubFraction != nil) ? 6 : 4

            VStack(spacing: 4) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(primaryText.opacity(0.15))
                        Capsule()
                            .fill(primaryText.opacity(0.85))
                            .frame(width: max(height, geo.size.width * CGFloat(min(max(fraction, 0), 1))))
                    }
                    .frame(height: height)
                    .frame(maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                guard duration > 0 else { return }
                                scrubFraction = Double(min(max(value.location.x / geo.size.width, 0), 1))
                            }
                            .onEnded { value in
                                guard duration > 0 else { scrubFraction = nil; return }
                                let f = Double(min(max(value.location.x / geo.size.width, 0), 1))
                                service.seek(to: f * duration)
                                scrubFraction = nil
                            }
                    )
                    .onHover { isHoveringBar = $0 }
                    .motionAnimation(.easeOut(duration: 0.15), value: height)
                }
                .frame(height: 14)
                .accessibilityElement()
                .accessibilityLabel("Playback position")
                .accessibilityValue("\(Self.format(shown)) of \(Self.format(duration))")

                HStack {
                    Text(Self.format(shown))
                    Spacer()
                    Text("-" + Self.format(max(duration - shown, 0)))
                }
                .scaledFont(size: 11, weight: .medium)
                .monospacedDigit()
                .foregroundStyle(secondaryText)
            }
        }
    }

    private var controls: some View {
        HStack(spacing: 28) {
            controlButton(.skipBackFill, size: 18, label: "Previous Track") {
                service.previousTrack()
            }
            controlButton(service.isPlaying ? .pauseFill : .playFill, size: 26, label: service.isPlaying ? "Pause" : "Play") {
                service.togglePlayPause()
            }
            controlButton(.skipForwardFill, size: 18, label: "Next Track") {
                service.nextTrack()
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 40)
    }

    private func controlButton(_ symbol: RemixIcon, size: CGFloat, label: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button {
            SensoryFeedback.buttonClicked()
            action()
        } label: {
            RemixImage(symbol, scaledSize: size * 1.15)
                .foregroundStyle(primaryText.opacity(0.9))
                .frame(width: 44, height: 40)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .help(label)
    }

    // MARK: - Empty & permission states

    private var emptyState: some View {
        VStack(spacing: 10) {
            Spacer()
            RemixImage(.music2Line, scaledSize: 43.5)
                .foregroundStyle(secondaryText)
            Text("Not Playing")
                .scaledFont(size: 16, weight: .semibold)
                .foregroundStyle(primaryText.opacity(0.85))
            Button {
                SensoryFeedback.buttonClicked()
                service.openPlayer(.music)
            } label: {
                Text("Open Music")
                    .scaledFont(size: 13, weight: .medium)
                    .foregroundStyle(primaryText)
                    .padding(.horizontal, 16)
                    .frame(height: 36)
                    .background(sheetBackgroundColor, in: Capsule())
                    .overlay { Capsule().strokeBorder(specularBorderGradient, lineWidth: 0.75) }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open Music")
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func permissionState(_ app: NowPlayingSource) -> some View {
        VStack(spacing: 10) {
            Spacer()
            RemixImage(.lockFill, scaledSize: 34.5)
                .foregroundStyle(secondaryText)
            Text("Allow Notsky Next to control \(app.displayName) in System Settings › Privacy & Security › Automation")
                .scaledFont(size: 13, weight: .regular)
                .foregroundStyle(primaryText.opacity(0.8))
                .multilineTextAlignment(.center)
            Button {
                SensoryFeedback.buttonClicked()
                service.openAutomationSettings()
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
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Context menu & helpers

    @ViewBuilder
    private var contextMenuItems: some View {
        Button {
            CardWallpaperActions.chooseCustomImage($note, panelTitle: String(localized: "Select Now Playing Card Background Image"))
        } label: {
            RemixLabel("Change Header Image...", .imageLine)
        }
        Button {
            CardWallpaperActions.cycle($note)
        } label: {
            RemixLabel("Next Wallpaper in Pack", .refreshLine)
        }
        Button {
            CardActions.togglePinned($note, haptic: false)
        } label: {
            RemixLabel(note.isPinned ? LocalizedStringKey("Unpin (Wallpaper Canvas Mode)") : LocalizedStringKey("Pin on Top (Floating)"), note.isPinned ? .unpinLine : .pushpinLine)
        }
        Divider()
        Button("New Now Playing Card") { onSpawnWidget() }
        Button(role: .destructive) {
            SensoryFeedback.taskDeleted()
            onDelete()
        } label: {
            RemixLabel("Delete Widget", .deleteBinLine)
        }
    }

    private static func format(_ seconds: TimeInterval) -> String {
        let total = Int(max(0, seconds.isFinite ? seconds : 0))
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }
}

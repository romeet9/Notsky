import SwiftUI

/// Keycap-style label used by the shortcut lists in Settings.
struct ShortcutBadge: View {
    let key: LocalizedStringKey

    init(_ key: LocalizedStringKey) {
        self.key = key
    }

    var body: some View {
        Text(key)
            .scaledFont(size: 11.5, weight: .medium, design: .monospaced)
            .padding(.horizontal, 6)
            .padding(.vertical, 2.5)
            .background(Color.primary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
    }
}

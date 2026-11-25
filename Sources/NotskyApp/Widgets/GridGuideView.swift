import SwiftUI
import AppKit

// MARK: - Native macOS Desktop Widget Grid & Slot Guide

public struct GridGuideView: View {
    public var width: CGFloat = 281
    public var height: CGFloat = 364
    
    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 40, style: .continuous)
                .fill(.ultraThinMaterial)
                .opacity(0.8)
            
            RoundedRectangle(cornerRadius: 40, style: .continuous)
                .fill(Color.white.opacity(0.2))
            
            RoundedRectangle(cornerRadius: 40, style: .continuous)
                .strokeBorder(Color.white.opacity(0.6), lineWidth: 2)
        }
        .frame(width: width, height: height)
        .padding(30)
    }
}

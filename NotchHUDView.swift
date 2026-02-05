import SwiftUI

struct NotchHUDView: View {
    @StateObject private var nowPlaying = NowPlayingManager()
    @State private var expanded = false
    
    // Collapsed: simple album + soundbar. Expanded: full player
    // Shrink when nothing playing
    private var pillWidth: CGFloat {
        if !nowPlaying.info.hasContent {
            return expanded ? 400 : 60  // Just album art when nothing playing
        }
        return expanded ? 400 : 250
    }
    private var pillHeight: CGFloat { expanded ? 175 : 34 }
    
    var body: some View {
        VStack {
            ZStack {
                // Pure black background - squared top, rounded bottom
                UnevenRoundedRectangle(
                    topLeadingRadius: 0,
                    bottomLeadingRadius: expanded ? 24 : 14,
                    bottomTrailingRadius: expanded ? 24 : 14,
                    topTrailingRadius: 0,
                    style: .continuous
                )
                .fill(Color.black)
                
                // Content
                if expanded {
                    expandedContent
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                } else {
                    collapsedContent
                        .transition(.opacity)
                }
            }
            .frame(width: pillWidth, height: pillHeight)
            .clipShape(
                UnevenRoundedRectangle(
                    topLeadingRadius: 0,
                    bottomLeadingRadius: expanded ? 24 : 14,
                    bottomTrailingRadius: expanded ? 24 : 14,
                    topTrailingRadius: 0,
                    style: .continuous
                )
            )
            .shadow(color: .black.opacity(0.4), radius: 12, y: 6)
            .contentShape(
                UnevenRoundedRectangle(
                    topLeadingRadius: 0,
                    bottomLeadingRadius: expanded ? 24 : 14,
                    bottomTrailingRadius: expanded ? 24 : 14,
                    topTrailingRadius: 0,
                    style: .continuous
                )
            )
            .onHover { hovering in
                withAnimation {
                    expanded = hovering
                }
            }
            
            Spacer()
        }
        .frame(width: 400, height: 200, alignment: .top)
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: expanded)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: nowPlaying.info.hasContent)
    }
    
    // MARK: - Collapsed View
    // Simple: album photo on left, soundbar on right (only when playing)
    
    private var collapsedContent: some View {
        HStack(spacing: 0) {
            // Album artwork on left
            if let artwork = nowPlaying.artwork, nowPlaying.info.hasContent {
                Image(nsImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 24, height: 24)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(.white.opacity(0.2))
                    .frame(width: 24, height: 24)
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.6))
                    )
            }
            
            if nowPlaying.info.hasContent {
                Spacer()
                
                // Soundbar on right - only when content is playing
                AudioVisualizer(
                    isPlaying: nowPlaying.info.isPlaying,
                    barCount: 4,
                    color: nowPlaying.artwork != nil ? extractDominantColor(from: nowPlaying.artwork) : .white
                )
                .frame(width: 24, height: 18)
            }
        }
        .padding(.horizontal, nowPlaying.info.hasContent ? 8 : 18)
    }
    
    // MARK: - Expanded View
    
    private var expandedContent: some View {
        VStack(spacing: 14) {
            // Top section: Artwork + Info + Visualizer
            HStack(spacing: 14) {
                // Album artwork
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white.opacity(0.1))
                    
                    if let artwork = nowPlaying.artwork {
                        Image(nsImage: artwork)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Image(systemName: "music.note")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                
                // Track info
                VStack(alignment: .leading, spacing: 4) {
                    Text(nowPlaying.info.hasContent ? nowPlaying.info.title : "Nothing Playing")
                        .font(.system(size: 15, weight: .bold, design: .default))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .tracking(-0.2)
                    
                    if nowPlaying.info.hasContent {
                        Text(nowPlaying.info.artist)
                            .font(.system(size: 13, weight: .regular, design: .default))
                            .foregroundStyle(.white.opacity(0.6))
                            .lineLimit(1)
                            .tracking(-0.1)
                    }
                }
                .padding(.top, 4)
                
                Spacer(minLength: 0)
                
                // Audio visualizer
                if nowPlaying.info.isPlaying {
                    AudioVisualizer(
                        isPlaying: true,
                        barCount: 4,
                        color: nowPlaying.artwork != nil ? extractDominantColor(from: nowPlaying.artwork) : .white
                    )
                    .frame(width: 22, height: 18)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            
            // Progress section
            if nowPlaying.info.hasContent {
                HStack(spacing: 8) {
                    Text(nowPlaying.info.elapsedFormatted)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.5))
                        .frame(width: 36, alignment: .leading)
                    
                    // Progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(.white.opacity(0.2))
                            
                            Capsule()
                                .fill(.white.opacity(0.8))
                                .frame(width: max(0, geo.size.width * nowPlaying.info.progress))
                        }
                    }
                    .frame(height: 4)
                    
                    Text(nowPlaying.info.remainingFormatted)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.5))
                        .frame(width: 40, alignment: .trailing)
                }
                .padding(.horizontal, 16)
            }
            
            // Controls section
            if nowPlaying.info.hasContent {
                HStack(spacing: 0) {
                    // Favorite button
                    controlButton(
                        icon: nowPlaying.info.isFavorited ? "star.fill" : "star",
                        size: 18,
                        color: nowPlaying.info.isFavorited ? .yellow : .white
                    ) {
                        nowPlaying.toggleFavorite()
                    }
                    
                    Spacer()
                    
                    // Playback controls
                    HStack(spacing: 20) {
                        controlButton(icon: "backward.fill", size: 20) {
                            nowPlaying.previousTrack()
                        }
                        
                        controlButton(icon: nowPlaying.info.isPlaying ? "pause.fill" : "play.fill", size: 28) {
                            nowPlaying.togglePlayPause()
                        }
                        
                        controlButton(icon: "forward.fill", size: 20) {
                            nowPlaying.nextTrack()
                        }
                    }
                    
                    Spacer()
                    
                    // AirPlay button - opens Sound settings
                    controlButton(icon: "airplayaudio", size: 18) {
                        openSoundSettings()
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
        }
    }
    
    // MARK: - Helpers
    
    private func controlButton(icon: String, size: CGFloat, color: Color = .white, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(color)
        }
        .buttonStyle(.plain)
        .frame(width: 44, height: 44)
        .contentShape(Rectangle())
    }
    
    private func openSoundSettings() {
        // Open Sound settings panel for AirPlay/output selection
        if let url = URL(string: "x-apple.systempreferences:com.apple.Sound-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }
    
    // MARK: - Color Extraction
    
    private func extractDominantColor(from image: NSImage?) -> Color {
        guard let image = image else { return .white }
        
        // Simple approach: sample center area of image
        guard let tiffData = image.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData) else {
            return .white
        }
        
        let width = Int(bitmapImage.size.width)
        let height = Int(bitmapImage.size.height)
        
        guard width > 0 && height > 0 else { return .white }
        
        // Sample center region
        var rSum: CGFloat = 0
        var gSum: CGFloat = 0
        var bSum: CGFloat = 0
        var count = 0
        
        let startX = width / 4
        let endX = width * 3 / 4
        let startY = height / 4
        let endY = height * 3 / 4
        
        for y in stride(from: startY, to: endY, by: 5) {
            for x in stride(from: startX, to: endX, by: 5) {
                if let color = bitmapImage.colorAt(x: x, y: y) {
                    rSum += color.redComponent
                    gSum += color.greenComponent
                    bSum += color.blueComponent
                    count += 1
                }
            }
        }
        
        guard count > 0 else { return .white }
        
        // Average color
        let avgR = rSum / CGFloat(count)
        let avgG = gSum / CGFloat(count)
        let avgB = bSum / CGFloat(count)
        
        // Make it vibrant and visible
        let hsl = NSColor(red: avgR, green: avgG, blue: avgB, alpha: 1.0).toHSL()
        let vibrant = NSColor(
            hue: hsl.h,
            saturation: min(1.0, max(0.5, hsl.s * 1.2)),
            brightness: min(1.0, max(0.6, hsl.l)),
            alpha: 1.0
        )
        
        return Color(nsColor: vibrant)
    }
}

// MARK: - NSImage Extension

extension NSImage {
    func resized(to size: NSSize) -> NSImage? {
        let img = NSImage(size: size)
        img.lockFocus()
        self.draw(in: NSRect(origin: .zero, size: size), from: .zero, operation: .sourceOver, fraction: 1.0)
        img.unlockFocus()
        return img
    }
}

// MARK: - NSColor Extension

extension NSColor {
    func toHSL() -> (h: CGFloat, s: CGFloat, l: CGFloat) {
        let r = redComponent
        let g = greenComponent
        let b = blueComponent
        
        let max = Swift.max(r, g, b)
        let min = Swift.min(r, g, b)
        let delta = max - min
        
        var h: CGFloat = 0
        var s: CGFloat = 0
        let l = (max + min) / 2
        
        if delta != 0 {
            s = l > 0.5 ? delta / (2 - max - min) : delta / (max + min)
            
            switch max {
            case r:
                h = ((g - b) / delta + (g < b ? 6 : 0)) / 6
            case g:
                h = ((b - r) / delta + 2) / 6
            case b:
                h = ((r - g) / delta + 4) / 6
            default:
                break
            }
        }
        
        return (h, s, l)
    }
}

// MARK: - Audio Visualizer

struct AudioVisualizer: View {
    var isPlaying: Bool
    var barCount: Int
    var color: Color = .white
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<barCount, id: \.self) { index in
                AnimatedBar(isPlaying: isPlaying, delay: Double(index) * 0.1, barIndex: index, color: color)
            }
        }
    }
}

struct AnimatedBar: View {
    var isPlaying: Bool
    var delay: Double
    var barIndex: Int
    var color: Color
    
    // Base height when stopped (all bars at same low height)
    private let stoppedHeight: CGFloat = 0.3
    
    @State private var scale: CGFloat = 0.3
    @State private var animating: Bool = false
    
    var body: some View {
        Capsule()
            .fill(color)
            .frame(width: 3)
            .scaleEffect(y: scale, anchor: .bottom)
            .opacity(0.9)
            .onAppear {
                scale = stoppedHeight
                if isPlaying {
                    startAnimation()
                }
            }
            .onChange(of: isPlaying) { _, playing in
                if playing {
                    startAnimation()
                } else {
                    stopAnimation()
                }
            }
    }
    
    private func startAnimation() {
        guard isPlaying && !animating else { return }
        animating = true
        
        // Start animation loop
        Task { @MainActor in
            while isPlaying {
                let duration = Double.random(in: 0.25...0.45)
                let targetScale = CGFloat.random(in: 0.5...1.0)
                
                withAnimation(.easeInOut(duration: duration).delay(delay)) {
                    scale = targetScale
                }
                
                try? await Task.sleep(for: .seconds(duration))
                
                if isPlaying {
                    withAnimation(.easeInOut(duration: duration)) {
                        scale = CGFloat.random(in: 0.3...0.6)
                    }
                }
                
                try? await Task.sleep(for: .milliseconds(100))
            }
            animating = false
        }
    }
    
    private func stopAnimation() {
        animating = false
        withAnimation(.easeOut(duration: 0.2)) {
            scale = stoppedHeight
        }
    }
}

#Preview {
    NotchHUDView()
        .frame(width: 420, height: 180)
        .background(Color.gray.opacity(0.3))
}

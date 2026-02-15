import SwiftUI

struct LyricsView: View {
    @ObservedObject var nowPlaying: NowPlayingManager
    var onClose: () -> Void
    
    var body: some View {
        ZStack {
            // Background with blur and tint
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .edgesIgnoringSafeArea(.all)
            
            Color.black.opacity(0.5)
                .edgesIgnoringSafeArea(.all)
                
            VStack(spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(nowPlaying.info.title)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                        
                        Text(nowPlaying.info.artist)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    
                    Spacer()
                    
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }
                .padding(20)
                .background(Color.black.opacity(0.3))
                
                // Lyrics Content
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 16) {
                            if nowPlaying.lyrics.isEmpty {
                                VStack(spacing: 16) {
                                    Image(systemName: "music.mic")
                                        .font(.system(size: 40))
                                        .foregroundStyle(.white.opacity(0.3))
                                    Text("No lyrics available")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundStyle(.white.opacity(0.5))
                                }
                                .frame(maxWidth: .infinity, minHeight: 200)
                            } else {
                                ForEach(nowPlaying.lyrics) { lyric in
                                    let isCurrent = isCurrentLine(lyric)
                                    
                                    Text(lyric.text)
                                        .font(.system(size: 20, weight: .medium, design: .rounded))
                                        .foregroundStyle(isCurrent ? .white : .white.opacity(0.5))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .multilineTextAlignment(.leading)
                                        .animation(.easeInOut(duration: 0.3), value: isCurrent)
                                        .id(lyric.id)
                                        .onTapGesture {
                                            // Optional: seek to time?
                                        }
                                }
                            }
                        }
                        .padding(32)
                        .padding(.bottom, 100) // Extra padding at bottom
                    }
                    .onChange(of: nowPlaying.info.elapsed) { _, _ in
                        scrollToCurrentLine(proxy: proxy)
                    }
                }
            }
        }
        .frame(minWidth: 300, minHeight: 400)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
    
    private func isCurrentLine(_ lyric: SyncedLyric) -> Bool {
        let currentTime = nowPlaying.info.elapsed
        // Find index of this lyric
        guard let index = nowPlaying.lyrics.firstIndex(of: lyric) else { return false }
        
        let startTime = lyric.time
        let endTime = index < nowPlaying.lyrics.count - 1 ? nowPlaying.lyrics[index + 1].time : Double.infinity
        
        return currentTime >= startTime && currentTime < endTime
    }
    
    private func scrollToCurrentLine(proxy: ScrollViewProxy) {
        if let current = nowPlaying.lyrics.first(where: { isCurrentLine($0) }) {
            withAnimation(.easeInOut(duration: 0.5)) {
                proxy.scrollTo(current.id, anchor: .center)
            }
        }
    }
}

// Helper for vibrant background
struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
        visualEffectView.state = .active
        return visualEffectView
    }
    
    func updateNSView(_ visualEffectView: NSVisualEffectView, context: Context) {
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
    }
}

import Foundation
import AppKit
import Combine

struct NowPlayingInfo: Equatable {
    var title: String = "Nothing Playing"
    var artist: String = ""
    var album: String = ""
    var isPlaying: Bool = false
    var duration: Double = 0
    var elapsed: Double = 0
    var artworkData: Data? = nil
    var source: String = "" // "Music" or "Spotify"
    var isFavorited: Bool = false
    var url: String = ""
    
    var progress: Double {
        guard duration > 0 else { return 0 }
        return min(elapsed / duration, 1.0)
    }
    
    var hasContent: Bool {
        title != "Nothing Playing" && !title.isEmpty
    }
    
    var elapsedFormatted: String {
        formatTime(elapsed)
    }
    
    var remainingFormatted: String {
        let remaining = max(0, duration - elapsed)
        return "-" + formatTime(remaining)
    }
    
    private func formatTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

struct SyncedLyric: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let time: TimeInterval
}

@MainActor
final class NowPlayingManager: ObservableObject {
    @Published var info = NowPlayingInfo()
    @Published var isAvailable = false
    @Published var artwork: NSImage? = nil
    @Published var lyrics: [SyncedLyric] = []
    
    private var timer: Timer?
    private var elapsedTimer: Timer?
    private var lastUpdateTime: Date = .now
    
    init() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.startPolling()
        }
    }
    
    func startPolling() {
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.fetchNowPlaying()
            }
        }
        fetchNowPlaying()
        
        elapsedTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateElapsed()
            }
        }
    }
    
    private func updateElapsed() {
        guard info.isPlaying, info.duration > 0 else { return }
        let timeSinceUpdate = Date.now.timeIntervalSince(lastUpdateTime)
        let newElapsed = min(info.elapsed + timeSinceUpdate, info.duration)
        info.elapsed = newElapsed
        lastUpdateTime = .now
    }
    
    func fetchNowPlaying() {
        Task.detached { [weak self] in
            // helper to update UI
            func update(with newInfo: NowPlayingInfo?, artwork: NSImage?) async {
                await MainActor.run {
                    if let newInfo = newInfo {
                        self?.isAvailable = true
                        self?.lastUpdateTime = .now
                        
                        let previousTitle = self?.info.title
                        let previousArtist = self?.info.artist
                        
                        self?.info = newInfo
                        
                        // Check if track changed
                        if previousTitle != newInfo.title || previousArtist != newInfo.artist {
                            self?.lyrics = [] // Clear old lyrics
                            self?.fetchLyrics(for: newInfo)
                            
                            if artwork == nil {
                                self?.artwork = nil
                            }
                        }
                        
                        if let img = artwork {
                            self?.artwork = img
                        }
                    } else {
                        self?.info = NowPlayingInfo()
                        self?.isAvailable = false
                        self?.artwork = nil
                        self?.lyrics = []
                    }
                }
            }

            if let spotifyInfo = self?.getSpotifyInfo() {
                let artworkImage = self?.getSpotifyArtwork()
                await update(with: spotifyInfo, artwork: artworkImage)
            } else if let musicInfo = self?.getAppleMusicInfo() {
                 let artworkImage = self?.getAppleMusicArtwork()
                 await update(with: musicInfo, artwork: artworkImage)
            } else if let safariInfo = self?.getSafariInfo() {
                 let art = self?.getSafariArtwork(for: safariInfo.url)
                 await update(with: safariInfo, artwork: art)
            } else {
                await update(with: nil, artwork: nil)
            }
        }
    }

    private func fetchLyrics(for info: NowPlayingInfo) {
        let title = info.title
        let artist = info.artist
        let duration = info.duration
        
        print("Fetching lyrics for \(title) by \(artist)")
        
        guard !title.isEmpty, title != "Safari Video" else { return }
        
        Task.detached { [weak self] in
            guard let self = self else { return }
            
            // Try specific get first
            var fetchedLyrics = await self.getLyrics(title: title, artist: artist, duration: duration)
            
            if fetchedLyrics.isEmpty {
                print("Direct get failed, trying search...")
                fetchedLyrics = await self.searchLyrics(title: title, artist: artist, duration: duration)
            }
            
            let finalLyrics = fetchedLyrics
            await MainActor.run {
                print("Found \(finalLyrics.count) lyric lines")
                self.lyrics = finalLyrics
            }
        }
    }
    
    // MARK: - Lyrics Helpers
    
    private nonisolated func getLyrics(title: String, artist: String, duration: Double) async -> [SyncedLyric] {
        let urlString = "https://lrclib.net/api/get?artist_name=\(artist.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&track_name=\(title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&duration=\(Int(duration))"
        
        guard let url = URL(string: urlString) else { return [] }
        
        do {
            let data = try await performRequest(url: url)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let syncedLyrics = json["syncedLyrics"] as? String {
                return parseLrcPayload(syncedLyrics)
            }
        } catch {
            print("Get lyrics error: \(error)")
        }
        return []
    }
    
    private nonisolated func searchLyrics(title: String, artist: String, duration: Double) async -> [SyncedLyric] {
        let query = "\(title) \(artist)"
        let urlString = "https://lrclib.net/api/search?q=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        
        guard let url = URL(string: urlString) else { return [] }
        
        do {
            let data = try await performRequest(url: url)
            if let results = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                // Find best match by duration
                let bestMatch = results.min(by: { a, b in
                    let durA = a["duration"] as? Double ?? 0
                    let durB = b["duration"] as? Double ?? 0
                    return abs(durA - duration) < abs(durB - duration)
                })
                
                if let match = bestMatch,
                   let syncedLyrics = match["syncedLyrics"] as? String {
                   // Verify it's somewhat close in duration (within 10s)
                   let matchDur = match["duration"] as? Double ?? 0
                   if abs(matchDur - duration) < 10 {
                       return parseLrcPayload(syncedLyrics)
                   }
                }
            }
        } catch {
            print("Search lyrics error: \(error)")
        }
        return []
    }
    
    private nonisolated func performRequest(url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        request.httpMethod = "GET"
        request.addValue("NotchHUD/1.0", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            guard (200...299).contains(httpResponse.statusCode) else {
                throw NSError(domain: "HTTPError", code: httpResponse.statusCode, userInfo: nil)
            }
        }
        return data
    }
    
    private nonisolated func parseLrcPayload(_ lrc: String) -> [SyncedLyric] {
        var result: [SyncedLyric] = []
        let pattern = "\\[(\\d{2}):(\\d{2}\\.\\d{2})\\](.*)"
        let regex = try? NSRegularExpression(pattern: pattern)
        
        lrc.enumerateLines { line, _ in
            let nsString = line as NSString
            if let match = regex?.firstMatch(in: line, range: NSRange(location: 0, length: line.utf16.count)) {
                let minStr = nsString.substring(with: match.range(at: 1))
                let secStr = nsString.substring(with: match.range(at: 2))
                let text = nsString.substring(with: match.range(at: 3)).trimmingCharacters(in: .whitespaces)
                
                if let min = Double(minStr), let sec = Double(secStr) {
                    // Slight offset for sync
                    let time = (min * 60 + sec) - 0.2
                    if !text.isEmpty {
                        result.append(SyncedLyric(text: text, time: time))
                    }
                }
            }
        }
        return result.sorted { $0.time < $1.time }
    }
    
    private nonisolated func getSafariInfo() -> NowPlayingInfo? {
        // Safari web video support (YouTube/Netflix/any <video>)
        // We read title + playback state + currentTime/duration + URL from the ACTIVE tab.
        // (Scanning all tabs is expensive and makes Safari feel laggy.)
        let js = """
        (() => {
          const v = document.querySelector('video');
          if (!v) return 'NOVIDEO';
          const paused = v.paused;
          const ct = v.currentTime || 0;
          const dur = v.duration || 0;
          const state = paused ? 'paused' : 'playing';
          const ogTitle = document.querySelector('meta[property=\"og:title\"]')?.content?.trim();
          const title = (ogTitle || document.title || '').trim();
          const author = (document.querySelector('meta[name=\"author\"]')?.content?.trim() || location.hostname);
          return [title, author, ct, dur, state, location.href].join('|||');
        })();
        """
        
        let script = """
        tell application "System Events"
            if not (exists process "Safari") then return "NOT_RUNNING"
        end tell
        tell application "Safari"
            if not (exists front document) then return "NO_DOC"
            try
                set r to do JavaScript "\(escapeForAppleScript(js))" in front document
                return r
            on error
                return "JS_ERROR"
            end try
        end tell
        """
        
        guard let result = runAppleScript(script),
              result != "NOT_RUNNING",
              result != "NO_DOC",
              result != "JS_ERROR",
              result != "NOVIDEO" else { return nil }
              
        let parts = result.components(separatedBy: "|||")
        guard parts.count >= 6 else { return nil }
        
        // Clean title
        var title = parts[0]
        // Remove common suffixes
        title = title.replacingOccurrences(of: " - YouTube", with: "")
        title = title.replacingOccurrences(of: " - Netflix", with: "")
        title = title.replacingOccurrences(of: " | TED", with: "")
        
        let author = parts[1]
        let elapsed = Double(parts[2]) ?? 0
        let duration = Double(parts[3]) ?? 0
        let isPlaying = parts[4].lowercased().contains("playing")
        let url = parts[5]
        
        return NowPlayingInfo(
            title: title.isEmpty ? "Safari Video" : title,
            artist: author.isEmpty ? "Safari" : author,
            album: "",
            isPlaying: isPlaying,
            duration: duration,
            elapsed: elapsed,
            artworkData: nil,
            source: "Safari",
            isFavorited: false,
            url: url
        )
    }

    private nonisolated func getSafariArtwork(for urlString: String) -> NSImage? {
        // YouTube: fetch thumbnail via public URL
        guard let vid = youtubeVideoID(from: urlString) else { return nil }
        guard let thumbURL = URL(string: "https://i.ytimg.com/vi/\(vid)/hqdefault.jpg") else { return nil }
        guard let data = try? Data(contentsOf: thumbURL) else { return nil }
        return NSImage(data: data)
    }
    
    private nonisolated func youtubeVideoID(from urlString: String) -> String? {
        guard let url = URL(string: urlString) else { return nil }
        if url.host?.contains("youtu.be") == true {
            return url.pathComponents.last
        }
        let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
        return comps?.queryItems?.first(where: { $0.name == "v" })?.value
    }
    
    private nonisolated func escapeForAppleScript(_ s: String) -> String {
        s
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
    }
    
    private nonisolated func getSpotifyInfo() -> NowPlayingInfo? {
        let script = """
        tell application "System Events"
            if not (exists process "Spotify") then return "NOT_RUNNING"
        end tell
        tell application "Spotify"
            if player state is stopped then return "STOPPED"
            set trackName to name of current track
            set artistName to artist of current track
            set albumName to album of current track
            set trackDuration to duration of current track
            set trackPosition to player position
            set playState to player state as string
            return trackName & "|||" & artistName & "|||" & albumName & "|||" & trackDuration & "|||" & trackPosition & "|||" & playState
        end tell
        """
        
        guard let result = runAppleScript(script),
              result != "NOT_RUNNING",
              result != "STOPPED" else { return nil }
        
        let parts = result.components(separatedBy: "|||")
        guard parts.count >= 6 else { return nil }
        
        return NowPlayingInfo(
            title: parts[0],
            artist: parts[1],
            album: parts[2],
            isPlaying: parts[5].lowercased().contains("playing"),
            duration: (Double(parts[3]) ?? 0) / 1000,
            elapsed: Double(parts[4]) ?? 0,
            source: "Spotify"
        )
    }
    
    private nonisolated func getSpotifyArtwork() -> NSImage? {
        let script = """
        tell application "Spotify"
            return artwork url of current track
        end tell
        """
        
        guard let urlString = runAppleScript(script),
              let url = URL(string: urlString),
              let data = try? Data(contentsOf: url),
              let image = NSImage(data: data) else { return nil }
        
        return image
    }
    
    private nonisolated func getAppleMusicInfo() -> NowPlayingInfo? {
        let script = """
        tell application "System Events"
            if not (exists process "Music") then return "NOT_RUNNING"
        end tell
        tell application "Music"
            if player state is stopped then return "STOPPED"
            set trackName to name of current track
            set artistName to artist of current track
            set albumName to album of current track
            set trackDuration to duration of current track
            set trackPosition to player position
            set playState to player state as string
            return trackName & "|||" & artistName & "|||" & albumName & "|||" & trackDuration & "|||" & trackPosition & "|||" & playState
        end tell
        """
        
        guard let result = runAppleScript(script),
              result != "NOT_RUNNING",
              result != "STOPPED" else { return nil }
        
        let parts = result.components(separatedBy: "|||")
        guard parts.count >= 6 else { return nil }
        
        return NowPlayingInfo(
            title: parts[0],
            artist: parts[1],
            album: parts[2],
            isPlaying: parts[5].lowercased().contains("playing"),
            duration: Double(parts[3]) ?? 0,
            elapsed: Double(parts[4]) ?? 0,
            source: "Music"
        )
    }
    
    private nonisolated func getAppleMusicArtwork() -> NSImage? {
        // For Apple Music, we'll use a different approach - get via temp file
        let tempScript = """
        tell application "Music"
            try
            set artworkData to data of artwork 1 of current track
            set tempPath to (path to temporary items as text) & "artwork.jpg"
            set fileRef to open for access file tempPath with write permission
            set eof fileRef to 0
            write artworkData to fileRef
            close access fileRef
            return POSIX path of file tempPath
            on error
            return ""
            end try
        end tell
        """
        
        guard let path = runAppleScript(tempScript), !path.isEmpty else { return nil }
        return NSImage(contentsOfFile: path)
    }
    
    private nonisolated func runAppleScript(_ source: String) -> String? {
        var error: NSDictionary?
        guard let script = NSAppleScript(source: source) else { return nil }
        let result = script.executeAndReturnError(&error)
        if error != nil { return nil }
        return result.stringValue
    }
    
    // MARK: - Playback Controls
    
    func togglePlayPause() {
        if info.source == "Spotify" || info.source == "Music" {
             let app = info.source 
             let script = """
             tell application "\(app)"
                 playpause
             end tell
             """
             Task.detached { [weak self] in _ = self?.runAppleScript(script); await self?.forceRefresh() }
        } else if info.source == "Safari" {
             let script = """
             tell application "Safari"
                try
                    do JavaScript "(() => { const v=document.querySelector('video'); if(!v) return ''; if(v.paused) v.play(); else v.pause(); return ''; })()" in front document
                end try
             end tell
             """
             Task.detached { [weak self] in _ = self?.runAppleScript(script); await self?.forceRefresh() }
        }
    }
    
    func nextTrack() {
        let app = info.source == "Safari" ? "Spotify" : (info.source.isEmpty ? "Spotify" : info.source)
        if app == "Safari" { return } // No next track for Safari yet
        
        let script = """
        tell application "\(app)"
            next track
        end tell
        """
        Task.detached { [weak self] in _ = self?.runAppleScript(script); await self?.forceRefresh() }
    }
    
    func previousTrack() {
         let app = info.source == "Safari" ? "Spotify" : (info.source.isEmpty ? "Spotify" : info.source)
         if app == "Safari" { return } // No prev track for Safari yet

        let script = """
        tell application "\(app)"
            previous track
        end tell
        """
        Task.detached { [weak self] in _ = self?.runAppleScript(script); await self?.forceRefresh() }
    }
    
    private func forceRefresh() async {
        try? await Task.sleep(for: .milliseconds(300))
        await MainActor.run {
            self.fetchNowPlaying()
        }
    }
    
    func toggleFavorite() {
        info.isFavorited.toggle()
    }
}


import AppKit

final class MusicAdapter: MediaAdapter {
    let source: NowPlaying.Source = .music
    let bundleID = "com.apple.Music"
    let notificationName = "com.apple.Music.playerInfo"

    private let runner = AppleScriptRunner.shared

    func snapshot() -> NowPlaying? {
        guard isRunning else { return nil }
        let script = """
        tell application "Music"
            set nbState to (player state as text)
            if nbState is not "playing" and nbState is not "paused" then return "idle"
            try
                set nbTrack to current track
            on error
                return "idle"
            end try
            return nbState & tab & (name of nbTrack) & tab & (artist of nbTrack) & tab & (album of nbTrack) & tab & ((duration of nbTrack) as text) & tab & ((player position) as text) & tab & "" & tab & ((shuffle enabled) as text) & tab & ((song repeat) as text)
        end tell
        """
        guard let raw = runner.string(script) else { return nil }
        return SnapshotParser.parse(raw, source: .music, durationDivisor: 1)
    }

    func upNext() -> [QueueEntry] {
        guard isRunning else { return [] }
        let script = """
        tell application "Music"
            try
                set nbList to current playlist
            on error
                return ""
            end try
            set nbTotal to (count of tracks of nbList)
            if nbTotal is 0 or nbTotal > 2000 then return ""
            set nbIndex to 0
            try
                set nbIndex to index of current track
            end try
            if nbIndex is 0 then return ""
            set nbOut to {}
            repeat with i from (nbIndex + 1) to (nbIndex + 8)
                if i is less than or equal to nbTotal then
                    set nbT to track i of nbList
                    set end of nbOut to ((name of nbT) & tab & (artist of nbT) & tab & (i as text))
                end if
            end repeat
            set AppleScript\'s text item delimiters to linefeed
            set nbText to (nbOut as text)
            set AppleScript\'s text item delimiters to ""
            return nbText
        end tell
        """
        guard let raw = runner.string(script), !raw.isEmpty else { return [] }
        return raw.components(separatedBy: "\n").enumerated().compactMap { offset, line in
            let fields = line.components(separatedBy: "\t")
            guard fields.count >= 3, !fields[0].isEmpty else { return nil }
            return QueueEntry(id: offset, title: fields[0], artist: fields[1],
                              artworkURL: nil, handle: fields[2], contextURI: nil)
        }
    }

    func artwork(for playing: NowPlaying) async -> NSImage? {
        guard isRunning else { return nil }
        let script = """
        tell application "Music"
            try
                return (raw data of artwork 1 of current track)
            on error
                return missing value
            end try
        end tell
        """
        guard let data = runner.data(script), !data.isEmpty else { return nil }
        return NSImage(data: data)
    }

    func play(_ entry: QueueEntry) {
        guard isRunning, let index = entry.handle, Int(index) != nil else { return }
        runner.execute("tell application \"Music\" to play track \(index) of current playlist")
    }

    func setShuffle(_ enabled: Bool) {
        guard isRunning else { return }
        runner.execute("tell application \"Music\" to set shuffle enabled to \(enabled)")
    }

    func setRepeat(_ mode: RepeatMode) {
        guard isRunning else { return }
        runner.execute("tell application \"Music\" to set song repeat to \(mode.rawValue)")
    }

    func activate() {
        guard isRunning else { return }
        runner.execute("tell application \"Music\"\nreopen\nactivate\nend tell")
    }

    func playPause() { runner.execute(command("playpause")) }
    func next() { runner.execute(command("next track")) }
    func previous() { runner.execute(command("previous track")) }

    func seek(to seconds: Double) {
        guard isRunning else { return }
        runner.execute("tell application \"Music\" to set player position to \(seconds)")
    }

    private func command(_ verb: String) -> String {
        "tell application \"Music\" to \(verb)"
    }
}

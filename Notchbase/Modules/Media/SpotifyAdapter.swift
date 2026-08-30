import AppKit

final class SpotifyAdapter: MediaAdapter {
    let source: NowPlaying.Source = .spotify
    let bundleID = "com.spotify.client"
    let notificationName = "com.spotify.client.PlaybackStateChanged"

    private let runner = AppleScriptRunner.shared

    func snapshot() -> NowPlaying? {
        guard isRunning else { return nil }
        let script = """
        tell application "Spotify"
            set nbState to (player state as text)
            if nbState is not "playing" and nbState is not "paused" then return "idle"
            try
                set nbTrack to current track
            on error
                return "idle"
            end try
            return nbState & tab & (name of nbTrack) & tab & (artist of nbTrack) & tab & (album of nbTrack) & tab & ((duration of nbTrack) as text) & tab & ((player position) as text) & tab & (artwork url of nbTrack) & tab & ((shuffling) as text) & tab & ((repeating) as text)
        end tell
        """
        guard let raw = runner.string(script) else { return nil }
        return SnapshotParser.parse(raw, source: .spotify, durationDivisor: 1000)
    }

    func artwork(for playing: NowPlaying) async -> NSImage? {
        guard let url = playing.artworkURL else { return nil }
        guard let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }
        return NSImage(data: data)
    }

    func play(_ entry: QueueEntry) {
        guard isRunning else { return }
        let steps = entry.id + 1
        guard steps > 0, steps <= 12 else { return }
        let script = "tell application \"Spotify\"\n"
            + "repeat \(steps) times\n next track\n delay 0.12\n end repeat\n"
            + "end tell"
        runner.execute(script)
    }

    func setShuffle(_ enabled: Bool) {
        guard isRunning else { return }
        runner.execute("tell application \"Spotify\" to set shuffling to \(enabled)")
    }

    func setRepeat(_ mode: RepeatMode) {
        guard isRunning else { return }
        runner.execute("tell application \"Spotify\" to set repeating to \(mode != .off)")
    }

    func activate() {
        guard isRunning else { return }
        runner.execute("tell application \"Spotify\"\nreopen\nactivate\nend tell")
    }

    func playPause() { runner.execute(command("playpause")) }
    func next() { runner.execute(command("next track")) }
    func previous() { runner.execute(command("previous track")) }

    func seek(to seconds: Double) {
        guard isRunning else { return }
        runner.execute("tell application \"Spotify\" to set player position to \(seconds)")
    }

    private func command(_ verb: String) -> String {
        "tell application \"Spotify\" to \(verb)"
    }
}

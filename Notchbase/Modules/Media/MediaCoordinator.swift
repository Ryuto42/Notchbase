import AppKit
import SwiftUI
import Observation

@Observable
final class MediaCoordinator {
    enum Diagnostic: Equatable {
        case ok
        case noAppRunning
        case notAuthorized(String)
        case idle
    }

    private(set) var current: NowPlaying?
    private(set) var artwork: NSImage?
    private(set) var artworkTint: Color?
    private(set) var artworkAccent: Color?
    private(set) var upNext: [QueueEntry] = []
    @ObservationIgnored let queueArtwork = QueueArtworkLoader()
    @ObservationIgnored private let webClient = SpotifyWebClient()
    private(set) var diagnostic: Diagnostic = .noAppRunning

    @ObservationIgnored private let adapters: [any MediaAdapter] = [MusicAdapter(), SpotifyAdapter()]
    @ObservationIgnored private var anchorPosition: Double = 0
    @ObservationIgnored private var anchorDate = Date()
    @ObservationIgnored private var artworkKey: String?
    @ObservationIgnored private var lastPlayingSource: NowPlaying.Source?
    @ObservationIgnored private var tick: Timer?
    @ObservationIgnored private var refreshCounter = 0

    var onTrackChange: ((NowPlaying?) -> Void)?

    func applyDemo(_ demo: NowPlaying, queue: [QueueEntry]) {
        current = demo
        anchor(demo.position)
        upNext = queue
        diagnostic = .ok
        artwork = DemoArtwork.image
        artworkTint = ArtworkAmbience.tint(for: artwork)
        artworkAccent = ArtworkAmbience.accent(for: artwork)
    }

    // MARK: - Lifecycle

    func start() {
        for adapter in adapters {
            DistributedNotificationCenter.default().addObserver(
                forName: Notification.Name(adapter.notificationName),
                object: nil,
                queue: .main
            ) { _ in
                MainActor.assumeIsolated { self.refresh() }
            }
        }

        let timer = Timer(timeInterval: 0.5, repeats: true) { _ in
            MainActor.assumeIsolated { self.onTick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        tick = timer
        refresh()
    }

    func stop() {
        tick?.invalidate()
        tick = nil
        DistributedNotificationCenter.default().removeObserver(self)
    }

    // MARK: - Commands

    var activeAdapter: (any MediaAdapter)? {
        guard let source = current?.source else { return nil }
        return adapters.first { $0.source == source }
    }

    func playPause() {
        activeAdapter?.playPause()
        current?.isPlaying.toggle()
        anchor(current?.position ?? 0)
        scheduleRefresh()
    }

    func next() {
        activeAdapter?.next()
        scheduleRefresh()
    }

    func previous() {
        activeAdapter?.previous()
        scheduleRefresh()
    }

    func play(_ entry: QueueEntry) {
        activeAdapter?.play(entry)
        scheduleRefresh()
    }

    func activatePlayer() {
        Debug.log("activatePlayer tapped")
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(200))
            self?.activeAdapter?.activate()
            if Debug.isLogging {
                let failure = AppleScriptRunner.shared.lastFailure
                let front = NSWorkspace.shared.frontmostApplication?.localizedName ?? "?"
                Debug.log("activate result failure=\(failure?.code ?? 0) \(failure?.message ?? "-") front=\(front)")
            }
        }
    }

    func toggleShuffle() {
        guard let playing = current else { return }
        activeAdapter?.setShuffle(!playing.isShuffling)
        current?.isShuffling.toggle()
        scheduleRefresh()
    }

    func cycleRepeat() {
        guard let playing = current else { return }
        let next: RepeatMode
        switch (playing.repeatMode, playing.source) {
        case (.off, _): next = .all
        case (.all, .music): next = .one
        default: next = .off
        }
        activeAdapter?.setRepeat(next)
        current?.repeatMode = next
        scheduleRefresh()
    }

    func seek(toProgress progress: Double) {
        guard let playing = current, playing.duration > 0 else { return }
        let seconds = progress * playing.duration
        activeAdapter?.seek(to: seconds)
        current?.position = seconds
        anchor(seconds)
    }

    // MARK: - Refresh

    private func onTick() {
        refreshCounter += 1
        if refreshCounter % 4 == 0 {
            refresh()
        } else if var playing = current, playing.isPlaying {
            playing.position = min(playing.duration,
                                   anchorPosition + Date().timeIntervalSince(anchorDate))
            current = playing
        }
    }

    private func scheduleRefresh() {
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(220))
            self?.refresh()
        }
    }

    func requestAuthorization() {
        for adapter in adapters where adapter.isRunning {
            _ = adapter.snapshot()
        }
        refresh()
    }

    private func demoTrack() -> NowPlaying? {
        guard let raw = Debug.value("DEMO_TRACK") else { return nil }
        let f = raw.components(separatedBy: "|")
        guard f.count >= 5 else { return nil }
        return NowPlaying(source: .spotify, isPlaying: true, title: f[1], artist: f[0],
                          album: f[2], duration: Double(f[3]) ?? 0, position: Double(f[4]) ?? 0,
                          artworkURL: nil)
    }

    private func refresh() {
        guard !Debug.isDemo else { return }
        if let demo = demoTrack() {
            let isNew = demo.trackKey != current?.trackKey
            current = demo
            diagnostic = .ok
            if isNew { onTrackChange?(demo) }
            return
        }
        let running = adapters.filter(\.isRunning)
        guard !running.isEmpty else {
            diagnostic = .noAppRunning
            clear()
            return
        }

        let snapshots = running.compactMap { $0.snapshot() }
        guard !snapshots.isEmpty else {
            if let failure = AppleScriptRunner.shared.lastFailure, failure.isNotPermitted {
                diagnostic = .notAuthorized(failure.message)
            } else {
                diagnostic = .idle
            }
            if Debug.isLogging {
                let failure = AppleScriptRunner.shared.lastFailure
                Debug.log("media no snapshot running=\(running.map(\.bundleID)) failure=\(failure?.code ?? 0) \(failure?.message ?? "-")")
            }
            clear()
            return
        }
        diagnostic = .ok

        let playing = snapshots.filter(\.isPlaying)
        let chosen: NowPlaying
        if playing.count > 1, let last = lastPlayingSource,
           let stick = playing.first(where: { $0.source == last }) {
            chosen = stick
        } else {
            chosen = playing.first ?? snapshots[0]
        }
        if chosen.isPlaying { lastPlayingSource = chosen.source }

        let isNewTrack = chosen.trackKey != current?.trackKey
        if isNewTrack {
            Debug.log("media \(chosen.source.rawValue) playing=\(chosen.isPlaying) title=\(chosen.title)")
        }
        current = chosen
        anchor(chosen.position)

        if isNewTrack {
            artwork = nil
            artworkTint = nil
            loadArtwork(for: chosen)
            loadQueue(for: chosen)
            onTrackChange?(chosen)
        }
    }

    private func clear() {
        guard current != nil else { return }
        current = nil
        artwork = nil
        artworkTint = nil
        artworkAccent = nil
        artworkKey = nil
        upNext = []
        onTrackChange?(nil)
    }

    private func anchor(_ position: Double) {
        anchorPosition = position
        anchorDate = Date()
    }

    private func loadQueue(for playing: NowPlaying) {
        upNext = []
        if playing.source == .spotify {
            guard SpotifyAuth.shared.isConnected else { return }
            let key = playing.trackKey
            Task { [weak self] in
                guard let self else { return }
                let entries = await self.webClient.upNext()
                guard self.current?.trackKey == key else {
                    Debug.log("queue dropped: key changed")
                    return
                }
                self.upNext = entries
                self.queueArtwork.prefetch(entries.map(\.artworkURL))
                Debug.log("upNext set \(entries.count)")
            }
        } else {
            upNext = adapters.first { $0.source == playing.source }?.upNext() ?? []
        }
    }

    private func loadArtwork(for playing: NowPlaying) {
        guard let adapter = adapters.first(where: { $0.source == playing.source }) else { return }
        artworkKey = playing.trackKey
        let key = playing.trackKey
        Task { [weak self] in
            let image = await adapter.artwork(for: playing)
            guard let self, self.artworkKey == key else { return }
            self.artwork = image
            self.artworkTint = ArtworkAmbience.tint(for: image)
            self.artworkAccent = Preferences.shared.artworkAccent
                ? ArtworkAmbience.accent(for: image)
                : nil
        }
    }
}

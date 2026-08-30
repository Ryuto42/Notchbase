import SwiftUI

struct MediaView: View {
    var model: NotchViewModel

    private var media: MediaCoordinator { model.media }

    var body: some View {
        Group {
            if let playing = media.current {
                player(playing)
            } else {
                placeholder
            }
        }
    }

    private func player(_ playing: NowPlaying) -> some View {
        HStack(spacing: 0) {
            NowPlayingColumn(model: model, playing: playing)
                .frame(maxWidth: .infinity)

            Rectangle()
                .fill(Theme.hairline)
                .frame(width: 1)
                .padding(.vertical, 4)

            UpNextColumn(media: media, source: playing.source)
                .frame(width: 216)
        }
        .padding(.horizontal, 12)
        .padding(.top, 4)
        .padding(.bottom, 10)
        .background(alignment: .bottom) { ambience }
    }

    private var ambience: some View {
        LinearGradient(colors: [(media.artworkTint ?? Theme.accent).opacity(0.08), .clear],
                       startPoint: .bottom, endPoint: .top)
            .frame(height: 70)
            .blur(radius: 26)
            .allowsHitTesting(false)
            .animation(Motion.content, value: media.artworkTint)
    }

    @ViewBuilder
    private var placeholder: some View {
        switch media.diagnostic {
        case .notAuthorized(let message):
            PlaceholderView(symbol: "lock.shield",
                            title: L.t("Automation access needed"),
                            detail: message,
                            actionTitle: L.t("Open Privacy Settings")) {
                NSWorkspace.shared.open(
                    URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")!)
            }
        case .noAppRunning:
            PlaceholderView(symbol: "music.note.list",
                            title: L.t("Music and Spotify are not running"),
                            detail: L.t("Open either app and playback shows up here."))
        case .idle, .ok:
            PlaceholderView(symbol: "pause.circle",
                            title: L.t("Nothing playing"),
                            detail: L.t("Start a track in Music or Spotify."),
                            actionTitle: L.t("Check again")) {
                media.requestAuthorization()
            }
        }
    }
}

// MARK: - Left column

private struct NowPlayingColumn: View {
    var model: NotchViewModel
    var playing: NowPlaying

    private var media: MediaCoordinator { model.media }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 11) {
                Button {
                    media.activatePlayer()
                } label: {
                    ArtworkView(image: media.artwork, size: 62, radius: 11)
                        .contentShape(Rectangle())
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.32, anchor: .topLeading)
                                .combined(with: .opacity),
                            removal: .scale(scale: 0.26, anchor: .topLeading)
                                .combined(with: .opacity)
                                .animation(Motion.withdraw)))
                }
                .buttonStyle(.plain)
                .help("Open \(playing.source.rawValue)")

                Button {
                    media.activatePlayer()
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(playing.title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.primaryText)
                            .lineLimit(1)
                        HStack(spacing: 5) {
                            Text(playing.artist)
                                .font(.system(size: 11.5))
                                .foregroundStyle(Theme.secondaryText)
                                .lineLimit(1)
                            SourceBadge(source: playing.source)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Open \(playing.source.rawValue)")

                Spacer(minLength: 6)

                if playing.isPlaying {
                    AudioBarsView(isAnimating: true, tint: media.artworkAccent)
                        .transition(.opacity)
                }
            }
            .animation(Motion.content, value: playing.isPlaying)

            scrubber.padding(.top, 9)
            controls.padding(.top, 1)

            Rectangle()
                .fill(Theme.hairline)
                .frame(height: 1)
                .padding(.top, 4)

            LyricsTickerView(controller: model.lyrics, position: playing.position)
                .padding(.top, 5)

            Spacer(minLength: 0)
        }
        .padding(.trailing, 13)
    }

    private var scrubber: some View {
        HStack(spacing: 9) {
            Text(Format.time(playing.position))
                .font(Typo.digits(10.5, .medium))
                .foregroundStyle(Theme.secondaryText)
                .frame(width: 32, alignment: .leading)

            GeometryReader { proxy in
                Meter(value: playing.progress, tint: media.artworkAccent ?? .white, height: 5)
                    .contentShape(Rectangle().inset(by: -8))
                    .gesture(
                        DragGesture(minimumDistance: 0).onEnded { value in
                            guard proxy.size.width > 0 else { return }
                            media.seek(toProgress: value.location.x / proxy.size.width)
                        }
                    )
            }
            .frame(height: 5)

            Text("-" + Format.time(max(0, playing.duration - playing.position)))
                .font(Typo.digits(10.5, .medium))
                .foregroundStyle(Theme.secondaryText)
                .frame(width: 36, alignment: .trailing)
        }
    }

    private var controls: some View {
        HStack(spacing: 0) {
            ToggleButton(symbol: "shuffle", isOn: playing.isShuffling,
                         tint: media.artworkAccent) { media.toggleShuffle() }
            Spacer(minLength: 0)
            HStack(spacing: 2) {
                TransportButton(symbol: "backward.fill", size: 15) { media.previous() }
                TransportButton(symbol: playing.isPlaying ? "pause.fill" : "play.fill", size: 19) {
                    media.playPause()
                }
                TransportButton(symbol: "forward.fill", size: 15) { media.next() }
            }
            Spacer(minLength: 0)
            ToggleButton(symbol: playing.repeatMode.symbol,
                         isOn: playing.repeatMode != .off,
                         tint: media.artworkAccent) { media.cycleRepeat() }
            OutputDeviceButton()
        }
    }
}

// MARK: - Right column

private struct UpNextColumn: View {
    var media: MediaCoordinator
    var source: NowPlaying.Source

    private var emptyMessage: String {
        guard source == .spotify else { return L.t("Nothing queued after this track") }
        return SpotifyAuth.shared.isConnected
            ? L.t("Nothing queued after this track")
            : L.t("Connect a Spotify account in Settings to see the queue")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(L.t("Playing Next"))
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(Theme.secondaryText)
                .padding(.leading, 12)
                .padding(.top, 4)

            if media.upNext.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "text.line.first.and.arrowtriangle.forward")
                        .font(.system(size: 17, weight: .light))
                    Text(emptyMessage)
                        .font(.system(size: 10.5))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundStyle(Theme.tertiaryText)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 2) {
                        ForEach(media.upNext) { entry in
                            QueueRow(entry: entry, loader: media.queueArtwork) {
                                media.play(entry)
                            }
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.bottom, 4)
                }
            }
        }
    }
}

private struct QueueRow: View {
    var entry: QueueEntry
    var loader: QueueArtworkLoader
    var play: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: play) {
            row
        }
        .buttonStyle(.plain)
        .disabled(entry.handle == nil)
        .onHover { hovering = $0 }
        .animation(Motion.quick, value: hovering)
    }

    private var row: some View {
        HStack(spacing: 9) {
            Group {
                if let image = loader.image(for: entry.artworkURL) {
                    Image(nsImage: image).resizable().aspectRatio(contentMode: .fill)
                } else {
                    Text("\(entry.id + 1)")
                        .font(Typo.digits(10, .semibold))
                        .foregroundStyle(Theme.tertiaryText)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Theme.card)
                }
            }
            .frame(width: 26, height: 26)
            .clipShape(RoundedRectangle(cornerRadius: 6.5, style: .continuous))

            VStack(alignment: .leading, spacing: 0) {
                Text(entry.title)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(Theme.primaryText)
                    .lineLimit(1)
                Text(entry.artist)
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.tertiaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Image(systemName: "play.fill")
                .font(.system(size: 8.5, weight: .bold))
                .foregroundStyle(Theme.secondaryText)
                .opacity(hovering ? 1 : 0)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(hovering ? Theme.cardHover : .clear)
        }
        .contentShape(Rectangle())
    }
}

private struct ToggleButton: View {
    var symbol: String
    var isOn: Bool
    var tint: Color?
    var action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isOn ? (tint ?? Theme.accent) : Theme.primaryText.opacity(hovering ? 0.9 : 0.55))
                .frame(width: 34, height: 32)
                .background {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(hovering ? Theme.cardHover : .clear)
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(Motion.quick, value: hovering)
    }
}

// MARK: - Buttons

private struct SourceBadge: View {
    var source: NowPlaying.Source

    var body: some View {
        Text(source.rawValue)
            .font(Typo.rounded(8.5, .bold))
            .tracking(0.3)
            .foregroundStyle(Theme.tertiaryText)
            .padding(.horizontal, 5)
            .padding(.vertical, 1.5)
            .background { Capsule().fill(Theme.card) }
    }
}

private struct TransportButton: View {
    var symbol: String
    var size: CGFloat
    var action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .medium))
                .foregroundStyle(Theme.primaryText)
                .opacity(hovering ? 1 : 0.86)
                .frame(width: 42, height: 34)
                .background { Circle().fill(hovering ? Theme.cardHover : .clear).frame(width: 34, height: 34) }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(Motion.quick, value: hovering)
    }
}

private struct OutputDeviceButton: View {
    @State private var controller = OutputMenuController()
    @State private var hovering = false

    var body: some View {
        Button {
            controller.show(at: NSEvent.mouseLocation)
        } label: {
            Image(systemName: "laptopcomputer")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(hovering ? Theme.primaryText : Theme.primaryText.opacity(0.8))
                .frame(width: 38, height: 32)
                .background {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(hovering ? Theme.cardHover : .clear)
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(Motion.quick, value: hovering)
    }
}

@MainActor
private final class OutputMenuController: NSObject {
    private var devices: [AudioOutputDevice] = []

    func show(at point: CGPoint) {
        devices = AudioOutputs.devices()
        let current = AudioOutputs.current()
        let menu = NSMenu()
        for (index, device) in devices.enumerated() {
            let item = NSMenuItem(title: device.name, action: #selector(pick(_:)), keyEquivalent: "")
            item.target = self
            item.tag = index
            item.state = device.id == current ? .on : .off
            menu.addItem(item)
        }
        if devices.isEmpty {
            menu.addItem(withTitle: "No output devices", action: nil, keyEquivalent: "")
        }
        menu.popUp(positioning: nil, at: point, in: nil)
    }

    @objc private func pick(_ sender: NSMenuItem) {
        guard devices.indices.contains(sender.tag) else { return }
        AudioOutputs.select(devices[sender.tag])
    }
}

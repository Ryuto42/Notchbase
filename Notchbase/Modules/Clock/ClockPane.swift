import SwiftUI

struct ClockPane: View {
    @Bindable var store: ClockStore

    var body: some View {
        HStack(spacing: 0) {
            ReadoutColumn(store: store)
                .frame(maxWidth: .infinity)

            Rectangle()
                .fill(Theme.hairline)
                .frame(width: 1)
                .padding(.vertical, 4)

            Group {
                switch store.mode {
                case .timer: PresetColumn(store: store)
                case .stopwatch: LapColumn(store: store)
                }
            }
            .frame(width: 216)
            .transition(.opacity)
        }
        .padding(.horizontal, 10)
        .padding(.top, 4)
        .animation(Motion.content, value: store.mode)
    }
}

// MARK: - Left column

private struct ReadoutColumn: View {
    @Bindable var store: ClockStore

    @State private var digits = ""
    @State private var focused = false
    @State private var popTrigger = 0

    private var entering: Bool { store.mode == .timer && !store.timerActive }

    var body: some View {
        VStack(spacing: 0) {
            ModePicker(mode: $store.mode)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)

            if store.mode == .timer && store.alerting {
                AlertReadout()
            } else {
                TimelineView(.periodic(from: .now, by: store.mode == .stopwatch ? 0.03 : 0.2)) { context in
                    VStack(spacing: 8) {
                        ZStack {
                            if entering {
                                DigitKeyCatcher(focused: $focused,
                                                onDigit: append,
                                                onDelete: removeLast,
                                                onReturn: start,
                                                onEscape: { withAnimation(Motion.content) { digits = "" } })
                            }
                            readout(at: context.date)
                                .font(Typo.digits(46, .semibold))
                                .contentTransition(.numericText())
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                                .allowsHitTesting(false)
                                .keyframeAnimator(initialValue: Pop(), trigger: popTrigger) { content, pop in
                                    content
                                        .scaleEffect(pop.scale)
                                        .opacity(pop.opacity)
                                        .blur(radius: pop.blur)
                                } keyframes: { _ in
                                    KeyframeTrack(\.scale) {
                                        MoveKeyframe(0.72)
                                        SpringKeyframe(1.05, duration: 0.2, spring: .snappy)
                                        SpringKeyframe(1, duration: 0.22, spring: .smooth)
                                    }
                                    KeyframeTrack(\.opacity) {
                                        MoveKeyframe(0)
                                        LinearKeyframe(1, duration: 0.16)
                                    }
                                    KeyframeTrack(\.blur) {
                                        MoveKeyframe(6)
                                        LinearKeyframe(0, duration: 0.2)
                                    }
                                }
                        }
                        .frame(width: 280, height: 56)

                        footer(at: context.date)
                            .frame(height: 12)
                    }
                }
            }

            Spacer(minLength: 0)

            controls
                .padding(.bottom, 12)
        }
        .padding(.trailing, 13)
        .onAppear { popTrigger += 1 }
        .onChange(of: store.mode) { _, _ in popTrigger += 1 }
        .animation(Motion.quick, value: focused)
    }

    private func readout(at now: Date) -> Text {
        switch store.mode {
        case .timer where entering && !digits.isEmpty:
            styled(String(repeating: "0", count: 6 - digits.count) + digits, typedFrom: 6 - digits.count)
        case .timer where entering:
            styled(ClockFormat.digits(store.timerTotal), typedFrom: 0)
        case .timer:
            styled(ClockFormat.digits(store.timerRemaining(at: now)), typedFrom: 0)
        case .stopwatch:
            ClockFormat.elapsed(store.stopwatchElapsed(at: now)).reduce(Text("")) { text, character in
                text + Text(String(character))
                    .foregroundStyle(character.isNumber ? Theme.primaryText : Theme.tertiaryText)
            }
        }
    }

    private func styled(_ six: String, typedFrom: Int) -> Text {
        var result = Text("")
        for (index, character) in six.enumerated() {
            if index == 2 || index == 4 {
                result = result + Text(":").foregroundStyle(Theme.tertiaryText)
            }
            result = result + Text(String(character))
                .foregroundStyle(index >= typedFrom ? Theme.primaryText : Theme.tertiaryText)
        }
        return result
    }

    @ViewBuilder
    private func footer(at now: Date) -> some View {
        switch store.mode {
        case .timer where entering:
            Capsule()
                .fill(Theme.accent.opacity(focused ? 0.7 : 0))
                .frame(width: 200, height: 2)
        case .timer:
            Meter(value: store.timerProgress(at: now),
                  tint: store.timerRunning ? Theme.warm : Theme.accent,
                  height: 4)
                .frame(width: 220)
        case .stopwatch:
            Text(store.laps.isEmpty ? " " : L.count("Lap %@", store.laps.count + 1))
                .font(Typo.rounded(10.5, .semibold))
                .foregroundStyle(Theme.tertiaryText)
        }
    }

    private func append(_ character: Character) {
        guard digits.count < 6, !(digits.isEmpty && character == "0") else { return }
        withAnimation(Motion.content) { digits.append(character) }
    }

    private func removeLast() {
        guard !digits.isEmpty else { return }
        withAnimation(Motion.content) { _ = digits.removeLast() }
    }

    private func start() {
        guard !digits.isEmpty else {
            store.toggleTimer()
            return
        }
        let padded = Array(String(repeating: "0", count: 6 - digits.count) + digits)
        let value = { (range: Range<Int>) in Int(String(padded[range])) ?? 0 }
        let total = value(0..<2) * 3600 + value(2..<4) * 60 + value(4..<6)
        withAnimation(Motion.content) { digits = "" }
        guard total > 0 else { return }
        store.startTimer(TimeInterval(min(total, 99 * 3600 + 59 * 60 + 59)))
    }

    @ViewBuilder
    private var controls: some View {
        switch store.mode {
        case .timer where store.alerting:
            ClockButton(symbol: "checkmark", prominent: true) { store.dismissAlert() }
        case .timer:
            HStack(spacing: 6) {
                ClockButton(symbol: store.timerRunning ? "pause.fill" : "play.fill", prominent: true) {
                    if entering { start() } else { store.toggleTimer() }
                }
                ClockButton(symbol: "xmark") {
                    withAnimation(Motion.content) { digits = "" }
                    store.cancelTimer()
                }
                    .opacity(store.timerActive || !digits.isEmpty ? 1 : 0.35)
                    .disabled(!store.timerActive && digits.isEmpty)
            }
        case .stopwatch:
            HStack(spacing: 6) {
                ClockButton(symbol: store.stopwatchRunning ? "flag.fill" : "arrow.counterclockwise") {
                    store.lapOrReset()
                }
                .opacity(store.stopwatchActive ? 1 : 0.35)
                .disabled(!store.stopwatchActive)
                ClockButton(symbol: store.stopwatchRunning ? "pause.fill" : "play.fill", prominent: true) {
                    store.toggleStopwatch()
                }
            }
        }
    }
}

private struct Pop {
    var scale = 1.0
    var opacity = 1.0
    var blur = 0.0
}

private struct DigitKeyCatcher: NSViewRepresentable {
    @Binding var focused: Bool
    var onDigit: (Character) -> Void
    var onDelete: () -> Void
    var onReturn: () -> Void
    var onEscape: () -> Void

    func makeNSView(context: Context) -> CatcherView {
        let view = CatcherView()
        view.owner = self
        return view
    }

    func updateNSView(_ view: CatcherView, context: Context) {
        view.owner = self
    }

    final class CatcherView: NSView {
        var owner: DigitKeyCatcher?
        private var observer: Any?

        override var acceptsFirstResponder: Bool { true }
        override var needsPanelToBecomeKey: Bool { true }

        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

        override func mouseDown(with event: NSEvent) {
            window?.makeFirstResponder(self)
        }

        override func becomeFirstResponder() -> Bool {
            owner?.focused = true
            return true
        }

        override func resignFirstResponder() -> Bool {
            owner?.focused = false
            return true
        }

        override func viewDidMoveToWindow() {
            if let observer { NotificationCenter.default.removeObserver(observer) }
            observer = nil
            guard let window else { return }
            observer = NotificationCenter.default.addObserver(
                forName: NSWindow.didResignKeyNotification, object: window, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self, self.window?.firstResponder === self else { return }
                    self.window?.makeFirstResponder(nil)
                }
            }
        }

        override func keyDown(with event: NSEvent) {
            guard let owner else { return super.keyDown(with: event) }
            switch event.keyCode {
            case 36, 76: owner.onReturn()
            case 51, 117: owner.onDelete()
            case 53:
                owner.onEscape()
                window?.makeFirstResponder(nil)
            default:
                let typed = (event.charactersIgnoringModifiers ?? "").precomposedStringWithCompatibilityMapping
                let digits = typed.filter { $0.isASCII && $0.isWholeNumber }
                guard !digits.isEmpty else { return super.keyDown(with: event) }
                digits.forEach(owner.onDigit)
            }
        }
    }
}

private struct AlertReadout: View {
    var body: some View {
        VStack(spacing: 8) {
            Label(L.t("Time's up"), systemImage: "bell.fill")
                .font(Typo.rounded(13, .semibold))
                .foregroundStyle(Theme.warm)
                .symbolEffect(.pulse, options: .repeating, isActive: true)
            Text("00:00:00")
                .font(Typo.digits(46, .semibold))
                .foregroundStyle(Theme.warm)
                .phaseAnimator([1.0, 0.3]) { content, phase in
                    content.opacity(phase)
                } animation: { _ in .easeInOut(duration: 0.55) }
        }
    }
}

private struct ModePicker: View {
    @Binding var mode: ClockStore.Mode

    var body: some View {
        HStack(spacing: 4) {
            option(.timer, title: L.t("Timer"), symbol: "timer")
            option(.stopwatch, title: L.t("Stopwatch"), symbol: "stopwatch")
        }
        .padding(3)
        .background { Capsule().fill(Theme.card) }
        .overlay { Capsule().strokeBorder(Theme.stroke, lineWidth: 0.5) }
    }

    private func option(_ value: ClockStore.Mode, title: String, symbol: String) -> some View {
        Button {
            mode = value
        } label: {
            Label(title, systemImage: symbol)
                .font(Typo.rounded(10.5, .semibold))
                .foregroundStyle(mode == value ? Theme.primaryText : Theme.secondaryText)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background { Capsule().fill(mode == value ? Theme.cardHover : .clear) }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct ClockButton: View {
    var symbol: String
    var prominent = false
    var action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: prominent ? 17 : 12, weight: .semibold))
                .foregroundStyle(Theme.primaryText.opacity(hovering ? 1 : 0.86))
                .frame(width: prominent ? 46 : 42, height: prominent ? 46 : 34)
                .background {
                    if prominent {
                        Circle().fill(hovering ? Theme.cardHover : Theme.card)
                    } else {
                        Capsule().fill(hovering ? Theme.cardHover : .clear)
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(Motion.quick, value: hovering)
    }
}

// MARK: - Right column

private struct PresetColumn: View {
    var store: ClockStore

    private let columns = [GridItem(.flexible(), spacing: 5), GridItem(.flexible(), spacing: 5)]

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            ColumnTitle(text: L.t("Presets"))
            LazyVGrid(columns: columns, spacing: 5) {
                ForEach(ClockStore.presets, id: \.self) { seconds in
                    PresetCard(seconds: seconds, selected: !store.timerActive && store.timerTotal == seconds) {
                        store.startTimer(seconds)
                    }
                }
            }
            .padding(.horizontal, 10)
            Spacer(minLength: 0)
        }
    }
}

private struct PresetCard: View {
    var seconds: TimeInterval
    var selected: Bool
    var action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "play.fill")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(hovering ? Theme.warm : Theme.tertiaryText)
                Text(ClockFormat.preset(seconds))
                    .font(Typo.digits(12.5, .semibold))
                    .foregroundStyle(selected ? Theme.primaryText : Theme.secondaryText)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .frame(height: 30)
            .cardBackground(hovering: hovering || selected, radius: 9)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(Motion.quick, value: hovering)
    }
}

private struct LapColumn: View {
    var store: ClockStore

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            ColumnTitle(text: L.t("Laps"))
            if store.laps.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "flag")
                        .font(.system(size: 17, weight: .light))
                    Text(L.t("Laps appear here"))
                        .font(.system(size: 10.5))
                }
                .foregroundStyle(Theme.tertiaryText)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 3) {
                        ForEach(Array(store.laps.enumerated()), id: \.offset) { offset, total in
                            let previous = offset + 1 < store.laps.count ? store.laps[offset + 1] : 0
                            LapRow(number: store.laps.count - offset, split: total - previous, total: total)
                                .transition(.opacity.combined(with: .offset(y: -6)))
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.bottom, 4)
                }
            }
        }
        .animation(Motion.content, value: store.laps.count)
    }
}

private struct LapRow: View {
    var number: Int
    var split: TimeInterval
    var total: TimeInterval

    var body: some View {
        HStack(spacing: 9) {
            Text(L.count("Lap %@", number))
                .font(Typo.rounded(10, .semibold))
                .foregroundStyle(Theme.tertiaryText)
                .fixedSize()
                .frame(minWidth: 44, alignment: .leading)
            Capsule()
                .fill(Theme.accent)
                .frame(width: 2.5, height: 18)
            Text(ClockFormat.elapsed(split))
                .font(Typo.digits(11.5, .medium))
                .foregroundStyle(Theme.primaryText)
            Spacer(minLength: 0)
            Text(ClockFormat.elapsed(total))
                .font(Typo.digits(10))
                .foregroundStyle(Theme.secondaryText)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .cardBackground(radius: 9)
    }
}

private struct ColumnTitle: View {
    var text: String

    var body: some View {
        Text(text)
            .font(.system(size: 11.5, weight: .semibold))
            .foregroundStyle(Theme.secondaryText)
            .padding(.leading, 12)
            .padding(.top, 2)
    }
}

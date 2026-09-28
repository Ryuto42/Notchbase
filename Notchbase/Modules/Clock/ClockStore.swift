import AppKit
import Observation

@Observable
final class ClockStore {
    enum Mode: String {
        case timer, stopwatch
    }

    var mode: Mode = .timer

    static let presets: [TimeInterval] = [60, 3 * 60, 5 * 60, 10 * 60, 15 * 60, 25 * 60, 30 * 60, 60 * 60]

    private(set) var timerTotal: TimeInterval = 5 * 60
    private(set) var timerEnd: Date?
    private(set) var timerPaused: TimeInterval?
    private(set) var timerFinishedAt: Date?
    private(set) var alerting = false
    private(set) var hourDigits = 0

    @ObservationIgnored var onFinish: (() -> Void)?
    @ObservationIgnored private var alertTask: Task<Void, Never>?
    @ObservationIgnored private var hoursTask: Task<Void, Never>?

    private(set) var stopwatchStart: Date?
    private(set) var stopwatchBase: TimeInterval = 0
    private(set) var laps: [TimeInterval] = []

    @ObservationIgnored private var finishTask: Task<Void, Never>?

    // MARK: - Timer

    var timerRunning: Bool { timerEnd != nil }
    var timerActive: Bool { timerEnd != nil || timerPaused != nil }

    func timerRemaining(at now: Date) -> TimeInterval {
        if let timerEnd { return max(0, timerEnd.timeIntervalSince(now)) }
        return timerPaused ?? timerTotal
    }

    func timerProgress(at now: Date) -> Double {
        guard timerTotal > 0 else { return 0 }
        return 1 - timerRemaining(at: now) / timerTotal
    }

    func startTimer(_ seconds: TimeInterval) {
        defer { refreshHours() }
        dismissAlert()
        timerTotal = seconds
        timerPaused = nil
        timerFinishedAt = nil
        run(for: seconds)
    }

    func toggleTimer() {
        defer { refreshHours() }
        if let timerEnd {
            timerPaused = max(0, timerEnd.timeIntervalSinceNow)
            self.timerEnd = nil
            finishTask?.cancel()
        } else {
            dismissAlert()
            timerFinishedAt = nil
            run(for: timerPaused ?? timerTotal)
            timerPaused = nil
        }
    }

    func cancelTimer() {
        defer { refreshHours() }
        dismissAlert()
        finishTask?.cancel()
        timerEnd = nil
        timerPaused = nil
        timerFinishedAt = nil
    }

    func dismissAlert() {
        alertTask?.cancel()
        alerting = false
        refreshHours()
    }

    private func refreshHours() {
        hoursTask?.cancel()
        var flip: Date?
        if alerting {
            hourDigits = 0
        } else if timerActive {
            let hours = Int(timerRemaining(at: Date()).rounded(.up)) / 3600
            hourDigits = hours == 0 ? 0 : String(hours).count
            if hours > 0, let timerEnd {
                flip = timerEnd.addingTimeInterval(hours >= 10 ? -35999 : -3599)
            }
        } else {
            let hours = Int(stopwatchElapsed(at: Date())) / 3600
            hourDigits = hours == 0 ? 0 : String(hours).count
            if hours < 10, let stopwatchStart {
                flip = stopwatchStart.addingTimeInterval((hours == 0 ? 3600 : 36000) - stopwatchBase)
            }
        }
        guard let flip else { return }
        hoursTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(max(0, flip.timeIntervalSinceNow) + 0.05))
            guard !Task.isCancelled else { return }
            self?.refreshHours()
        }
    }

    private func run(for seconds: TimeInterval) {
        let end = Date().addingTimeInterval(seconds)
        timerEnd = end
        finishTask?.cancel()
        finishTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(max(0, end.timeIntervalSinceNow)))
            guard !Task.isCancelled, let self, self.timerEnd == end else { return }
            self.finish()
        }
    }

    private func finish() {
        defer { refreshHours() }
        timerEnd = nil
        timerPaused = nil
        timerFinishedAt = Date()
        alerting = true
        onFinish?()
        alertTask?.cancel()
        alertTask = Task { [weak self] in
            for _ in 0..<3 {
                NSSound(named: "Glass")?.play()
                try? await Task.sleep(for: .seconds(1.3))
                if Task.isCancelled { return }
            }
            try? await Task.sleep(for: .seconds(56))
            guard !Task.isCancelled else { return }
            self?.dismissAlert()
        }
    }

    // MARK: - Stopwatch

    var stopwatchRunning: Bool { stopwatchStart != nil }
    var stopwatchActive: Bool { stopwatchStart != nil || stopwatchBase > 0 }

    func stopwatchElapsed(at now: Date) -> TimeInterval {
        stopwatchBase + (stopwatchStart.map { now.timeIntervalSince($0) } ?? 0)
    }

    func toggleStopwatch() {
        defer { refreshHours() }
        if let stopwatchStart {
            stopwatchBase += Date().timeIntervalSince(stopwatchStart)
            self.stopwatchStart = nil
        } else {
            stopwatchStart = Date()
        }
    }

    func lapOrReset() {
        defer { refreshHours() }
        if stopwatchRunning {
            laps.insert(stopwatchElapsed(at: Date()), at: 0)
        } else {
            stopwatchBase = 0
            laps = []
        }
    }
}

enum ClockFormat {
    static func countdown(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded(.up))
        let hours = total / 3600, minutes = (total % 3600) / 60, secs = total % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, secs)
            : String(format: "%d:%02d", minutes, secs)
    }

    static func clock(_ seconds: TimeInterval) -> String {
        let digits = Array(digits(seconds))
        return "\(digits[0])\(digits[1]):\(digits[2])\(digits[3]):\(digits[4])\(digits[5])"
    }

    static func digits(_ seconds: TimeInterval) -> String {
        let total = min(Int(seconds.rounded(.up)), 99 * 3600 + 59 * 60 + 59)
        return String(format: "%02d%02d%02d", total / 3600, (total % 3600) / 60, total % 60)
    }

    static func elapsed(_ seconds: TimeInterval, hundredths: Bool = true) -> String {
        let total = Int(seconds)
        let hours = total / 3600, minutes = (total % 3600) / 60, secs = total % 60
        let fraction = Int((seconds - Double(total)) * 100)
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return hundredths
            ? String(format: "%02d:%02d.%02d", minutes, secs, fraction)
            : String(format: "%d:%02d", minutes, secs)
    }

    static func preset(_ seconds: TimeInterval) -> String {
        seconds >= 3600 ? "\(Int(seconds / 3600))h" : "\(Int(seconds / 60))m"
    }
}

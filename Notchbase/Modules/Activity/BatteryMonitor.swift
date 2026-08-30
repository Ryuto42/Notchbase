import Foundation
import Observation
import IOKit.ps

@Observable
final class BatteryMonitor {
    private(set) var percentage: Int?
    private(set) var isCharging = false
    private(set) var minutesRemaining: Int?

    @ObservationIgnored private var timer: Timer?

    func start() {
        refresh()
        let timer = Timer(timeInterval: 20, repeats: true) { _ in
            MainActor.assumeIsolated { self.refresh() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func refresh() {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef] else {
            percentage = nil
            return
        }

        for source in sources {
            guard let info = IOPSGetPowerSourceDescription(blob, source)?.takeUnretainedValue()
                    as? [String: Any] else { continue }
            guard let current = info[kIOPSCurrentCapacityKey] as? Int,
                  let max = info[kIOPSMaxCapacityKey] as? Int, max > 0 else { continue }
            percentage = Int((Double(current) / Double(max) * 100).rounded())
            isCharging = (info[kIOPSPowerSourceStateKey] as? String) == kIOPSACPowerValue
            let remaining = info[kIOPSTimeToEmptyKey] as? Int ?? -1
            minutesRemaining = remaining > 0 ? remaining : nil
            return
        }
    }
}

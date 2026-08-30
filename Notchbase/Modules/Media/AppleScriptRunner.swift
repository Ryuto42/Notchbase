import Foundation
import AppKit

final class AppleScriptRunner {
    static let shared = AppleScriptRunner()

    struct Failure: Equatable {
        var code: Int
        var message: String

        var isNotPermitted: Bool { code == -1743 || code == -10004 }
    }

    private(set) var lastFailure: Failure?
    private var cache: [String: NSAppleScript] = [:]

    func string(_ source: String) -> String? {
        descriptor(source)?.stringValue
    }

    func data(_ source: String) -> Data? {
        descriptor(source)?.data
    }

    @discardableResult
    func execute(_ source: String) -> Bool {
        descriptor(source) != nil
    }

    private func descriptor(_ source: String) -> NSAppleEventDescriptor? {
        let script: NSAppleScript
        if let cached = cache[source] {
            script = cached
        } else {
            guard let created = NSAppleScript(source: source) else {
                lastFailure = Failure(code: 0, message: "Script could not be compiled")
                return nil
            }
            cache[source] = created
            script = created
        }

        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)
        if let error {
            let code = error[NSAppleScript.errorNumber] as? Int ?? 0
            let message = error[NSAppleScript.errorBriefMessage] as? String
                ?? error[NSAppleScript.errorMessage] as? String
                ?? "Unknown AppleScript error"
            lastFailure = Failure(code: code, message: message)
            return nil
        }
        lastFailure = nil
        return result
    }
}

extension NSRunningApplication {
    static func isRunning(bundleID: String) -> Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty
    }
}

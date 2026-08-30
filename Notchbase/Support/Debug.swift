import Foundation

enum Debug {
    private static let environment = ProcessInfo.processInfo.environment

    static let isLogging = flag("LOG")
    static let isDemo = flag("DEMO")

    static func log(_ message: @autoclosure () -> String) {
        guard isLogging else { return }
        FileHandle.standardError.write(Data("[nb] \(message())\n".utf8))
    }

    static func value(_ name: String) -> String? { environment["NOTCHBASE_" + name] }
    static func flag(_ name: String) -> Bool { environment["NOTCHBASE_" + name] != nil }
}

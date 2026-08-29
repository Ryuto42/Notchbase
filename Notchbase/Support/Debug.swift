import Foundation

/// Development hooks, every one of them driven by a `NOTCHBASE_*` environment variable so a
/// normally launched build behaves as though none of this exists.
///
///     NOTCHBASE_LOG=1           trace to stderr
///     NOTCHBASE_FORCE_STATE=…   pin the panel open
///     NOTCHBASE_FORCE_TAB=…     pin a tab
///     NOTCHBASE_SNAPSHOT=path   render the panel offscreen and exit
///     NOTCHBASE_DEMO=1          fill every module with fictional content
enum Debug {
    private static let environment = ProcessInfo.processInfo.environment

    static let isLogging = flag("LOG")
    /// Modules stop polling so the fixtures stay on screen.
    static let isDemo = flag("DEMO")

    /// Autoclosure so interpolating a message costs nothing when logging is off.
    static func log(_ message: @autoclosure () -> String) {
        guard isLogging else { return }
        FileHandle.standardError.write(Data("[nb] \(message())\n".utf8))
    }

    static func value(_ name: String) -> String? { environment["NOTCHBASE_" + name] }
    static func flag(_ name: String) -> Bool { environment["NOTCHBASE_" + name] != nil }
}

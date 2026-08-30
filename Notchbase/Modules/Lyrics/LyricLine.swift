import Foundation

struct LyricLine: Codable, Hashable {
    var time: Double
    var text: String
}

enum LrcParser {
    private static let pattern = try? NSRegularExpression(pattern: #"\[(\d{1,2}):(\d{2})([.:]\d{1,3})?\]"#)

    static func parse(_ source: String) -> [LyricLine] {
        guard let pattern else { return [] }
        var lines: [LyricLine] = []

        for raw in source.components(separatedBy: .newlines) {
            let range = NSRange(raw.startIndex..., in: raw)
            let matches = pattern.matches(in: raw, range: range)
            guard !matches.isEmpty, let last = matches.last else { continue }

            let text = String(raw[Range(last.range, in: raw)!.upperBound...])
                .trimmingCharacters(in: .whitespaces)

            for match in matches {
                guard let minutes = Double(substring(raw, match.range(at: 1))),
                      let seconds = Double(substring(raw, match.range(at: 2))) else { continue }
                var fraction = 0.0
                if match.range(at: 3).location != NSNotFound {
                    let piece = substring(raw, match.range(at: 3)).dropFirst()
                    fraction = (Double(piece) ?? 0) / pow(10, Double(piece.count))
                }
                lines.append(LyricLine(time: minutes * 60 + seconds + fraction, text: text))
            }
        }

        return lines.sorted { $0.time < $1.time }
    }

    private static func substring(_ string: String, _ range: NSRange) -> String {
        guard range.location != NSNotFound, let swiftRange = Range(range, in: string) else { return "" }
        return String(string[swiftRange])
    }
}

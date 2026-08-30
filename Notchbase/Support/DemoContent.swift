import AppKit
import Foundation

enum DemoContent {
    static func install(into model: NotchViewModel) {
        model.tray.applyDemo(items)
        model.clipboard.applyDemo(clips)
        model.agents.applyDemo(sessions)
        model.calendar.applyDemo(events)
        model.media.applyDemo(track, queue: queue)
        model.lyrics.applyDemo(lyrics)
        if Debug.flag("DEMO_EDITOR") {
            let start = events[3].start
            model.calendar.draft = CalendarStore.Draft(eventID: events[3].id,
                                                       title: events[3].title,
                                                       start: start,
                                                       end: events[3].end,
                                                       location: "Studio 2",
                                                       notes: "Bring the burndown chart and the three open questions from last week.")
        }
    }

    // MARK: - Fixtures

    private static func minutes(_ value: Double) -> Date {
        Date().addingTimeInterval(value * 60)
    }

    private static var items: [TrayItem] {
        [("Q3-report.pdf", 2_400_000, false),
         ("keynote-cover@2x.png", 830_000, false),
         ("release-notes.md", 4_100, false),
         ("Design exports", 0, true)].enumerated().map { index, file in
            TrayItem(id: UUID(), name: file.0, storedName: nil, bookmark: nil,
                     addedAt: minutes(Double(-index) * 7), isCopy: true,
                     isDirectory: file.2, byteSize: Int64(file.1))
        }
    }

    private static var clips: [ClipEntry] {
        [("git switch -c feature/notch-metrics", true),
         ("https://developer.apple.com/documentation/appkit/nspanel", false),
         ("The build finished in 42s — everything green.", false),
         ("#0B0B0F", false),
         ("hello@example.com", false)].enumerated().map { index, clip in
            ClipEntry(id: UUID(), kind: .text, text: clip.0, imageName: nil,
                      createdAt: minutes(Double(-index) * 4), pinned: clip.1)
        }
    }

    private static var sessions: [AgentSession] {
        var list: [AgentSession] = [
            make("Rewrite the notch hit testing", .claude, "~/Code/notchbase", -1, 48_200, open: true),
            make("Audit the payment webhook", .codex, "~/Code/storefront", -12, 21_400, open: false),
            make("Port the CSV importer to async", .claude, "~/Code/ledger", -46, 9_800, open: false),
            make("Trim the onboarding copy", .codex, "~/Code/marketing-site", -180, 3_150, open: false),
        ]
        list[0].turnOpen = true
        return list
    }

    private static func make(_ title: String, _ tool: AgentSession.Tool, _ directory: String,
                             _ ago: Double, _ tokens: Int, open: Bool) -> AgentSession {
        AgentSession(id: directory + title, tool: tool, title: title,
                     lastActivity: minutes(ago), tokens: tokens,
                     directory: directory, turnOpen: open)
    }

    private static var events: [CalendarStore.Entry] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        func at(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
            calendar.date(byAdding: .day, value: day, to: today)!
                .addingTimeInterval(Double(hour) * 3600 + Double(minute) * 60)
        }
        let plan: [(String, Int, Int, Int, Double, NSColor)] = [
            ("Design review", 0, 10, 0, 1, .systemBlue),
            ("1:1 with Aya", 0, 14, 30, 0.5, .systemPurple),
            ("Ship 0.2.0", 0, 17, 0, 1, .systemOrange),
            ("Sprint planning", 1, 9, 30, 1.5, .systemBlue),
            ("Dentist", 1, 16, 0, 1, .systemTeal),
            ("Team lunch", 2, 12, 0, 1, .systemPink),
            ("Quarterly offsite", 4, 9, 0, 8, .systemIndigo),
        ]
        return plan.enumerated().map { index, event in
            let start = at(event.1, event.2, event.3)
            return CalendarStore.Entry(id: "demo-\(index)", title: event.0, start: start,
                                       end: start.addingTimeInterval(event.4 * 3600),
                                       isAllDay: false, color: event.5)
        }
    }

    private static var track: NowPlaying {
        NowPlaying(source: .spotify, isPlaying: true, title: "Nightglass",
                   artist: "Aoi Field", album: "Slow Harbour",
                   duration: 227, position: 78, artworkURL: nil,
                   isShuffling: false, repeatMode: .all)
    }

    private static var queue: [QueueEntry] {
        [("Paper Lanterns", "Aoi Field"),
         ("Undertow", "Marin Vale"),
         ("Second Winter", "The Long Way Round"),
         ("Halogen", "Aoi Field"),
         ("Tidal", "Kite Season")].enumerated().map { index, entry in
            QueueEntry(id: index, title: entry.0, artist: entry.1,
                       artworkURL: nil, handle: nil, contextURI: nil)
        }
    }

    private static var lyrics: [LyricLine] {
        [(66.0, "Streetlights hum against the window"),
         (71.5, "I trace the harbour with my hand"),
         (77.0, "Everything is quiet in the nightglass"),
         (83.0, "And the morning is a country away"),
         (89.0, "Hold the light a little longer"),
         (95.0, "It never stays as long as we do")]
            .map { LyricLine(time: $0.0, text: $0.1) }
    }
}

enum DemoArtwork {
    static let image: NSImage = {
        let size = NSSize(width: 600, height: 600)
        let art = NSImage(size: size)
        art.lockFocus()
        NSGradient(colors: [NSColor(calibratedRed: 0.11, green: 0.16, blue: 0.34, alpha: 1),
                            NSColor(calibratedRed: 0.36, green: 0.20, blue: 0.42, alpha: 1),
                            NSColor(calibratedRed: 0.86, green: 0.44, blue: 0.34, alpha: 1)])?
            .draw(in: NSRect(origin: .zero, size: size), angle: 62)
        NSColor(calibratedWhite: 1, alpha: 0.16).setStroke()
        for step in stride(from: 90.0, through: 520, by: 78) {
            let ring = NSBezierPath(ovalIn: NSRect(x: 300 - step / 2, y: 250 - step / 2,
                                                   width: step, height: step))
            ring.lineWidth = 1.4
            ring.stroke()
        }
        NSColor(calibratedWhite: 1, alpha: 0.9).setFill()
        NSBezierPath(ovalIn: NSRect(x: 272, y: 222, width: 56, height: 56)).fill()
        art.unlockFocus()
        return art
    }()
}

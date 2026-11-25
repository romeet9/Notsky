import Foundation

/// What a spoken phrase asks Notsky to do. Deterministic: no search, no network, no model.
enum VoiceCommand: Equatable {
    enum Kind: Equatable { case task, note, any }
    enum Music: Equatable { case play, pause, next, previous, nowPlaying }

    /// "rest" still holds an optional " to <card name>" tail; the runner splits it against real cards.
    case add(Kind, rest: String)
    case newTaskGroup(name: String?, items: [String])
    case newNote(name: String?)
    case music(Music)
    case unknown

    static let hint = String(localized: "Try: add task …, new task group …, add note …, next song")

    // MARK: - Parsing

    static func parse(_ transcript: String) -> VoiceCommand {
        let s = clean(transcript)
        guard !s.isEmpty else { return .unknown }

        if let music = parseMusic(s) { return .music(music) }

        // New task group / list / widget.
        let noun = #"(?:(?:task|tasks|todo|to-do|to do)\s+(?:group|list|widget|card)|group|list|widget)"#
        let groupPatterns = [
            #"^(?:create|make|start|add|build|open)\s+(?:a\s+|an\s+|the\s+)?new\s+\#(noun)\b(.*)$"#,
            #"^(?:create|make|build)\s+(?:a\s+|an\s+|the\s+)?\#(noun)\b(.*)$"#,
            #"^new\s+\#(noun)\b(.*)$"#
        ]
        for pattern in groupPatterns {
            if let g = match(pattern, s) {
                return parseGroup(rest: g[1] ?? "")
            }
        }

        // New notes card.
        let newNote = #"^(?:(?:create|make|start|open)\s+)?(?:a\s+|an\s+)?new\s+(?:note|notes|note card|notes card|note widget|notes widget)\b(.*)$"#
        if let g = match(newNote, s) {
            let name = tidyName(stripLead(g[1] ?? "", #"^(?:called|named|titled)\s+"#))
            return .newNote(name: name.isEmpty ? nil : name)
        }

        // Add note.
        let notePatterns = [
            #"^(?:add|take|make|write|jot|put)(?:\s+(?:a|an|new|quick))*\s+note\b(?:\s+(?:that|saying|to|called))?\s*[:,]?\s*(.+)$"#,
            #"^note\s+(?:that\s+|to self\s*[:,]?\s*)?(.+)$"#,
            #"^(?:write down|jot down|write|jot)\s+(.+)$"#
        ]
        for pattern in notePatterns {
            if let g = match(pattern, s), let rest = g[1], !rest.isEmpty { return .add(.note, rest: rest) }
        }

        // Add task.
        let taskPatterns = [
            #"^(?:add|create|make|put|new)(?:\s+(?:a|an|new|another|quick))*\s+(?:task|todo|to-do|to do|item|reminder)s?\b(?:\s+(?:to|that|called|saying))?\s*[:,]?\s*(.+)$"#,
            #"^remind me\s+(?:to\s+|that\s+|about\s+)?(.+)$"#,
            #"^(?:todo|to-do|to do)\s*[:,]?\s+(.+)$"#
        ]
        for pattern in taskPatterns {
            if let g = match(pattern, s), let rest = g[1], !rest.isEmpty { return .add(.task, rest: rest) }
        }

        // "add <text> to <card>" without saying which kind of card.
        if let g = match(#"^(?:add|put)\s+(.+)$"#, s), let rest = g[1], !rest.isEmpty { return .add(.any, rest: rest) }

        return .unknown
    }

    private static func parseMusic(_ s: String) -> Music? {
        let l = s.lowercased()
        let song = #"(?:\s+(?:song|track|one))?"#
        func hit(_ p: String) -> Bool { l.range(of: p, options: .regularExpression) != nil }
        if hit(#"^(?:what'?s|what is|what song is|which song is)\s+(?:this|that|playing|currently playing|playing now|playing right now)(?:\s+song|\s+track)?$"#)
            || hit(#"^what(?:'?s| is) (?:this|that) (?:song|track)$"#)
            || hit(#"^what(?:'?s| is) playing(?: now| right now)?$"#) { return .nowPlaying }
        if hit(#"^(?:play\s+)?(?:the\s+)?(?:next|skip)\#(song)$"#) || hit(#"^skip(?:\s+(?:this|the))?\#(song)$"#) { return .next }
        if hit(#"^(?:play\s+)?(?:the\s+)?(?:previous|prior|last)\#(song)$"#) || hit(#"^(?:go\s+)?back(?:\s+a|\s+one)?\#(song)$"#) { return .previous }
        if hit(#"^(?:play|resume|continue|unpause)(?:\s+the)?(?:\s+(?:music|song|track|playback))?(?:\s+again)?$"#) { return .play }
        if hit(#"^(?:pause|stop|hold)(?:\s+the)?(?:\s+(?:music|song|track|playback))?$"#) { return .pause }
        return nil
    }

    private static func parseGroup(rest: String) -> VoiceCommand {
        var head = rest.trimmingCharacters(in: .whitespacesAndNewlines)
        var itemText: String?
        if let r = head.range(of: #"(?:^|\s)with\s+"#, options: [.regularExpression, .caseInsensitive]) {
            itemText = String(head[r.upperBound...])
            head = String(head[..<r.lowerBound])
        }
        let name = tidyName(stripLead(head, #"^(?:called|named|titled|for)\s+"#))
        let items = (itemText ?? "")
            .replacingOccurrences(of: #",?\s+and\s+"#, with: ",", options: [.regularExpression, .caseInsensitive])
            .split(separator: ",")
            .map { capitalized(tidyText(String($0))) }
            .filter { !$0.isEmpty }
        return .newTaskGroup(name: name.isEmpty ? nil : name, items: items)
    }

    // MARK: - Text helpers

    /// Lowercase-insensitive cleanup: curly quotes, leading fillers ("hey", "please", "can you") and trailing politeness.
    static func clean(_ raw: String) -> String {
        var s = raw
            .replacingOccurrences(of: "’", with: "'")
            .replacingOccurrences(of: "‘", with: "'")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let lead = #"^(?:hey|hi|hello|ok|okay|um+|uh+|so|please|notsky|can you|could you|would you|will you|can i|i want to|i wanna|i'd like to|i would like to|i need to|let's|lets|go ahead and|just)\b[\s,.]*"#
        while let r = s.range(of: lead, options: [.regularExpression, .caseInsensitive]) {
            s.removeSubrange(r)
        }
        let tail = #"[\s,.!?;:]*(?:\s(?:please|thanks|thank you))?[\s,.!?;:]*$"#
        if let r = s.range(of: tail, options: [.regularExpression, .caseInsensitive]) { s.removeSubrange(r) }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Regex match, case-insensitive, returning capture groups (index 0 is the whole match).
    static func match(_ pattern: String, _ s: String) -> [String?]? {
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let ns = s as NSString
        guard let m = re.firstMatch(in: s, range: NSRange(location: 0, length: ns.length)) else { return nil }
        return (0..<m.numberOfRanges).map { i in
            let r = m.range(at: i)
            return r.location == NSNotFound ? nil : ns.substring(with: r).trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    private static func stripLead(_ s: String, _ pattern: String) -> String {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let r = t.range(of: pattern, options: [.regularExpression, .caseInsensitive]) else { return t }
        return String(t[r.upperBound...])
    }

    /// Trailing punctuation and wrapping quotes removed.
    static func tidyText(_ s: String) -> String {
        var t = s.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ".,;:!?")))
        t = t.trimmingCharacters(in: CharacterSet(charactersIn: "\"'“”"))
        return t.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func tidyName(_ s: String) -> String { capitalized(tidyText(s)) }

    static func capitalized(_ s: String) -> String {
        guard let first = s.first else { return s }
        return first.uppercased() + s.dropFirst()
    }

    // MARK: - Card name matching

    private static let numberWords: [String: String] = [
        "zero": "0", "one": "1", "two": "2", "three": "3", "four": "4", "five": "5", "six": "6", "seven": "7",
        "eight": "8", "nine": "9", "ten": "10", "eleven": "11", "twelve": "12"
    ]

    /// Lowercased, diacritic-free, punctuation-free, with spoken numbers as digits ("list two" == "List 2").
    static func normalizeName(_ s: String) -> String {
        let folded = s.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current).lowercased()
        let cleaned = String(folded.map { $0.isLetter || $0.isNumber ? $0 : " " })
        return cleaned.split(separator: " ").map { numberWords[String($0)] ?? String($0) }.joined(separator: " ")
    }

    /// 3 exact, 2 one contains the other or every spoken word is in the title, 0 no match.
    static func nameScore(spoken: String, title: String) -> Int {
        let a = normalizeName(spoken), b = normalizeName(title)
        guard !a.isEmpty, !b.isEmpty else { return 0 }
        if a == b { return 3 }
        if b.contains(a) || (b.count >= 3 && a.contains(b)) { return 2 }
        let titleWords = Set(b.split(separator: " "))
        return a.split(separator: " ").allSatisfy(titleWords.contains) ? 2 : 0
    }
}

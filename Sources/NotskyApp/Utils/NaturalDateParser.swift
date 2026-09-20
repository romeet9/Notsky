import Foundation

public struct ParsedTaskResult {
    public let cleanText: String
    public let dateTag: String?
    public let dueDate: Date?
    public let isToday: Bool
    public let isTomorrow: Bool
}

public final class NaturalDateParser {
    private static let detector: NSDataDetector? = {
        try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
    }()
    
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }()
    
    private static let dayTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter
    }()
    
    /// Parse natural date/time keywords and expressions from user task string
    public static func parse(_ rawText: String) -> ParsedTaskResult {
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return ParsedTaskResult(cleanText: rawText, dateTag: nil, dueDate: nil, isToday: false, isTomorrow: false)
        }
        
        let lower = trimmed.lowercased()
        let calendar = Calendar.current
        let now = Date()
        
        // 1. Keyword-based fast matching for high fidelity
        // Matches: "today 5pm", "today at 3:30 pm", "today 18:00", "today"
        if let match = matchToday(in: trimmed, lower: lower, calendar: calendar, now: now) {
            return match
        }
        
        // Matches: "tomorrow 10am", "tomorrow at 2pm", "tomorrow"
        if let match = matchTomorrow(in: trimmed, lower: lower, calendar: calendar, now: now) {
            return match
        }
        
        // Matches: "tonight", "tonight at 8pm"
        if let match = matchTonight(in: trimmed, lower: lower, calendar: calendar, now: now) {
            return match
        }
        
        // 2. NSDataDetector fallback for advanced dates (e.g. "Oct 24 at 4pm", "Friday 2pm")
        if let detector = detector {
            let matches = detector.matches(in: trimmed, options: [], range: NSRange(location: 0, length: trimmed.utf16.count))
            if let firstMatch = matches.first, let detectedDate = firstMatch.date {
                let matchedString = (trimmed as NSString).substring(with: firstMatch.range)
                var clean = trimmed.replacingOccurrences(of: matchedString, with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                if clean.hasSuffix(" at") || clean.hasSuffix(" on") || clean.hasSuffix(" by") {
                    clean = String(clean.dropLast(3)).trimmingCharacters(in: .whitespacesAndNewlines)
                }
                
                let isToday = calendar.isDateInToday(detectedDate)
                let isTomorrow = calendar.isDateInTomorrow(detectedDate)
                
                let tag: String
                if isToday {
                    tag = "Today " + timeFormatter.string(from: detectedDate)
                } else if isTomorrow {
                    tag = "Tomorrow " + timeFormatter.string(from: detectedDate)
                } else {
                    tag = dayTimeFormatter.string(from: detectedDate)
                }
                
                return ParsedTaskResult(
                    cleanText: clean.isEmpty ? trimmed : clean,
                    dateTag: tag,
                    dueDate: detectedDate,
                    isToday: isToday,
                    isTomorrow: isTomorrow
                )
            }
        }
        
        return ParsedTaskResult(cleanText: trimmed, dateTag: nil, dueDate: nil, isToday: false, isTomorrow: false)
    }
    
    private static func matchToday(in text: String, lower: String, calendar: Calendar, now: Date) -> ParsedTaskResult? {
        let regex = #"\b(?:today|tdy)\b(?:\s+(?:at\s+)?(\d{1,2}(?::\d{2})?\s*(?:am|pm)?|\d{1,2}:\d{2}))?"#
        guard let range = lower.range(of: regex, options: .regularExpression) else { return nil }
        
        let matchStr = String(text[range])
        var clean = text.replacingOccurrences(of: matchStr, with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.hasSuffix(" at") || clean.hasSuffix(" on") || clean.hasSuffix(" by") {
            clean = String(clean.dropLast(3)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        let timePart = matchStr.lowercased().replacingOccurrences(of: "today", with: "").replacingOccurrences(of: "tdy", with: "").replacingOccurrences(of: "at", with: "").trimmingCharacters(in: .whitespaces)
        
        let dateTag: String
        let dueDate: Date?
        if !timePart.isEmpty, let timeDate = parseTime(timePart, on: now, calendar: calendar) {
            dateTag = "Today " + timeFormatter.string(from: timeDate)
            dueDate = timeDate
        } else {
            dateTag = "Today"
            dueDate = calendar.startOfDay(for: now)
        }
        
        return ParsedTaskResult(cleanText: clean.isEmpty ? text : clean, dateTag: dateTag, dueDate: dueDate, isToday: true, isTomorrow: false)
    }
    
    private static func matchTomorrow(in text: String, lower: String, calendar: Calendar, now: Date) -> ParsedTaskResult? {
        let regex = #"\b(?:tomorrow|tmrw|tmrw)\b(?:\s+(?:at\s+)?(\d{1,2}(?::\d{2})?\s*(?:am|pm)?|\d{1,2}:\d{2}))?"#
        guard let range = lower.range(of: regex, options: .regularExpression) else { return nil }
        
        let matchStr = String(text[range])
        var clean = text.replacingOccurrences(of: matchStr, with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.hasSuffix(" at") || clean.hasSuffix(" on") || clean.hasSuffix(" by") {
            clean = String(clean.dropLast(3)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        let timePart = matchStr.lowercased().replacingOccurrences(of: "tomorrow", with: "").replacingOccurrences(of: "tmrw", with: "").replacingOccurrences(of: "at", with: "").trimmingCharacters(in: .whitespaces)
        
        guard let tomorrowDate = calendar.date(byAdding: .day, value: 1, to: now) else { return nil }
        
        let dateTag: String
        let dueDate: Date?
        if !timePart.isEmpty, let timeDate = parseTime(timePart, on: tomorrowDate, calendar: calendar) {
            dateTag = "Tomorrow " + timeFormatter.string(from: timeDate)
            dueDate = timeDate
        } else {
            dateTag = "Tomorrow"
            dueDate = calendar.startOfDay(for: tomorrowDate)
        }
        
        return ParsedTaskResult(cleanText: clean.isEmpty ? text : clean, dateTag: dateTag, dueDate: dueDate, isToday: false, isTomorrow: true)
    }
    
    private static func matchTonight(in text: String, lower: String, calendar: Calendar, now: Date) -> ParsedTaskResult? {
        let regex = #"\btonight\b(?:\s+(?:at\s+)?(\d{1,2}(?::\d{2})?\s*(?:am|pm)?|\d{1,2}:\d{2}))?"#
        guard let range = lower.range(of: regex, options: .regularExpression) else { return nil }
        
        let matchStr = String(text[range])
        var clean = text.replacingOccurrences(of: matchStr, with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.hasSuffix(" at") || clean.hasSuffix(" on") || clean.hasSuffix(" by") {
            clean = String(clean.dropLast(3)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        let target = calendar.date(bySettingHour: 20, minute: 0, second: 0, of: now) ?? now
        let tag = "Tonight 8:00 PM"
        
        return ParsedTaskResult(cleanText: clean.isEmpty ? text : clean, dateTag: tag, dueDate: target, isToday: true, isTomorrow: false)
    }
    
    private static func parseTime(_ timeStr: String, on baseDate: Date, calendar: Calendar) -> Date? {
        let cleanTime = timeStr.trimmingCharacters(in: .whitespaces)
        let isPM = cleanTime.contains("pm")
        let isAM = cleanTime.contains("am")
        let digitsOnly = cleanTime.replacingOccurrences(of: "pm", with: "").replacingOccurrences(of: "am", with: "").trimmingCharacters(in: .whitespaces)
        
        let components = digitsOnly.split(separator: ":")
        guard let hourRaw = Int(components[0]) else { return nil }
        let minuteRaw = components.count > 1 ? (Int(components[1]) ?? 0) : 0
        
        var hour = hourRaw
        if isPM && hour < 12 { hour += 12 }
        if isAM && hour == 12 { hour = 0 }
        if !isPM && !isAM && hour < 8 { hour += 12 } // 5 -> 5pm if unspecified
        
        return calendar.date(bySettingHour: hour, minute: minuteRaw, second: 0, of: baseDate)
    }
}

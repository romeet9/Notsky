import Foundation
import AppKit
import PDFKit

public final class AIFinderService: @unchecked Sendable {
    public static let shared = AIFinderService()
    
    public static let defaultFreeModel = "meta-llama/llama-3.3-70b-instruct:free"
    public static let fallbackFreeModel = "google/gemini-2.0-flash-exp:free"
    
    private let fileManager = FileManager.default
    
    public var apiKey: String {
        get {
            UserDefaults.standard.string(forKey: "notsky_openrouter_api_key") ?? ""
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "notsky_openrouter_api_key")
        }
    }
    
    public var selectedModel: String {
        get {
            UserDefaults.standard.string(forKey: "notsky_openrouter_model") ?? Self.defaultFreeModel
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "notsky_openrouter_model")
        }
    }
    
    private init() {}
    
    // MARK: - Smart Local Storage Document Scanning & Date Sorting
    
    private static let displayDateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "MMM d, yyyy"
        return df
    }()
    
    private static let monthMap: [String: Int] = [
        "january": 1, "jan": 1,
        "february": 2, "feb": 2,
        "march": 3, "mar": 3,
        "april": 4, "apr": 4,
        "may": 5,
        "june": 6, "jun": 6,
        "july": 7, "jul": 7,
        "august": 8, "aug": 8,
        "september": 9, "sep": 9, "sept": 9,
        "october": 10, "oct": 10,
        "november": 11, "nov": 11,
        "december": 12, "dec": 12
    ]
    
    public static func parseDateLimits(query: String, timeframe: String? = nil) -> (min: Date?, max: Date?, isStrict: Bool) {
        let lower = (query + " " + (timeframe ?? "")).lowercased()
        let calendar = Calendar.current
        let now = Date()
        let currentYear = calendar.component(.year, from: now)
        
        // Check for specific year mentioned in text
        var targetYear = currentYear
        for y in 2020...2030 {
            if lower.contains("\(y)") {
                targetYear = y
                break
            }
        }
        
        // 1. Check for month ranges (e.g., "january to march", "jan - mar", "from may to august")
        for (m1Name, m1) in monthMap {
            if lower.contains(m1Name) {
                for (m2Name, m2) in monthMap where m2 > m1 {
                    if lower.contains(m2Name) {
                        let minComp = DateComponents(year: targetYear, month: m1, day: 1)
                        let nextMonth = m2 == 12 ? 1 : m2 + 1
                        let nextYear = m2 == 12 ? targetYear + 1 : targetYear
                        let maxComp = DateComponents(year: nextYear, month: nextMonth, day: 1, second: -1)
                        return (calendar.date(from: minComp), calendar.date(from: maxComp), true)
                    }
                }
            }
        }
        
        // 2. Check for single month mention (e.g., "september", "sep", "in may")
        for (mName, mNum) in monthMap {
            // Check word boundary
            let pattern = "\\b\(mName)\\b"
            if lower.range(of: pattern, options: .regularExpression) != nil {
                let minComp = DateComponents(year: targetYear, month: mNum, day: 1)
                let nextMonth = mNum == 12 ? 1 : mNum + 1
                let nextYear = mNum == 12 ? targetYear + 1 : targetYear
                let maxComp = DateComponents(year: nextYear, month: nextMonth, day: 1, second: -1)
                return (calendar.date(from: minComp), calendar.date(from: maxComp), true)
            }
        }
        
        // 3. Quarter matching
        if lower.contains("q1") {
            return (calendar.date(from: DateComponents(year: targetYear, month: 1, day: 1)),
                    calendar.date(from: DateComponents(year: targetYear, month: 3, day: 31, hour: 23, minute: 59, second: 59)), true)
        } else if lower.contains("q2") {
            return (calendar.date(from: DateComponents(year: targetYear, month: 4, day: 1)),
                    calendar.date(from: DateComponents(year: targetYear, month: 6, day: 30, hour: 23, minute: 59, second: 59)), true)
        } else if lower.contains("q3") {
            return (calendar.date(from: DateComponents(year: targetYear, month: 7, day: 1)),
                    calendar.date(from: DateComponents(year: targetYear, month: 9, day: 30, hour: 23, minute: 59, second: 59)), true)
        } else if lower.contains("q4") {
            return (calendar.date(from: DateComponents(year: targetYear, month: 10, day: 1)),
                    calendar.date(from: DateComponents(year: targetYear, month: 12, day: 31, hour: 23, minute: 59, second: 59)), true)
        }
        
        // 4. Relative timeframes
        if lower.contains("today") {
            let start = calendar.startOfDay(for: now)
            return (start, now, true)
        } else if lower.contains("yesterday") {
            if let yesterday = calendar.date(byAdding: .day, value: -1, to: now) {
                let start = calendar.startOfDay(for: yesterday)
                let end = calendar.date(byAdding: .day, value: 1, to: start)?.addingTimeInterval(-1)
                return (start, end, true)
            }
        } else if lower.contains("7 day") || lower.contains("last week") || lower.contains("past week") {
            return (calendar.date(byAdding: .day, value: -7, to: now), now, true)
        } else if lower.contains("this month") {
            let start = calendar.date(from: calendar.dateComponents([.year, .month], from: now))
            return (start, now, true)
        } else if lower.contains("last month") {
            if let prevMonthDate = calendar.date(byAdding: .month, value: -1, to: now) {
                let comp = calendar.dateComponents([.year, .month], from: prevMonthDate)
                let start = calendar.date(from: comp)
                let nextMonth = calendar.date(byAdding: .month, value: 1, to: start ?? prevMonthDate)?.addingTimeInterval(-1)
                return (start, nextMonth, true)
            }
        } else if lower.contains("last 3 months") || lower.contains("3 months") {
            return (calendar.date(byAdding: .month, value: -3, to: now), now, true)
        } else if lower.contains("last 6 months") || lower.contains("6 months") {
            return (calendar.date(byAdding: .month, value: -6, to: now), now, true)
        } else if lower.contains("last year") {
            let y = currentYear - 1
            return (calendar.date(from: DateComponents(year: y, month: 1, day: 1)),
                    calendar.date(from: DateComponents(year: y, month: 12, day: 31, hour: 23, minute: 59, second: 59)), true)
        } else if lower.contains("2026") {
            return (calendar.date(from: DateComponents(year: 2026, month: 1, day: 1)),
                    calendar.date(from: DateComponents(year: 2026, month: 12, day: 31, hour: 23, minute: 59, second: 59)), true)
        } else if lower.contains("2025") {
            return (calendar.date(from: DateComponents(year: 2025, month: 1, day: 1)),
                    calendar.date(from: DateComponents(year: 2025, month: 12, day: 31, hour: 23, minute: 59, second: 59)), true)
        }
        
        return (nil, nil, false)
    }
    
    // MARK: - Smart Local Storage Document Scanning & Date Sorting
    
    public func searchLocalFiles(matching query: String, timeframe: String? = nil, maxResults: Int = 10) async -> [FinderFileItem] {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var collected: [(item: FinderFileItem, date: Date)] = []
                let lowerQuery = query.lowercased()
                let terms = lowerQuery.split(separator: " ").map(String.init)
                
                // Parse date bounds and strict filter mode
                let (minDateLimit, maxDateLimit, isStrictDate) = Self.parseDateLimits(query: query, timeframe: timeframe)
                
                // 1. Detect target file extensions from query
                var filterExtensions: Set<String>? = nil
                if lowerQuery.contains("pdf") {
                    filterExtensions = ["pdf"]
                } else if lowerQuery.contains("excel") || lowerQuery.contains("spreadsheet") || lowerQuery.contains("csv") || lowerQuery.contains("xlsx") {
                    filterExtensions = ["xlsx", "xls", "csv", "numbers"]
                } else if lowerQuery.contains("word") || lowerQuery.contains("doc") || lowerQuery.contains("docx") || lowerQuery.contains("pages") {
                    filterExtensions = ["docx", "doc", "pages", "rtf", "txt"]
                } else if lowerQuery.contains("image") || lowerQuery.contains("photo") || lowerQuery.contains("screenshot") || lowerQuery.contains("png") || lowerQuery.contains("jpg") {
                    filterExtensions = ["png", "jpg", "jpeg", "heic", "webp"]
                } else if lowerQuery.contains("code") || lowerQuery.contains("script") || lowerQuery.contains("python") || lowerQuery.contains("swift") {
                    filterExtensions = ["swift", "py", "js", "ts", "json", "html", "css", "md"]
                }
                
                let allowedExtensions: Set<String> = filterExtensions ?? [
                    "pdf", "docx", "doc", "xlsx", "xls", "csv", "txt", "md", "markdown",
                    "json", "swift", "py", "js", "ts", "html", "png", "jpg", "jpeg", "heic", "webp"
                ]
                
                // 2. Prioritize Downloads directory if query mentions download/downloaded
                var targetFolders: [URL] = []
                let downloads = self.fileManager.urls(for: .downloadsDirectory, in: .userDomainMask).first
                let docs = self.fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
                let desktop = self.fileManager.urls(for: .desktopDirectory, in: .userDomainMask).first
                let projects = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Projects")
                
                if lowerQuery.contains("download") {
                    targetFolders = [downloads, docs, desktop, projects].compactMap { $0 }
                } else {
                    targetFolders = [docs, downloads, desktop, projects].compactMap { $0 }
                }
                
                var stopWords: Set<String> = [
                    "list", "me", "down", "the", "last", "first", "recent", "find", "show",
                    "search", "where", "is", "my", "all", "get", "i", "downloaded", "created",
                    "files", "file", "documents", "document", "pdfs", "pdf", "images", "doc",
                    "from", "to", "between", "during", "date", "dates", "month", "months", "year",
                    "in", "of", "and", "or", "for", "with", "only"
                ]
                // Also add months and quarters to stopwords so they don't block filename search
                for m in Self.monthMap.keys {
                    stopWords.insert(m)
                }
                for y in 2020...2030 {
                    stopWords.insert("\(y)")
                }
                let meaningfulTerms = terms.filter { !stopWords.contains($0) && $0.count > 1 }
                
                for folder in targetFolders {
                    guard self.fileManager.fileExists(atPath: folder.path) else { continue }
                    
                    let resourceKeys: [URLResourceKey] = [.nameKey, .fileSizeKey, .contentModificationDateKey, .creationDateKey, .isDirectoryKey]
                    guard let enumerator = self.fileManager.enumerator(
                        at: folder,
                        includingPropertiesForKeys: resourceKeys,
                        options: [.skipsHiddenFiles, .skipsPackageDescendants]
                    ) else { continue }
                    
                    for case let fileURL as URL in enumerator {
                        if collected.count >= 200 { break }
                        
                        let ext = fileURL.pathExtension.lowercased()
                        guard allowedExtensions.contains(ext) else { continue }
                        
                        let fileName = fileURL.lastPathComponent
                        let lowerName = fileName.lowercased()
                        let lowerPath = fileURL.path.lowercased()
                        
                        let matches: Bool
                        if meaningfulTerms.isEmpty {
                            matches = true
                        } else {
                            matches = meaningfulTerms.contains { term in
                                lowerName.contains(term) || lowerPath.contains(term)
                            }
                        }
                        
                        if matches {
                            let rv = try? fileURL.resourceValues(forKeys: Set(resourceKeys))
                            let modDate = rv?.contentModificationDate ?? Date.distantPast
                            let creationDate = rv?.creationDate ?? modDate
                            let primaryDate = (creationDate != Date.distantPast) ? creationDate : modDate
                            
                            // Strict timeframe & month/date filtering check
                            if isStrictDate {
                                let satisfiesMin: Bool
                                if let minD = minDateLimit {
                                    satisfiesMin = (modDate >= minD) || (creationDate >= minD)
                                } else {
                                    satisfiesMin = true
                                }
                                
                                let satisfiesMax: Bool
                                if let maxD = maxDateLimit {
                                    satisfiesMax = (modDate <= maxD) || (creationDate <= maxD)
                                } else {
                                    satisfiesMax = true
                                }
                                
                                if !satisfiesMin || !satisfiesMax {
                                    continue
                                }
                            }
                            
                            let sizeStr = self.formattedFileSize(for: fileURL)
                            let summary = self.extractPreviewSummary(for: fileURL, ext: ext)
                            let dateStr = (primaryDate != Date.distantPast) ? Self.displayDateFormatter.string(from: primaryDate) : ""
                            
                            let item = FinderFileItem(
                                name: fileName,
                                path: fileURL.path,
                                fileSize: sizeStr,
                                fileType: ext.uppercased(),
                                summary: summary,
                                formattedDate: dateStr
                            )
                            collected.append((item: item, date: primaryDate))
                        }
                    }
                }
                
                // 3. Sort by most recent date descending
                collected.sort { $0.date > $1.date }
                
                let finalItems = Array(collected.map(\.item).prefix(maxResults))
                continuation.resume(returning: finalItems)
            }
        }
    }
    
    // MARK: - Document Content Extractor (Concise Clean 1-Line Gist)
    
    public func extractPreviewSummary(for fileURL: URL, ext: String) -> String {
        switch ext {
        case "pdf":
            if let pdf = PDFDocument(url: fileURL), let page = pdf.page(at: 0), let text = page.string {
                let clean = text.replacingOccurrences(of: "\n", with: " ")
                    .replacingOccurrences(of: "  ", with: " ")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if clean.count > 15 {
                    return String(clean.prefix(110)) + "..."
                }
            }
            return "PDF document file"
            
        case "txt", "md", "markdown", "json", "csv", "swift", "py", "js", "ts", "html":
            if let content = try? String(contentsOf: fileURL, encoding: .utf8) {
                let clean = content.replacingOccurrences(of: "\n", with: " ")
                    .replacingOccurrences(of: "  ", with: " ")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if clean.count > 15 {
                    return String(clean.prefix(110)) + "..."
                }
            }
            return "Text source document"
            
        case "png", "jpg", "jpeg", "heic", "webp":
            if let image = NSImage(contentsOf: fileURL) {
                return "Image (\(Int(image.size.width)) × \(Int(image.size.height)) px)"
            }
            return "Image asset file"
            
        case "xlsx", "xls", "numbers":
            return "Spreadsheet document data"
            
        case "docx", "doc", "pages":
            return "Word / Pages formatted document"
            
        default:
            return "Local document file"
        }
    }
    
    private func formattedFileSize(for fileURL: URL) -> String {
        guard let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey]), let size = values.fileSize else {
            return ""
        }
        let bcf = ByteCountFormatter()
        bcf.allowedUnits = [.useAll]
        bcf.countStyle = .file
        return bcf.string(fromByteCount: Int64(size))
    }
    
    // MARK: - OpenRouter Query
    
    public func queryCloudAI(
        userPrompt: String,
        relevantFiles: [FinderFileItem],
        chatHistory: [ChatMessage]
    ) async throws -> String {
        guard let url = URL(string: "https://openrouter.ai/api/v1/chat/completions") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let key = apiKey.isEmpty ? "sk-or-v1-anonymous-demo" : apiKey
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("https://notsky.app", forHTTPHeaderField: "HTTP-Referer")
        request.setValue("Notsky macOS Native Widget", forHTTPHeaderField: "X-Title")
        
        var systemInstruction = """
        You are notskyai, a fast macOS desktop AI assistant.
        The user has asked to find or query local documents.
        Interactive file cards with preview, reveal, and copy buttons are automatically displayed below your reply.
        Respond with ONLY 1 short, clean sentence introducing the found documents. Never output file paths, summaries, bullet points, or markdown lists.
        """
        
        if !relevantFiles.isEmpty {
            systemInstruction += "\n\nFound matching files in storage:\n"
            for (idx, file) in relevantFiles.enumerated() {
                systemInstruction += "\(idx + 1). [\(file.fileType)] \(file.name) (\(file.fileSize))\n"
            }
        }
        
        var messagesPayload: [[String: String]] = [
            ["role": "system", "content": systemInstruction]
        ]
        
        let recent = chatHistory.suffix(4)
        for msg in recent {
            messagesPayload.append([
                "role": msg.role,
                "content": msg.content
            ])
        }
        
        messagesPayload.append([
            "role": "user",
            "content": userPrompt
        ])
        
        let bodyPayload: [String: Any] = [
            "model": selectedModel,
            "messages": messagesPayload,
            "max_tokens": 250,
            "temperature": 0.2
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: bodyPayload)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        if httpResponse.statusCode != 200 {
            return generateLocalFallbackResponse(query: userPrompt, files: relevantFiles)
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            return generateLocalFallbackResponse(query: userPrompt, files: relevantFiles)
        }
        
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - Clean Natural 1-Line Local Fallback Response
    
    public func generateLocalFallbackResponse(query: String, files: [FinderFileItem]) -> String {
        if files.isEmpty {
            return "No matching files were found in your local storage for \"\(query)\"."
        }
        
        let count = files.count
        let lower = query.lowercased()
        
        if lower.contains("pdf") {
            return "Found \(count) recent PDF document\(count == 1 ? "" : "s") in your local storage:"
        } else if lower.contains("download") {
            return "Here are the \(count) most recent downloaded file\(count == 1 ? "" : "s") from your storage:"
        } else if lower.contains("image") || lower.contains("screenshot") {
            return "Found \(count) image asset\(count == 1 ? "" : "s") matching your search:"
        } else {
            return "Found \(count) matching document\(count == 1 ? "" : "s") in your local storage:"
        }
    }
}

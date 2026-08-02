import Foundation

public enum OfficialUpdateSource: String, Codable, Equatable, Sendable {
    case openAI = "OpenAI"
    case github = "GitHub"
}

public struct OfficialUpdateItem: Codable, Equatable, Identifiable, Sendable {
    public let title: String
    public let summary: String
    public let link: URL
    public let source: OfficialUpdateSource
    public let publishedAt: Date?

    public init(
        title: String,
        summary: String,
        link: URL,
        source: OfficialUpdateSource,
        publishedAt: Date?
    ) {
        self.title = title
        self.summary = summary
        self.link = link
        self.source = source
        self.publishedAt = publishedAt
    }

    public var id: String { link.absoluteString }
}

public enum OfficialUpdatesFeedError: LocalizedError {
    case invalidFeed

    public var errorDescription: String? {
        "官方动态源返回了无法识别的内容。"
    }
}

public enum OfficialUpdatesFeedParser {
    public static func parse(
        data: Data,
        source: OfficialUpdateSource
    ) throws -> [OfficialUpdateItem] {
        let delegate = RSSParserDelegate(source: source)
        let parser = XMLParser(data: data)
        parser.delegate = delegate

        guard parser.parse() else {
            throw parser.parserError ?? OfficialUpdatesFeedError.invalidFeed
        }

        return delegate.items
    }
}

public enum OfficialUpdatesFilter {
    public static func isRelevant(_ item: OfficialUpdateItem) -> Bool {
        guard item.source == .github else { return true }

        let normalized = item.title.lowercased()
        let phrases = [
            "copilot",
            "codex",
            "coding agent",
            "ai model",
            "generative ai",
            "artificial intelligence"
        ]
        if phrases.contains(where: normalized.contains) {
            return true
        }

        let words = Set(
            normalized.split { !$0.isLetter && !$0.isNumber }.map(String.init)
        )
        return words.contains("ai")
    }
}

public enum UsageSummaryFormatter {
    public static func make(
        snapshot: RateLimitSnapshot,
        asOf now: Date = Date(),
        isDemoMode: Bool = false
    ) -> String {
        var lines = ["QuotaBar · Codex 用量"]
        if isDemoMode {
            lines[0] += "（演示数据）"
        }

        for window in snapshot.preferredBucket?.windows ?? [] {
            let remaining = Int(window.remainingPercent.rounded())
            let resetDescription = resetDescription(for: window.resetsAt, asOf: now)
            lines.append(
                "\(window.windowLabel)：\(remaining)% 剩余（\(resetDescription)）"
            )
        }

        return lines.joined(separator: "\n")
    }

    private static func resetDescription(for resetDate: Date, asOf now: Date) -> String {
        let totalMinutes = max(0, Int(resetDate.timeIntervalSince(now) / 60))
        guard totalMinutes > 0 else { return "即将重置" }

        let days = totalMinutes / (24 * 60)
        let hours = (totalMinutes % (24 * 60)) / 60
        let minutes = totalMinutes % 60

        if days > 0 {
            return hours > 0 ? "\(days)天\(hours)小时后重置" : "\(days)天后重置"
        }
        if hours > 0 {
            return minutes > 0 ? "\(hours)小时\(minutes)分钟后重置" : "\(hours)小时后重置"
        }
        return "\(minutes)分钟后重置"
    }
}

private final class RSSParserDelegate: NSObject, XMLParserDelegate {
    private let source: OfficialUpdateSource
    private(set) var items: [OfficialUpdateItem] = []
    private var isInsideItem = false
    private var currentElement = ""
    private var title = ""
    private var summary = ""
    private var link = ""
    private var publishedAt = ""

    init(source: OfficialUpdateSource) {
        self.source = source
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        currentElement = elementName.lowercased()
        if currentElement == "item" {
            isInsideItem = true
            title = ""
            summary = ""
            link = ""
            publishedAt = ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard isInsideItem else { return }

        switch currentElement {
        case "title": title += string
        case "description": summary += string
        case "link": link += string
        case "pubdate": publishedAt += string
        default: break
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        if elementName.lowercased() == "item" {
            appendCurrentItem()
            isInsideItem = false
        }
        currentElement = ""
    }

    private func appendCurrentItem() {
        let cleanTitle = Self.clean(title, limit: 180)
        let cleanSummary = Self.clean(summary, limit: 280)
        guard
            !cleanTitle.isEmpty,
            let url = URL(string: link.trimmingCharacters(in: .whitespacesAndNewlines)),
            Self.isAllowed(url: url, for: source)
        else { return }

        items.append(
            OfficialUpdateItem(
                title: cleanTitle,
                summary: cleanSummary,
                link: url,
                source: source,
                publishedAt: Self.parseDate(publishedAt)
            )
        )
    }

    private static func isAllowed(url: URL, for source: OfficialUpdateSource) -> Bool {
        guard url.scheme == "https", let host = url.host?.lowercased() else { return false }
        switch source {
        case .openAI:
            return host == "openai.com" || host.hasSuffix(".openai.com")
        case .github:
            return host == "github.blog" || host.hasSuffix(".github.blog")
        }
    }

    private static func clean(_ value: String, limit: Int) -> String {
        let withoutTags = value.replacingOccurrences(
            of: "<[^>]+>",
            with: " ",
            options: .regularExpression
        )
        let decoded = withoutTags
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&nbsp;", with: " ")
        let collapsed = decoded
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
        guard collapsed.count > limit else { return collapsed }
        return String(collapsed.prefix(limit)).trimmingCharacters(in: .whitespaces) + "…"
    }

    private static func parseDate(_ value: String) -> Date? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)

        for format in [
            "EEE, dd MMM yyyy HH:mm:ss Z",
            "EEE, dd MMM yyyy HH:mm:ss zzz"
        ] {
            formatter.dateFormat = format
            if let date = formatter.date(from: trimmed) {
                return date
            }
        }
        return ISO8601DateFormatter().date(from: trimmed)
    }
}

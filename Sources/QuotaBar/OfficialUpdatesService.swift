import Foundation
import QuotaBarCore

@MainActor
final class OfficialUpdatesService: ObservableObject {
    static let shared = OfficialUpdatesService()

    enum Phase: Equatable {
        case idle
        case loading
        case loaded
        case failed
    }

    @Published private(set) var items: [OfficialUpdateItem] = []
    @Published private(set) var phase: Phase = .idle
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var errorMessage: String?

    private let defaults: UserDefaults
    private let cacheLifetime: TimeInterval = 24 * 60 * 60

    private enum Keys {
        static let cachedItems = "officialUpdates.cachedItems"
        static let lastUpdated = "officialUpdates.lastUpdated"
    }

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        restoreCache()
    }

    func refreshIfNeeded(enabled: Bool) async {
        guard enabled else { return }
        if let lastUpdated, Date().timeIntervalSince(lastUpdated) < cacheLifetime {
            return
        }
        await refresh()
    }

    func refresh() async {
        guard phase != .loading else { return }
        phase = .loading
        errorMessage = nil

        let fetchedItems = await OfficialUpdatesClient.fetch()
        guard !fetchedItems.isEmpty else {
            phase = items.isEmpty ? .failed : .loaded
            errorMessage = "暂时无法读取官方动态，请稍后重试。"
            return
        }

        items = Array(
            Dictionary(grouping: fetchedItems, by: \.id)
                .compactMap { $0.value.first }
                .sorted { ($0.publishedAt ?? .distantPast) > ($1.publishedAt ?? .distantPast) }
                .prefix(12)
        )
        lastUpdated = Date()
        phase = .loaded
        saveCache()
    }

    private func restoreCache() {
        guard
            let data = defaults.data(forKey: Keys.cachedItems),
            let decoded = try? JSONDecoder().decode([OfficialUpdateItem].self, from: data)
        else { return }

        items = decoded
        lastUpdated = defaults.object(forKey: Keys.lastUpdated) as? Date
        phase = .loaded
    }

    private func saveCache() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        defaults.set(data, forKey: Keys.cachedItems)
        defaults.set(lastUpdated, forKey: Keys.lastUpdated)
    }
}

private enum OfficialUpdatesClient {
    private struct Feed: Sendable {
        let url: URL
        let source: OfficialUpdateSource
    }

    private static let feeds = [
        Feed(url: URL(string: "https://openai.com/news/rss.xml")!, source: .openAI),
        Feed(url: URL(string: "https://github.blog/changelog/feed/")!, source: .github)
    ]

    static func fetch() async -> [OfficialUpdateItem] {
        await withTaskGroup(of: [OfficialUpdateItem].self) { group in
            for feed in feeds {
                group.addTask {
                    (try? await fetch(feed: feed)) ?? []
                }
            }

            var allItems: [OfficialUpdateItem] = []
            for await items in group {
                allItems.append(contentsOf: items)
            }
            return allItems.filter(OfficialUpdatesFilter.isRelevant)
        }
    }

    private static func fetch(feed: Feed) async throws -> [OfficialUpdateItem] {
        var request = URLRequest(url: feed.url)
        request.timeoutInterval = 15
        request.setValue("application/rss+xml, application/xml;q=0.9", forHTTPHeaderField: "Accept")
        request.setValue("QuotaBar/1.2 Official Updates", forHTTPHeaderField: "User-Agent")

        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpShouldSetCookies = false
        configuration.httpCookieAcceptPolicy = .never
        let session = URLSession(configuration: configuration)

        let (data, response) = try await session.data(for: request)
        guard
            let response = response as? HTTPURLResponse,
            response.statusCode == 200,
            response.url?.host?.lowercased() == feed.url.host?.lowercased()
        else {
            throw URLError(.badServerResponse)
        }
        return try OfficialUpdatesFeedParser.parse(data: data, source: feed.source)
    }
}

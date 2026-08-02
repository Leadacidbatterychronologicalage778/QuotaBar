import Foundation
import Testing
@testable import QuotaBarCore

struct OfficialUpdatesTests {
    @Test
    func parsesAndSanitizesOfficialRSSItems() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0">
          <channel>
            <item>
              <title><![CDATA[Codex &amp; tools update]]></title>
              <description><![CDATA[<p>A short <strong>official</strong> update.</p>]]></description>
              <link>https://openai.com/index/codex-update/</link>
              <pubDate>Fri, 31 Jul 2026 08:00:00 GMT</pubDate>
            </item>
          </channel>
        </rss>
        """

        let items = try OfficialUpdatesFeedParser.parse(
            data: Data(xml.utf8),
            source: .openAI
        )

        #expect(items.count == 1)
        #expect(items[0].title == "Codex & tools update")
        #expect(items[0].summary == "A short official update.")
        #expect(items[0].source == .openAI)
        #expect(items[0].publishedAt != nil)
    }

    @Test
    func rejectsUnexpectedHostsAndFiltersUnrelatedGitHubPosts() throws {
        let xml = """
        <rss version="2.0"><channel>
          <item>
            <title>GitHub Copilot coding agent update</title>
            <description>Relevant</description>
            <link>https://github.blog/changelog/copilot-update/</link>
          </item>
          <item>
            <title>Actions runner maintenance</title>
            <description>Unrelated</description>
            <link>https://github.blog/changelog/actions-update/</link>
          </item>
          <item>
            <title>Fake update</title>
            <description>Untrusted</description>
            <link>https://example.com/fake/</link>
          </item>
        </channel></rss>
        """

        let parsed = try OfficialUpdatesFeedParser.parse(
            data: Data(xml.utf8),
            source: .github
        )
        let relevant = parsed.filter(OfficialUpdatesFilter.isRelevant)

        #expect(parsed.count == 2)
        #expect(relevant.map(\.title) == ["GitHub Copilot coding agent update"])
    }

    @Test
    func formatsClipboardSummaryWithoutAccountInformation() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let fiveHour = RateLimitWindow(
            usedPercent: 37.4,
            windowDurationMinutes: 300,
            resetsAt: now.addingTimeInterval(2 * 60 * 60 + 18 * 60)
        )
        let weekly = RateLimitWindow(
            usedPercent: 61.2,
            windowDurationMinutes: 10_080,
            resetsAt: now.addingTimeInterval(3 * 24 * 60 * 60 + 7 * 60 * 60)
        )
        let snapshot = RateLimitSnapshot(
            buckets: [
                RateLimitBucket(
                    id: "codex",
                    name: nil,
                    planType: "plus",
                    primary: fiveHour,
                    secondary: weekly,
                    reachedType: nil
                )
            ],
            fetchedAt: now
        )

        let summary = UsageSummaryFormatter.make(snapshot: snapshot, asOf: now)

        #expect(summary == """
        QuotaBar · Codex 用量
        5 小时额度：63% 剩余（2小时18分钟后重置）
        周额度：39% 剩余（3天7小时后重置）
        """)
    }
}

import Foundation
import Testing
@testable import QuotaBarCore

struct RateLimitParserTests {
    @Test
    func parsesMultiBucketResponseAndPrefersCodex() throws {
        let payload = """
        {
          "rateLimits": {
            "limitId": "codex",
            "primary": {
              "usedPercent": 25,
              "windowDurationMins": 300,
              "resetsAt": 1785903010
            }
          },
          "rateLimitsByLimitId": {
            "codex_other": {
              "limitId": "codex_other",
              "limitName": "Other",
              "primary": {
                "usedPercent": 42,
                "windowDurationMins": 60,
                "resetsAt": 1785904000
              }
            },
            "codex": {
              "limitId": "codex",
              "planType": "plus",
              "primary": {
                "usedPercent": 98,
                "windowDurationMins": 10080,
                "resetsAt": 1785903010
              }
            }
          }
        }
        """

        let value = try JSONDecoder().decode(JSONValue.self, from: Data(payload.utf8))
        let snapshot = try RateLimitParser.parse(
            result: value,
            fetchedAt: Date(timeIntervalSince1970: 1)
        )

        #expect(snapshot.buckets.count == 2)
        #expect(snapshot.preferredBucket?.id == "codex")
        #expect(snapshot.planType == "plus")
        #expect(snapshot.headlineWindow?.remainingPercent == 2)
        #expect(snapshot.headlineWindow?.windowLabel == "周额度")
    }

    @Test
    func parsesLegacySingleBucketResponse() throws {
        let payload = """
        {
          "rateLimits": {
            "limitId": "codex",
            "primary": {
              "usedPercent": 18.5,
              "windowDurationMins": 300,
              "resetsAt": 1785903010
            }
          }
        }
        """

        let value = try JSONDecoder().decode(JSONValue.self, from: Data(payload.utf8))
        let snapshot = try RateLimitParser.parse(result: value)

        #expect(snapshot.buckets.count == 1)
        #expect(snapshot.headlineWindow?.remainingPercent == 81.5)
        #expect(snapshot.headlineWindow?.windowLabel == "5 小时额度")
    }

    @Test
    func clampsRemainingPercentage() {
        let over = RateLimitWindow(
            usedPercent: 110,
            windowDurationMinutes: 60,
            resetsAt: Date()
        )
        let negative = RateLimitWindow(
            usedPercent: -10,
            windowDurationMinutes: 60,
            resetsAt: Date()
        )

        #expect(over.remainingPercent == 0)
        #expect(negative.remainingPercent == 100)
    }
}

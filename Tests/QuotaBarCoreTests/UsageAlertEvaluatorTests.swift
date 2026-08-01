import Foundation
import Testing
@testable import QuotaBarCore

struct UsageAlertEvaluatorTests {
    @Test
    func firstSnapshotOnlyEstablishesBaseline() {
        var evaluator = UsageAlertEvaluator()
        let events = evaluator.evaluate(
            snapshot: snapshot(remaining: 10, resetsAt: 1_000, fetchedAt: 900),
            lowQuotaThreshold: 20,
            notifyOnReset: true
        )

        #expect(events.isEmpty)
    }

    @Test
    func crossingThresholdNotifiesOncePerWindow() {
        var evaluator = UsageAlertEvaluator()
        _ = evaluator.evaluate(
            snapshot: snapshot(remaining: 21, resetsAt: 1_000, fetchedAt: 900),
            lowQuotaThreshold: 20,
            notifyOnReset: true
        )

        let crossing = evaluator.evaluate(
            snapshot: snapshot(remaining: 19, resetsAt: 1_000, fetchedAt: 920),
            lowQuotaThreshold: 20,
            notifyOnReset: true
        )
        let repeated = evaluator.evaluate(
            snapshot: snapshot(remaining: 18, resetsAt: 1_000, fetchedAt: 930),
            lowQuotaThreshold: 20,
            notifyOnReset: true
        )

        #expect(crossing.count == 1)
        #expect(repeated.isEmpty)
        #expect(
            crossing.first == .lowQuota(
                windowLabel: "5 小时额度",
                remainingPercent: 19,
                resetsAt: Date(timeIntervalSince1970: 1_000)
            )
        )
    }

    @Test
    func resetRequiresElapsedWindowAndRecoveredQuota() {
        var evaluator = UsageAlertEvaluator()
        _ = evaluator.evaluate(
            snapshot: snapshot(remaining: 5, resetsAt: 1_000, fetchedAt: 990),
            lowQuotaThreshold: 20,
            notifyOnReset: true
        )

        let events = evaluator.evaluate(
            snapshot: snapshot(remaining: 100, resetsAt: 2_000, fetchedAt: 1_010),
            lowQuotaThreshold: 20,
            notifyOnReset: true
        )

        #expect(events == [.quotaReset(windowLabel: "5 小时额度", remainingPercent: 100)])
    }

    @Test
    func resetCanBeDisabled() {
        var evaluator = UsageAlertEvaluator()
        _ = evaluator.evaluate(
            snapshot: snapshot(remaining: 5, resetsAt: 1_000, fetchedAt: 990),
            lowQuotaThreshold: 20,
            notifyOnReset: false
        )

        let events = evaluator.evaluate(
            snapshot: snapshot(remaining: 100, resetsAt: 2_000, fetchedAt: 1_010),
            lowQuotaThreshold: 20,
            notifyOnReset: false
        )

        #expect(events.isEmpty)
    }

    private func snapshot(
        remaining: Double,
        resetsAt: TimeInterval,
        fetchedAt: TimeInterval
    ) -> RateLimitSnapshot {
        let window = RateLimitWindow(
            usedPercent: 100 - remaining,
            windowDurationMinutes: 300,
            resetsAt: Date(timeIntervalSince1970: resetsAt)
        )
        let bucket = RateLimitBucket(
            id: "codex",
            name: nil,
            planType: "plus",
            primary: window,
            secondary: nil,
            reachedType: nil
        )
        return RateLimitSnapshot(
            buckets: [bucket],
            fetchedAt: Date(timeIntervalSince1970: fetchedAt)
        )
    }
}

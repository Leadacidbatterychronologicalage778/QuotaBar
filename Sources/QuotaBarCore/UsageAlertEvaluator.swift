import Foundation

public enum UsageAlertEvent: Equatable, Sendable {
    case lowQuota(windowLabel: String, remainingPercent: Int, resetsAt: Date)
    case quotaReset(windowLabel: String, remainingPercent: Int)
}

public struct UsageAlertEvaluator: Sendable {
    private var previousWindows: [Int: RateLimitWindow] = [:]
    private var deliveredLowQuotaKeys: Set<String> = []
    private var deliveredResetKeys: Set<String> = []
    private var hasBaseline = false

    public init() {}

    public mutating func reset() {
        previousWindows = [:]
        deliveredLowQuotaKeys = []
        deliveredResetKeys = []
        hasBaseline = false
    }

    public mutating func evaluate(
        snapshot: RateLimitSnapshot,
        lowQuotaThreshold: Int,
        notifyOnReset: Bool
    ) -> [UsageAlertEvent] {
        let windows = snapshot.preferredBucket?.windows ?? []
        defer {
            previousWindows = Dictionary(
                uniqueKeysWithValues: windows.map { ($0.windowDurationMinutes, $0) }
            )
            hasBaseline = true
        }

        guard hasBaseline else { return [] }

        var events: [UsageAlertEvent] = []
        let threshold = Double(lowQuotaThreshold)

        for current in windows {
            guard let previous = previousWindows[current.windowDurationMinutes] else {
                continue
            }

            let sameWindow = abs(
                current.resetsAt.timeIntervalSince(previous.resetsAt)
            ) < 1
            let lowQuotaKey = [
                String(current.windowDurationMinutes),
                String(Int(current.resetsAt.timeIntervalSince1970)),
                String(lowQuotaThreshold)
            ].joined(separator: "-")

            if sameWindow,
               previous.remainingPercent > threshold,
               current.remainingPercent <= threshold,
               deliveredLowQuotaKeys.insert(lowQuotaKey).inserted
            {
                events.append(
                    .lowQuota(
                        windowLabel: current.windowLabel,
                        remainingPercent: Int(current.remainingPercent.rounded()),
                        resetsAt: current.resetsAt
                    )
                )
            }

            let resetKey = [
                String(current.windowDurationMinutes),
                String(Int(current.resetsAt.timeIntervalSince1970))
            ].joined(separator: "-")
            let resetConfirmed = current.resetsAt > previous.resetsAt
                && previous.resetsAt <= snapshot.fetchedAt
                && current.remainingPercent > previous.remainingPercent

            if notifyOnReset,
               resetConfirmed,
               deliveredResetKeys.insert(resetKey).inserted
            {
                events.append(
                    .quotaReset(
                        windowLabel: current.windowLabel,
                        remainingPercent: Int(current.remainingPercent.rounded())
                    )
                )
            }
        }

        return events
    }
}

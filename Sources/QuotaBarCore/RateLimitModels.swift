import Foundation

public struct RateLimitWindow: Equatable, Sendable, Identifiable {
    public let usedPercent: Double
    public let windowDurationMinutes: Int
    public let resetsAt: Date

    public init(usedPercent: Double, windowDurationMinutes: Int, resetsAt: Date) {
        self.usedPercent = usedPercent
        self.windowDurationMinutes = windowDurationMinutes
        self.resetsAt = resetsAt
    }

    public var id: String {
        "\(windowDurationMinutes)-\(Int(resetsAt.timeIntervalSince1970))"
    }

    public var remainingPercent: Double {
        min(100, max(0, 100 - usedPercent))
    }

    public var windowLabel: String {
        if windowDurationMinutes % 10_080 == 0 {
            let weeks = windowDurationMinutes / 10_080
            return weeks == 1 ? "周额度" : "\(weeks) 周额度"
        }

        if windowDurationMinutes % 60 == 0 {
            let hours = windowDurationMinutes / 60
            return "\(hours) 小时额度"
        }

        return "\(windowDurationMinutes) 分钟额度"
    }
}

public struct RateLimitBucket: Equatable, Sendable, Identifiable {
    public let id: String
    public let name: String?
    public let planType: String?
    public let primary: RateLimitWindow?
    public let secondary: RateLimitWindow?
    public let reachedType: String?

    public init(
        id: String,
        name: String?,
        planType: String?,
        primary: RateLimitWindow?,
        secondary: RateLimitWindow?,
        reachedType: String?
    ) {
        self.id = id
        self.name = name
        self.planType = planType
        self.primary = primary
        self.secondary = secondary
        self.reachedType = reachedType
    }

    public var windows: [RateLimitWindow] {
        [primary, secondary].compactMap { $0 }
    }
}

public struct RateLimitSnapshot: Equatable, Sendable {
    public let buckets: [RateLimitBucket]
    public let fetchedAt: Date

    public init(buckets: [RateLimitBucket], fetchedAt: Date = Date()) {
        self.buckets = buckets
        self.fetchedAt = fetchedAt
    }

    public var preferredBucket: RateLimitBucket? {
        buckets.first(where: { $0.id == "codex" }) ?? buckets.first
    }

    public var headlineWindow: RateLimitWindow? {
        preferredBucket?.primary ?? preferredBucket?.secondary
    }

    public var planType: String? {
        preferredBucket?.planType ?? buckets.compactMap(\.planType).first
    }
}

public enum RateLimitParserError: LocalizedError {
    case invalidPayload
    case noRateLimits

    public var errorDescription: String? {
        switch self {
        case .invalidPayload:
            return "额度接口返回了无法识别的数据。"
        case .noRateLimits:
            return "当前账户没有返回可显示的 Codex 额度。"
        }
    }
}

public enum RateLimitParser {
    public static func parse(
        result: JSONValue,
        fetchedAt: Date = Date()
    ) throws -> RateLimitSnapshot {
        guard let root = result.objectValue else {
            throw RateLimitParserError.invalidPayload
        }

        var bucketValues: [(String, JSONValue)] = []

        if let byID = root["rateLimitsByLimitId"]?.objectValue {
            bucketValues = byID
                .map { ($0.key, $0.value) }
                .sorted { $0.0 < $1.0 }
        } else if let single = root["rateLimits"] {
            let identifier = single["limitId"]?.stringValue ?? "codex"
            bucketValues = [(identifier, single)]
        }

        let buckets = bucketValues.compactMap { key, value in
            parseBucket(fallbackID: key, value: value)
        }

        guard !buckets.isEmpty else {
            throw RateLimitParserError.noRateLimits
        }

        return RateLimitSnapshot(buckets: buckets, fetchedAt: fetchedAt)
    }

    private static func parseBucket(
        fallbackID: String,
        value: JSONValue
    ) -> RateLimitBucket? {
        guard let object = value.objectValue else { return nil }

        let identifier = object["limitId"]?.stringValue ?? fallbackID
        return RateLimitBucket(
            id: identifier,
            name: object["limitName"]?.stringValue,
            planType: object["planType"]?.stringValue,
            primary: parseWindow(object["primary"]),
            secondary: parseWindow(object["secondary"]),
            reachedType: object["rateLimitReachedType"]?.stringValue
        )
    }

    private static func parseWindow(_ value: JSONValue?) -> RateLimitWindow? {
        guard
            let object = value?.objectValue,
            let usedPercent = object["usedPercent"]?.doubleValue,
            let duration = object["windowDurationMins"]?.intValue,
            let resetTimestamp = object["resetsAt"]?.doubleValue
        else {
            return nil
        }

        return RateLimitWindow(
            usedPercent: usedPercent,
            windowDurationMinutes: duration,
            resetsAt: Date(timeIntervalSince1970: resetTimestamp)
        )
    }
}

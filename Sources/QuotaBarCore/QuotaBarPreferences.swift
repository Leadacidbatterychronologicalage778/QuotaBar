import Foundation

public enum StatusItemDisplayStyle: String, CaseIterable, Hashable, Sendable {
    case iconAndPercentage
    case percentageOnly
    case iconOnly
}

public struct StatusItemDisplay: Equatable, Sendable {
    public let title: String
    public let showsIcon: Bool

    public init(title: String, showsIcon: Bool) {
        self.title = title
        self.showsIcon = showsIcon
    }
}

public enum StatusItemDisplayFormatter {
    public static func make(
        remainingPercent: Double?,
        style: StatusItemDisplayStyle
    ) -> StatusItemDisplay {
        let percentage = remainingPercent.map {
            "\(Int(min(100, max(0, $0)).rounded()))%"
        } ?? ""

        switch style {
        case .iconAndPercentage:
            return StatusItemDisplay(title: percentage, showsIcon: true)
        case .percentageOnly:
            return StatusItemDisplay(
                title: percentage.isEmpty ? "--%" : percentage,
                showsIcon: false
            )
        case .iconOnly:
            return StatusItemDisplay(title: "", showsIcon: true)
        }
    }
}

public enum QuotaBarPreferenceDefaults {
    public static let showFloatingPanel = false
    public static let floatingAcrossSpaces = false
    public static let statusItemStyle = StatusItemDisplayStyle.iconAndPercentage
    public static let globalHotKeyEnabled = true
    public static let notificationsEnabled = false
    public static let lowQuotaThreshold = 20
    public static let notifyOnReset = true
}

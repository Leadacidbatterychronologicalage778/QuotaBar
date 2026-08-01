import Combine
import Foundation
import QuotaBarCore
import UserNotifications

@MainActor
final class UsageNotificationService: ObservableObject {
    static let shared = UsageNotificationService()
    private static let notificationsNotAllowedErrorCode = 1

    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published private(set) var errorMessage: String?

    private let center = UNUserNotificationCenter.current()
    private let preferences = AppPreferences.shared
    private var evaluator = UsageAlertEvaluator()

    private init() {}

    func refreshAuthorizationStatus() async {
        let settings = await center.notificationSettings()
        authorizationStatus = settings.authorizationStatus

        if settings.authorizationStatus == .denied,
           preferences.notificationsEnabled
        {
            preferences.notificationsEnabled = false
            evaluator.reset()
            errorMessage = "通知权限已关闭，请在系统设置中重新允许 QuotaBar 通知。"
        }
    }

    func setNotificationsEnabled(_ enabled: Bool) async {
        if !enabled {
            preferences.notificationsEnabled = false
            evaluator.reset()
            errorMessage = nil
            await refreshAuthorizationStatus()
            return
        }

        // Clear a previous denial message while macOS presents or evaluates the
        // authorization request. The preference remains false until authorization
        // succeeds, so the toggle cannot stay visually enabled after a failure.
        errorMessage = nil

        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound])
            preferences.notificationsEnabled = granted
            evaluator.reset()
            errorMessage = granted
                ? nil
                : "通知权限未开启，QuotaBar 不会发送额度提醒。"
            await refreshAuthorizationStatus()
        } catch {
            preferences.notificationsEnabled = false
            evaluator.reset()
            await refreshAuthorizationStatus()
            errorMessage = Self.authorizationErrorMessage(for: error)
        }
    }

    func process(snapshot: RateLimitSnapshot, isDemoMode: Bool) {
        guard preferences.notificationsEnabled, !isDemoMode else {
            evaluator.reset()
            return
        }

        let events = evaluator.evaluate(
            snapshot: snapshot,
            lowQuotaThreshold: preferences.lowQuotaThreshold,
            notifyOnReset: preferences.notifyOnReset
        )

        for event in events {
            let content = UNMutableNotificationContent()
            content.sound = .default

            switch event {
            case let .lowQuota(windowLabel, remainingPercent, resetsAt):
                content.title = "Codex \(windowLabel)偏低"
                content.body = "剩余 \(remainingPercent)%，将在 \(Self.timeString(resetsAt)) 重置。"
            case let .quotaReset(windowLabel, remainingPercent):
                content.title = "Codex \(windowLabel)已重置"
                content.body = "当前剩余 \(remainingPercent)%。"
            }

            let request = UNNotificationRequest(
                identifier: "quotabar-\(UUID().uuidString)",
                content: content,
                trigger: nil
            )
            center.add(request) { _ in }
        }
    }

    func resetBaseline() {
        evaluator.reset()
    }

    private static func timeString(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    private static func authorizationErrorMessage(for error: Error) -> String {
        let nsError = error as NSError
        if nsError.domain == UNErrorDomain,
           nsError.code == notificationsNotAllowedErrorCode
        {
            return "macOS 当前未允许 QuotaBar 请求通知权限。请打开系统通知设置，允许 QuotaBar 通知后再试。"
        }

        return "无法启用系统通知。请打开系统通知设置，允许 QuotaBar 通知后再试。"
    }
}

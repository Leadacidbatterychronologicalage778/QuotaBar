import AppKit
import Foundation
import QuotaBarCore

@MainActor
final class AppModel: ObservableObject {
    static let shared = AppModel()

    enum Phase: Equatable {
        case connecting
        case needsLogin
        case loggingIn
        case loadingUsage
        case ready
        case failed
    }

    @Published private(set) var phase: Phase = .connecting
    @Published private(set) var account: CodexAccount = .signedOut
    @Published private(set) var snapshot: RateLimitSnapshot?
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var isDemoMode = false
    @Published var errorMessage: String?

    private var client: CodexAppServerClient?
    private var pollTask: Task<Void, Never>?
    private var hasStarted = false

    var headlineRemaining: Double? {
        snapshot?.headlineWindow?.remainingPercent
    }

    var planLabel: String {
        (snapshot?.planType ?? account.planType ?? "ChatGPT").uppercased()
    }

    deinit {
        pollTask?.cancel()
        client?.stop()
    }

    func start() async {
        guard !hasStarted else { return }
        hasStarted = true

        await activate()
    }

    func activate() async {
        do {
            let activeClient: CodexAppServerClient

            if let client {
                activeClient = client
            } else {
                phase = .connecting
                let newClient = CodexAppServerClient()
                newClient.onNotification = { [weak self] method, params in
                    Task { @MainActor [weak self] in
                        self?.handleNotification(method: method, params: params)
                    }
                }
                try await newClient.start()
                client = newClient
                activeClient = newClient
            }

            account = try await activeClient.readAccount()

            guard account.isAuthenticated else {
                phase = .needsLogin
                return
            }

            await refresh()
            startPolling()
        } catch {
            present(error)
        }
    }

    func beginLogin() async {
        errorMessage = nil
        isDemoMode = false
        snapshot = nil

        do {
            if client == nil {
                await activate()
            }
            guard let client else {
                throw CodexClientError.serverNotRunning
            }

            phase = .loggingIn
            let loginURL = try await client.beginChatGPTLogin()
            NSWorkspace.shared.open(loginURL)
        } catch {
            present(error)
        }
    }

    func refresh() async {
        guard let client else { return }
        guard !isDemoMode else { return }

        phase = snapshot == nil ? .loadingUsage : .ready
        errorMessage = nil

        do {
            if !account.isAuthenticated {
                account = try await client.readAccount()
            }

            guard account.isAuthenticated else {
                phase = .needsLogin
                return
            }

            snapshot = try await client.readRateLimits()
            lastUpdated = Date()
            phase = .ready
        } catch {
            present(error)
        }
    }

    func openUsageDashboard() {
        guard let url = URL(string: "https://chatgpt.com/codex/settings/usage") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    func enterDemoMode() {
        let now = Date()
        let fiveHour = RateLimitWindow(
            usedPercent: 37,
            windowDurationMinutes: 300,
            resetsAt: now.addingTimeInterval(2 * 60 * 60 + 18 * 60)
        )
        let weekly = RateLimitWindow(
            usedPercent: 61,
            windowDurationMinutes: 10_080,
            resetsAt: now.addingTimeInterval(3 * 24 * 60 * 60 + 7 * 60 * 60)
        )
        let bucket = RateLimitBucket(
            id: "codex",
            name: nil,
            planType: "plus",
            primary: fiveHour,
            secondary: weekly,
            reachedType: nil
        )

        isDemoMode = true
        account = .signedOut
        snapshot = RateLimitSnapshot(buckets: [bucket], fetchedAt: now)
        lastUpdated = now
        errorMessage = nil
        phase = .ready
    }

    func connectRealAccountFromDemo() async {
        isDemoMode = false
        snapshot = nil
        await beginLogin()
    }

    func logout() async {
        guard let client else { return }

        do {
            try await client.logout()
            pollTask?.cancel()
            pollTask = nil
            isDemoMode = false
            snapshot = nil
            lastUpdated = nil
            account = .signedOut
            phase = .needsLogin
        } catch {
            present(error)
        }
    }

    private func startPolling() {
        guard pollTask == nil else { return }

        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                guard !Task.isCancelled else { break }
                await self?.refresh()
            }
        }
    }

    private func handleNotification(method: String, params: JSONValue) {
        switch method {
        case "account/login/completed":
            if params["success"]?.boolValue == true {
                Task { [weak self] in
                    guard let self, let client = self.client else { return }
                    do {
                        self.account = try await client.readAccount()
                        await self.refresh()
                        self.startPolling()
                    } catch {
                        self.present(error)
                    }
                }
            } else {
                let message = params["error"]?.stringValue ?? "ChatGPT 登录未完成。"
                errorMessage = message
                phase = .needsLogin
            }
        case "account/updated":
            Task { [weak self] in
                guard let self, let client = self.client else { return }
                do {
                    self.account = try await client.readAccount()
                    if self.account.isAuthenticated {
                        await self.refresh()
                    } else {
                        self.phase = .needsLogin
                    }
                } catch {
                    self.present(error)
                }
            }
        case "account/rateLimits/updated":
            Task { [weak self] in
                await self?.refresh()
            }
        default:
            break
        }
    }

    private func present(_ error: Error) {
        errorMessage = error.localizedDescription
        phase = .failed
    }
}

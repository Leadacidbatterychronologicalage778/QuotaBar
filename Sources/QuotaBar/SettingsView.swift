import AppKit
import ServiceManagement
import SwiftUI

@MainActor
final class LaunchAtLoginManager: ObservableObject {
    @Published var isEnabled = SMAppService.mainApp.status == .enabled
    @Published var errorMessage: String?

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            isEnabled = SMAppService.mainApp.status == .enabled
            errorMessage = nil
        } catch {
            isEnabled = SMAppService.mainApp.status == .enabled
            errorMessage = error.localizedDescription
        }
    }
}

struct SettingsView: View {
    @StateObject private var launchAtLogin = LaunchAtLoginManager()
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Form {
            Section("通用") {
                Toggle(
                    "登录 Mac 后自动启动",
                    isOn: Binding(
                        get: { launchAtLogin.isEnabled },
                        set: { launchAtLogin.setEnabled($0) }
                    )
                )

                if let errorMessage = launchAtLogin.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section("隐私") {
                Text("QuotaBar 不包含广告或分析 SDK，不会把你的 ChatGPT 登录信息或用量数据发送给开发者。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("支持开发") {
                Text("QuotaBar 永久免费。赞助完全自愿，不会解锁或限制任何功能。")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button {
                    openWindow(id: "sponsor")
                } label: {
                    Label("查看赞助二维码", systemImage: "heart")
                }
            }

            Section("关于") {
                Text("QuotaBar 不是 OpenAI 官方产品，也不受 OpenAI 赞助或认可。Codex 与 ChatGPT 是其各自权利人的商标。")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack {
                    Button {
                        openURL("https://github.com/RoketrP/QuotaBar/releases/latest")
                    } label: {
                        Label("检查新版本", systemImage: "arrow.up.right.square")
                    }

                    Button {
                        openURL("https://github.com/RoketrP/QuotaBar/issues")
                    } label: {
                        Label("反馈问题", systemImage: "exclamationmark.bubble")
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 460, height: 430)
        .navigationTitle("QuotaBar 设置")
    }

    private func openURL(_ address: String) {
        guard let url = URL(string: address) else { return }
        NSWorkspace.shared.open(url)
    }
}

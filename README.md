# QuotaBar

[![macOS](https://img.shields.io/badge/macOS-14%2B-111111?logo=apple)](https://github.com/RoketrP/QuotaBar/releases/latest)
[![Apple Silicon](https://img.shields.io/badge/Apple%20Silicon-arm64-0b9b68)](https://github.com/RoketrP/QuotaBar/releases/latest)
[![CI](https://github.com/RoketrP/QuotaBar/actions/workflows/ci.yml/badge.svg)](https://github.com/RoketrP/QuotaBar/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

QuotaBar 是一款原生 macOS 菜单栏 App，用来实时显示 Codex 剩余用量、额度窗口和重置倒计时。它永久免费，不包含广告或分析 SDK，也不会把登录信息和用量数据发送给开发者。

![QuotaBar 实时用量界面](docs/assets/quotabar-dashboard.png)

## 功能

- 在菜单栏显示 Codex 剩余百分比
- 展示 5 小时、周额度及其他额度窗口
- 显示重置倒计时，每 60 秒自动刷新
- 使用 Codex 官方 ChatGPT 登录流程
- 支持演示模式、手动刷新、退出账户和开机启动
- 内置固定版本的 Codex 本机服务
- 永久免费，赞助完全自愿

## 下载与安装

1. 从 [Releases](https://github.com/RoketrP/QuotaBar/releases/latest) 下载 `QuotaBar-v1.0.0-macOS-arm64.zip`。
2. 解压后把 `QuotaBar.app` 拖入“应用程序”文件夹。
3. 首次启动时按住 Control 点击 App，选择“打开”，再在系统提示中确认“打开”。

当前版本支持 macOS 14 或更高版本，以及 Apple 芯片 Mac。由于本项目没有 Apple Developer Program 证书，GitHub 下载版采用临时签名且未经过 Apple 公证；这是首次打开需要额外确认的原因。

发布页同时提供 SHA-256 文件，可用下面的命令核对下载内容：

```bash
shasum -a 256 -c QuotaBar-v1.0.0-macOS-arm64.zip.sha256
```

## 使用

1. 启动 QuotaBar。
2. 登录 ChatGPT，或先使用演示模式查看界面。
3. 点击菜单栏中的 QuotaBar 图标查看额度和重置时间。

QuotaBar 使用 Codex 官方 App Server 读取当前账户授权的额度，不读取浏览器 Cookie，也不要求用户向开发者提供密码或令牌。

## 自愿赞助

QuotaBar 的所有功能永久免费。赞助金额由你决定，不会解锁功能，也不会改变可用额度。

<table>
  <tr>
    <th>微信</th>
    <th>支付宝</th>
  </tr>
  <tr>
    <td><img src="docs/assets/sponsor-wechat.jpg" alt="微信收款码" width="280"></td>
    <td><img src="docs/assets/sponsor-alipay.jpg" alt="支付宝收款码" width="280"></td>
  </tr>
</table>

App 内也可通过“设置 → 查看赞助二维码”打开同一组收款码。

## 隐私

- 没有开发者后端、广告 SDK 或分析 SDK
- ChatGPT 登录凭证由 Codex 官方流程在本机处理
- 额度快照只保存在运行内存中
- 设置保存在 macOS 本地偏好中
- 收款码是静态图片，不会自动发起付款或采集信息

完整说明见 [隐私政策](https://roketrp.github.io/QuotaBar/privacy.html)。

## 从源码构建

要求：Xcode 16 或更高版本、macOS 14+、Swift 6，以及 `codex-cli 0.136.0`。

```bash
git clone https://github.com/RoketrP/QuotaBar.git
cd QuotaBar
npm install -g @openai/codex@0.136.0
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
./script/build_and_run.sh
```

生成可分发 ZIP：

```bash
CONFIGURATION=release scripts/package_app.sh
```

主要目录：

```text
QuotaBar.xcodeproj       Xcode 工程
Sources/QuotaBar         SwiftUI 菜单栏 App 与 Codex 客户端
Sources/QuotaBarCore     额度模型和 JSON 解析
Tests                    单元测试
docs                     GitHub Pages 帮助与隐私页面
scripts                  打包、图标和 Codex 嵌入脚本
```

## 反馈与安全

- Bug 与功能建议：[GitHub Issues](https://github.com/RoketrP/QuotaBar/issues)
- 安全问题：[Security Policy](SECURITY.md)
- 参与开发：[CONTRIBUTING.md](CONTRIBUTING.md)

提交问题时请勿上传密码、ChatGPT 登录令牌、Cookie 或其他敏感信息。

## 第三方组件与商标

发行包内嵌 Apache-2.0 许可的 OpenAI Codex CLI `0.136.0`，许可文本与声明保存在 `Sources/QuotaBar/Resources/Legal`。

QuotaBar 是独立第三方项目，不是 OpenAI 官方产品，也不受 OpenAI 赞助或认可。Codex、ChatGPT 和 OpenAI 是其各自权利人的商标。

## License

QuotaBar 源码采用 [MIT License](LICENSE)。第三方组件仍适用各自许可证。

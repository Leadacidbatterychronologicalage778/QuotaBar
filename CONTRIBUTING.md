# 参与 QuotaBar

感谢你帮助改进 QuotaBar。

## 开始之前

- Bug 和功能建议先在 GitHub Issues 中确认是否已有记录。
- 不要在 Issue、日志或截图中提交 ChatGPT 登录令牌、Cookie、密码或其他敏感信息。
- 大型改动请先创建 Issue 说明用途和交互方案。

## 本地验证

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project QuotaBar.xcodeproj \
  -scheme QuotaBar \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO test
```

提交代码前请确认 App 能启动，并验证登录、演示、刷新和设置窗口。

## Pull Request

- 一个 PR 只解决一个清晰问题。
- 说明行为变化和验证方式。
- UI 变化请附 macOS 截图。
- 新增第三方依赖时说明许可证和必要性。

# 项目协作约定

- 新增或修改的代码注释、README、开发说明与脚本提示使用简体中文。
- 界面继续支持中英文。
- 仅支持 Apple Silicon（arm64），最低运行版本 macOS 14；使用 Xcode 27、Swift 最新 编译器和 Swift 6 语言模式。
- 不兼容旧版项目的数据格式、偏好设置或登录项，不添加旧版迁移分支。
- 优先使用 SwiftUI
- 修改配置或快捷键逻辑后运行 `swift test`，必要时运行 `Scripts/check-native-shortcuts.sh`。
- 系统集成测试优先使用 `--preview` 隔离实例，不修改用户的真实配置或登录启动设置。

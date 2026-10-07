# BetterOpen 隐私政策

BetterOpen 在本机提供Finder 右键打开、应用启动、切换、隐藏与全局快捷键功能，无需注册账号。

## 本地数据

BetterOpen 保存用户选择的应用路径、显示名称、Finder 操作选择、快捷键和应用设置，用于显示应用列表与响应快捷键。应用绑定保存在 `~/Library/Application Support/BetterOpen/configuration.json`，偏好设置由 macOS 保存在 BetterOpen 的独立域中。这些配置不会由 BetterOpen 上传。开发版使用独立的 `BetterOpen Dev` 配置目录和 `io.github.awkj.BetterOpen.dev` 偏好设置域。

独立 Finder 配置保存在 `~/Library/Application Support/BetterOpen/finder-settings.json`，菜单快照保存在`~/Library/Application Support/BetterOpen/FinderMenu/configuration.json` 中，供本机 Finder 扩展读取。选中的文件与目录路径只在打开时传给 BetterOpen 和目标应用，不保存历史记录、不上传。目标应用如何处理打开的内容，取决于该应用自身。

导入、导出由用户主动发起，文件保存到用户选择的位置。请妥善保管导出的配置文件，其中可能包含本机应用路径。

## 系统功能

BetterOpen 使用 macOS 的快捷键注册与应用管理功能处理启动、切换及隐藏操作，不记录用户输入的文本。开启登录启动时，由 macOS 的登录项服务管理授权与启动状态。

Ghostty、iTerm 的指定窗口或标签页方式使用 macOS 自动化权限，仅在所选终端中创建会话并定位到用户选择的目录。用户可在系统设置中管理该权限。其他应用优先通过自身命令行接口或系统打开接口处理。

## 网络访问

当前代码未集成广告、使用行为分析或遥测服务。

配置了更新源后，Sparkle 更新组件会访问该更新源，并在更新过程中访问对应的下载服务器。服务器可能接收到正常网络请求包含的 IP 地址等信息；具体处理方式由所配置服务的运营方决定。默认构建未配置更新源。

点击菜单中的隐私政策链接时，系统浏览器会打开 GitHub 页面，该访问适用 GitHub 的隐私政策。

## 数据管理

用户可以在界面中移除应用绑定。卸载应用不会自动删除本地配置；如需彻底清除，请删除 BetterOpen 的配置目录与偏好设置。BetterOpen 不读取或迁移原版项目的配置、偏好设置或登录项。

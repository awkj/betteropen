# BetterOpen

<img src="Design/Icon.png" width="128" alt="BetterOpen 图标">

从 Finder 右键菜单打开文件、文件夹，或用全局快捷键快速启动、切换和隐藏 macOS 应用。BetterOpen 使用 SwiftUI 界面，拥有独立的应用标识、配置目录与更新源。

## Finder 右键打开

界面分为 **应用快捷键**、**Finder 扩展** 和 **应用设置** 三个标签页。快捷键页底部提供启用总开关，用于添加应用和录制热键；不设置快捷键就不会注册。应用设置统一提供外观、语言、登录启动、图标控制及快捷键配置的导入、导出。Finder 扩展的启停、授权状态与操作配置保留在 Finder 页。菜单栏仅显示三个页面入口、版本和退出；Finder 扩展页仅提供三个操作，配置与快捷键应用列表相互独立：

- **复制路径**：复制选中的文件或目录的完整路径，多选时每行一个路径。
- **默认编辑器**：下拉选择自动检测到的已安装编辑器，打开选中的文件或目录。
- **默认终端**：下拉选择自动检测到的已安装终端；选中文件时打开其所在目录，同一目录只打开一次。

首次运行自动选择检测到的编辑器与终端；选择 **关闭** 可以隐藏对应菜单。复制路径使用开关控制。应用通过 Launch Services 检测，支持用户目录和非标准安装位置；返回应用或点击 **刷新应用** 时重新检测。已保存但卸载的应用会标记为未安装，不自动替换用户的选择。

终端支持 Ghostty、Otty、iTerm2、系统 Terminal、WezTerm、Alacritty 和 kitty。编辑器支持 VS Code、Cursor、Zed、Sublime Text、BBEdit、CotEditor、Nova、TextMate、Typora、Xcode、TextEdit 等。Otty 使用应用包内的 `otty-cli open`，无需安装全局命令或设置脚本。

点击 **启用 Finder 扩展…** 打开系统扩展管理，再由用户启用 BetterOpen。右键文件夹打开该目录，右键空白处使用当前目录。菜单最多显示复制路径、一个编辑器和一个终端。

Finder 配置保存在 `~/Library/Application Support/BetterOpen/finder-settings.json`，版本为 1。Finder 扩展只读取 `~/Library/Application Support/BetterOpen/FinderMenu/configuration.json` 菜单快照，复制路径直接由扩展完成，不切换应用；编辑器与终端操作通过 BetterOpen 的 URL 协议传递操作类型与路径。主应用重新检查操作是否启用、路径是否存在、应用标识是否一致。编辑器与终端分别提供打开方式选择器，选项根据应用能力显示。Otty、WezTerm、iTerm 支持新窗口和新标签页；Ghostty 的脚本方式要求 1.3 或更新版本；VS Code 和 Sublime Text 支持新窗口和当前窗口。不提供指定打开接口的应用仅使用系统打开功能。打开方式直接显示在所选应用下方，默认优先使用标签页，VS Code、Sublime Text 默认使用当前窗口。选择 Otty 标签页时优先复用现有窗口，无窗口时先打开首个窗口，多选目录随后分别打开标签页。CLI 路径作为独立参数传递；iTerm 的目录切换由 AppleScript 使用 quoted form 安全转义。Ghostty、iTerm 的指定打开方式需要 macOS 自动化授权。打开方式保存在本版本的偏好设置中，不改变目标应用的全局设置。共享菜单写入失败会提示，重新打开主应用时重试。

`just dev` 使用独立的开发版配置，可验证真实 Finder 菜单；正式产物的 `--preview` 使用临时配置，不发布共享菜单、不响应真实 Finder 请求。扩展管理按钮打开系统设置，由用户启用对应版本的扩展。本地构建脚本会添加临时签名，公开版本使用临时签名，不含开发者证书签名与公证。

## 品牌与图标

Dock 图标采用白色圆角底板、钴蓝色球体与纯白色（`#FFFFFF`）双眼。球面通过左上方的宽范围柔光渐变（`#7DAAFF` 经主色 `#497DE0` 至 `#315FC2`）表现体积感，双眼略高于中心。Dock、菜单栏与 SVG 共用球体轮廓和双眼垂直位置；菜单栏放大双眼并增加 1 点的眼间留白，补偿小尺寸显示的识别度。菜单栏不含白色底板，使用背景透明的单色镂空模板，自动适配系统明暗外观。

`Design/Icon.svg` 是可编辑的矢量图，`Design/Icon.png` 是 1024 像素预览。修改 `Scripts/generate-icons.swift` 后，在仓库根目录运行以下命令，统一生成矢量图、预览图、全部 macOS 图标尺寸与菜单栏图标：

```sh
swift Scripts/generate-icons.swift
```

## 开发环境与兼容范围

- **仅支持 Apple Silicon（arm64）**，最低运行版本 **macOS 14**。
- Xcode 27、Swift 6.4 编译器与 macOS 27 SDK。
- Swift 6 语言模式，启用严格并发检查、主执行器默认隔离和易用并发配置。
- 使用 Swift Package Manager 管理依赖。
- 不兼容旧版项目的配置格式、导出文件、偏好设置或登录项。

`Build.xcconfig` 统一设置架构与最低运行版本。`SDKROOT = macosx` 使用当前 Xcode 提供的 SDK；编译 SDK 与最低运行版本相互独立。使用新工具链构建，同时支持 macOS 14 至当前系统。

## 当前技术栈

- **SwiftUI**：应用列表、设置页面和 `MenuBarExtra` 菜单栏；提供隔离的 `#Preview` Canvas 预览。
- **Observation**：`@Observable` 管理状态，`@Bindable` 提供界面绑定。
- **Swift 并发**：界面与系统回调隔离到 `MainActor`；配置记录、快捷键和状态机显式声明为 `nonisolated`；恢复计时使用 `Task.sleep(for:)`。
- **ServiceManagement**：通过 `SMAppService` 管理登录启动与授权状态。
- **字符串目录**：通过 `Localizable.xcstrings` 管理中英文界面。
- **Codable 与原子写入**：使用带版本标识的结构化配置，快捷键直接保存系统键码与修饰键位图。
- **Swift Testing**：验证配置校验、失败处理和快捷键状态。
- **KeyboardShortcuts 3.1.0**：全局快捷键与 SwiftUI 录制控件。
- **Sparkle 2.10.0**：支持自己的自动更新源；默认尚未配置更新地址和验证公钥。

`AppState` 连接界面状态与各项服务，`ApplicationStore` 管理应用绑定，`GlobalShortcutService` 管理热键，`ApplicationService` 通过 `NSWorkspace` 和 `NSRunningApplication` 启动、切换与隐藏应用。配置窗口由 AppKit 按需创建，内容使用 SwiftUI，登录启动时不会自动弹出窗口。

## 构建与验证

工程与源码目录使用小写 `betteropen`，应用品牌与产物名保留 `BetterOpen`。

打开 `betteropen.xcodeproj` 或现有工作区，选择共享的 **betteropen** 构建方案。本地开发使用临时签名；准备分发时使用自己的开发者团队。

终端开发使用 `just` 和 Python 3（监听脚本仅使用标准库）。在仓库根目录构建并启动 Debug 开发版：

```sh
just dev
```

`just dev` 持续在终端前台运行，自动传入 `--preview`，使用独立的开发版配置，注册全局快捷键、不修改登录项。保存 Swift 源码、资源、字符串目录或 Xcode 项目配置后，脚本自动停止本会话的应用，增量构建并重新打开主窗口。连续保存会合并处理；构建失败会显示诊断，修正并保存后自动重试。应用自行退出后仍继续监听，可保存源码重新启动。

这是自动构建并重启，不是在原进程内注入 Swift 代码；已保存的开发版配置会保留，窗口中的临时状态会重置。只调试 SwiftUI 局部界面时，也可以使用 Xcode 的 `#Preview` Canvas。

在运行命令的终端按 **Ctrl+C** 可停止监听、正在进行的构建及本会话启动的应用，并清理快捷键；关闭终端也会结束会话。`Ctrl+D` 仅表示标准输入结束，不用于退出应用。Dock 图标遵循应用设置。同一构建目录只能运行一个开发会话。

只构建启动一次、关闭自动监听：

```sh
just dev --no-watch
```

`just dev` 和 `just build` 默认只显示阶段提示，完整构建输出保存在 `.build-release/build.log`，开发版运行日志保存在 `.build-release/dev.log`。需要排错时可显示详细输出：

```sh
just dev --verbose
BETTEROPEN_VERBOSE=1 just build
```

构建 arm64 Release 版本并打包为 DMG：

```sh
just build
```

产物位置（本地构建，不包含分发签名与公证）：

```text
.build-release/DerivedData/Build/Products/Release/BetterOpen.app
.build-release/BetterOpen-1.0.0-arm64.dmg
.build-release/BetterOpen-1.0.0-arm64.dmg.sha256
```

`BETTEROPEN_BUILD_DIR` 可以覆盖默认产物目录。只需构建 Release 而不打包时，仍可运行 `./build.sh build`。

核心测试：

```sh
swift test --arch arm64
```

开发会话回归测试（临时工程，验证保存后重启、构建失败后恢复及 Ctrl+C 清理）：

```sh
python3 -B -m unittest discover -s Tests/Development -v
```

隔离验证 Finder 菜单快照、终端参数、特殊路径、多选去重及错误处理（只使用临时配置与模拟终端）：

```sh
./Scripts/check-finder-opening.sh
```

在已登录图形桌面的 Mac 上检查原生热键的注册、编辑、清除与退出清理：

```sh
./Scripts/check-native-shortcuts.sh
```

此检查会短暂注册测试热键，包括已释放的原菜单栏组合。如果另一份 BetterOpen 正在占用同一快捷键，可能产生冲突；退出正在运行的 BetterOpen 后再执行。

准备分发归档：

```sh
BETTEROPEN_TEAM_ID=你的开发者团队标识 ./build.sh archive
```

分发前在 Xcode Organizer 中导出并公证归档。本地脚本不会发布版本或更新列表。启用自动更新时，在 `Build.xcconfig` 配置自己的 `BETTEROPEN_UPDATE_FEED_URL` 与 `BETTEROPEN_UPDATE_PUBLIC_KEY`。

## 配置行为

配置保存在：

```text
~/Library/Application Support/BetterOpen/configuration.json
```

当前格式版本为 **2**，不读取版本 1 或其他旧格式。文件包含 `version` 和 `applications`。每条应用绑定包含 UUID、应用路径、显示名称及可选快捷键；快捷键包含 `keyCode` 和 `modifiers`。版本字段用于拒绝未知格式，不执行历史迁移。

首次运行使用新的空应用列表和默认设置。旧版 `apps.json` 和旧偏好设置不会读取，也不会删除。新格式的导入、导出保持可用。未录制快捷键的应用会保留，找不到的应用仍显示在列表中。

所有编辑先校验并原子保存，再更新内存和热键注册。保存或导入失败时保留当前状态；无法读取的当前配置文件在成功替换前会自动备份。

应用快捷键页底部提供「启用应用快捷键」总开关，默认开启。关闭后立即注销全部应用热键并保留已录制的配置，重新开启后恢复注册；开关状态在重启后保留。停用期间编辑或导入配置不会重新启用热键。

应用设置的「应用图标」组统一提供菜单栏与 Dock 图标的显示开关。macOS 26 及以上还提供说明和系统设置入口，可前往「系统设置 > 菜单栏 > 允许在菜单栏中显示」管理 BetterOpen；应用内的显示设置也受系统许可影响。不再提供菜单栏图标专用快捷键。两个图标均隐藏时，可从访达或聚焦重新打开应用设置。

## 开发版、正式版与隔离预览

| 项目 | 正式版（Release） | 开发版（Debug） |
| --- | --- | --- |
| 应用名 | BetterOpen | BetterOpen Dev |
| Bundle ID | `io.github.awkj.BetterOpen` | `io.github.awkj.BetterOpen.dev` |
| Finder 扩展 ID | `io.github.awkj.BetterOpen.Finder` | `io.github.awkj.BetterOpen.dev.Finder` |
| URL 协议 | `betteropen` | `betteropen-dev` |
| 配置目录 | `~/Library/Application Support/BetterOpen/` | `~/Library/Application Support/BetterOpen Dev/` |

`just dev` 构建并在前台启动开发版，保存源码后自动构建重启，按 Ctrl+C 停止；`just build` 打包正式版。直接使用 Xcode 的 Debug 配置也采用开发版身份。两个版本的偏好设置、Finder 菜单与登录项身份相互独立，不迁移旧标识的数据。开发版窗口显示「BetterOpen 开发版」，系统扩展列表按应用显示「BetterOpen Dev」。

开发版可以保存并测试自己的 Finder 配置和全局热键，不修改登录项、不检查更新。开发版热键使用独立配置，但仍会占用系统按键组合，测试时避免与正式版绑定相同热键。在系统设置的 Finder 扩展中启用对应版本即可测试菜单；同时启用两个版本会分别显示两套菜单。Finder 扩展页提供启用总开关，关闭后隐藏全部菜单项并拒绝打开请求，保留编辑器、终端和复制路径的选择；重新开启后恢复。页面通过系统接口显示当前版本的扩展是否已启用，进入页面或从其他应用返回时自动检测应用与扩展状态；菜单快照写入失败会单独显示错误与「重试」按钮。

正式产物传入 `--preview` 时使用临时 JSON 和独立预览偏好设置，每次生成示例应用列表，不发布 Finder 菜单，也不注册全局热键、修改登录项或检查更新。

```sh
open -n .build-release/DerivedData/Build/Products/Release/BetterOpen.app --args --preview
```

自动测试覆盖当前格式读写、旧格式拒绝、原子保存、编辑与导入失败、状态更新回调、快捷键校验和修饰键双击。macOS 14 真机、登录启动授权、分发签名、公证和真实更新流程仍需对应环境验证。

## 后续可升级内容

在保留 macOS 14 的前提下，可以继续完善：

- 使用 SwiftUI 窗口场景接管按需窗口生命周期，保持登录启动不弹窗的行为。
- 在支持的系统上采用 Liquid Glass 等新界面 API，在 macOS 14 使用原生样式。
- 配置规模增长时，用独立 actor 管理文件读写，维持保存成功后才提交状态的事务语义。
- 出现复杂查询、关系模型或同步需求时，再评估 SwiftData。
- 增加界面自动化测试、macOS 14 验证和自动签名发布流水线。

## 来源与致谢

BetterOpen 基于 [Thor](https://github.com/gbammc/Thor) 改造。原项目的版权声明保留在许可证中。

`Design/Legacy` 下的 Sketch 文件仅为原项目设计归档，不属于 BetterOpen 发布产物。`Releases/appcast.xml` 是 BetterOpen 的空更新列表，正式发布时需要填入自己的版本、下载地址和签名，并配置更新源与验证公钥。

原版界面灵感来自 [Pomodoro One](http://rinik.net/pomodoro/)，历史快捷键实现使用了 [MASShortcut](https://github.com/shpakovski/MASShortcut)。

## 许可证

采用 MIT 许可证。版权声明与完整许可原文保留在 [LICENSE](LICENSE)。

## GitHub 自动发布

推送 `v主版本.次版本.修订版本` 标签（例如 `v1.0.0`）后，GitHub Actions 使用 Xcode 27 构建、运行核心测试、生成 DMG 和 SHA-256 校验文件，并创建 GitHub Release。标签版本必须与工程中的 `MARKETING_VERSION` 一致；后续发布前同步修改主应用和 Finder 扩展的版本与构建号。

发布包仅支持 Apple Silicon 和 macOS 14 及以上，使用临时签名，没有 Developer ID 签名或 Apple 公证。首次打开可能被系统拦截；确认下载来源后，可在「系统设置 > 隐私与安全性」中允许打开。GitHub Release 不会自动配置 Sparkle 更新源。

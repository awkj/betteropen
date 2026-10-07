# 查看可用命令。
default:
    @just --list

# 前台启动开发版，保存源码后自动构建重启，按 Ctrl+C 停止。
dev *args:
    @./build.sh dev {{args}}

# 构建 arm64 Release 版本并打包为 DMG。
build:
    @./build.sh package

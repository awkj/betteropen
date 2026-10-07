#!/usr/bin/env bash
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CHECK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/betteropen-finder-check.XXXXXX")"
trap 'rm -rf "$CHECK_DIR"' EXIT
# 全部菜单数据与模拟终端位于临时目录，不接触用户配置或真实应用。
swiftc -swift-version 6 -target arm64-apple-macos14 \
  "$REPO_ROOT/betteropen/Core/Hotkey.swift" \
  "$REPO_ROOT/betteropen/Core/ConfigurationStore.swift" \
  "$REPO_ROOT/betteropen/Core/FinderOpening.swift" \
  "$REPO_ROOT/betteropen/Core/FinderConfiguration.swift" \
  "$REPO_ROOT/betteropen/FinderOpeningService.swift" \
  "$REPO_ROOT/Tests/FinderChecks/Check.swift" -o "$CHECK_DIR/check"
"$CHECK_DIR/check" "$CHECK_DIR"

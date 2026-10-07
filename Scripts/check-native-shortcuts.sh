#!/usr/bin/env bash
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CHECK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/betteropen-native-check.XXXXXX")"
trap 'rm -rf "$CHECK_DIR"' EXIT
mkdir -p "$CHECK_DIR/Sources/NativeCheck"
cp "$REPO_ROOT"/betteropen/Core/*.swift "$REPO_ROOT/betteropen/ApplicationService.swift" \
  "$REPO_ROOT/betteropen/GlobalShortcutService.swift" "$REPO_ROOT/Tests/NativeChecks/Check.swift" \
  "$CHECK_DIR/Sources/NativeCheck/"
cat > "$CHECK_DIR/Package.swift" <<'SWIFT'
// swift-tools-version: 6.4
import PackageDescription
let package = Package(name: "NativeCheck", platforms: [.macOS(.v14)],
    dependencies: [.package(url: "https://github.com/sindresorhus/KeyboardShortcuts", exact: "3.1.0")],
    targets: [.executableTarget(name: "NativeCheck", dependencies: [.product(name: "KeyboardShortcuts", package: "KeyboardShortcuts")])])
SWIFT
swift run --arch arm64 --package-path "$CHECK_DIR"

#!/usr/bin/env bash
set -euo pipefail

# 仅构建 Apple Silicon 应用，最低系统版本由 Build.xcconfig 指定。
# 准备签名分发时，通过 BETTEROPEN_TEAM_ID 指定自己的开发者团队。
# 本地构建不需要分发签名，也不会发布更新列表。
cd "$(dirname "$0")"
PROJECT_NAME="betteropen"
APP_NAME="BetterOpen"
BUILD_DIR="${BETTEROPEN_BUILD_DIR:-$PWD/.build-release}"
BUILD_MODE="${1:-build}"
mkdir -p "$BUILD_DIR"
BUILD_DIR="$(cd "$BUILD_DIR" && pwd)"
BUILD_LOG="$BUILD_DIR/build.log"
ARCHIVE_PATH="$BUILD_DIR/$APP_NAME.xcarchive"

# 日常只显示阶段提示，完整工具输出保留在日志中；失败时直接显示诊断。
run_logged() {
  if [[ "${BETTEROPEN_VERBOSE:-0}" == "1" ]]; then
    "$@" 2>&1 | tee "$BUILD_LOG"
  elif "$@" >"$BUILD_LOG" 2>&1; then
    echo "构建完成。"
  else
    local status=$?
    cat "$BUILD_LOG" >&2
    echo "构建失败，完整日志：$BUILD_LOG" >&2
    return "$status"
  fi
}

build_app() {
  xcodebuild -project "$PROJECT_NAME.xcodeproj" -scheme "$PROJECT_NAME" \
    -configuration "$1" -derivedDataPath "$BUILD_DIR/DerivedData" \
    ARCHS=arm64 ONLY_ACTIVE_ARCH=YES CODE_SIGNING_ALLOWED=NO build || return $?
  # Debug 与 Release 使用不同的应用名、标识和扩展沙盒权限。
  local product_name="$APP_NAME" extension_entitlements="betteropenfinder/betteropenfinder.entitlements"
  if [[ "$1" == "Debug" ]]; then
    product_name="BetterOpen Dev"
    extension_entitlements="betteropenfinder/betteropenfinder-dev.entitlements"
  fi
  local app_path="$BUILD_DIR/DerivedData/Build/Products/$1/$product_name.app"
  # Xcode 复制框架时可能剥离符号，重新签名并保留框架辅助进程原有权限。
  codesign --force --deep --sign - --preserve-metadata=entitlements \
    "$app_path/Contents/Frameworks/Sparkle.framework" || return $?
  codesign --force --sign - --entitlements "$extension_entitlements" \
    "$app_path/Contents/PlugIns/BetterOpenFinder.appex" || return $?
  codesign --force --sign - --entitlements betteropen/betteropen.entitlements "$app_path"
}

case "$BUILD_MODE" in
  dev)
    shift
    if ! command -v python3 >/dev/null 2>&1; then
      echo "开发监听需要 Python 3，请安装后重试。" >&2
      exit 1
    fi
    export BETTEROPEN_BUILD_DIR="$BUILD_DIR"
    exec python3 Scripts/dev.py "$@"
    ;;
  debug)
    echo "正在构建开发版…"
    run_logged build_app Debug
    ;;
  build)
    echo "正在构建正式版…"
    run_logged build_app Release
    ;;
  package)
    echo "正在构建正式版…"
    run_logged build_app Release
    APP_PATH="$BUILD_DIR/DerivedData/Build/Products/Release/$APP_NAME.app"
    VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_PATH/Contents/Info.plist")"
    if [[ -n "${BETTEROPEN_VERSION:-}" && "$VERSION" != "$BETTEROPEN_VERSION" ]]; then
      echo "标签版本与应用版本不一致：$BETTEROPEN_VERSION / $VERSION" >&2
      exit 1
    fi
    DMG_PATH="$BUILD_DIR/$APP_NAME-$VERSION-arm64.dmg"
    STAGING_DIR="$(mktemp -d "$BUILD_DIR/dmg.XXXXXX")"
    trap 'rm -rf "$STAGING_DIR"' EXIT
    ditto "$APP_PATH" "$STAGING_DIR/$APP_NAME.app"
    ln -s /Applications "$STAGING_DIR/Applications"
    echo "正在生成 DMG…"
    hdiutil create -volname "$APP_NAME" -srcfolder "$STAGING_DIR" \
      -format UDZO -ov "$DMG_PATH"
    (cd "$BUILD_DIR" && shasum -a 256 "$(basename "$DMG_PATH")" > "$(basename "$DMG_PATH").sha256")
    echo "应用路径： $APP_PATH"
    echo "打包路径： $DMG_PATH"
    ;;
  archive)
    if [[ -z "${BETTEROPEN_TEAM_ID:-}" ]]; then
      echo "归档前请通过 BETTEROPEN_TEAM_ID 指定自己的 Apple 开发者团队。" >&2
      exit 1
    fi
    echo "正在归档正式版…"
    run_logged xcodebuild -project "$PROJECT_NAME.xcodeproj" -scheme "$PROJECT_NAME" \
      -configuration Release -archivePath "$ARCHIVE_PATH" \
      ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
      DEVELOPMENT_TEAM="$BETTEROPEN_TEAM_ID" CODE_SIGN_IDENTITY='Developer ID Application' archive
    echo "归档路径： $ARCHIVE_PATH"
    echo "分发前请在 Xcode Organizer 中导出并公证此归档。"
    ;;
  *)
    echo "用法： $0 [dev [--no-watch] [--verbose]|debug|build|package|archive]" >&2
    exit 1
    ;;
esac

#!/bin/bash
# 构建「晨云待办」macOS 应用（arm64 原生）并打包 DMG 安装包
set -euo pipefail
cd "$(dirname "$0")"

echo "==> swift build (release)"
swift build -c release
BIN="$(swift build -c release --show-bin-path)"

APP="build/晨云待办.app"
rm -rf "$APP" "build/极简待办.app" # 同时清理旧名称的产物
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN/MinimalTodo" "$APP/Contents/MacOS/"
cp Resources/Info.plist "$APP/Contents/Info.plist"
if [ -f ../chenyun-todo/src-tauri/icons/icon.icns ]; then
    cp ../chenyun-todo/src-tauri/icons/icon.icns "$APP/Contents/Resources/AppIcon.icns"
fi
codesign --force -s - "$APP"
echo "构建完成: $(pwd)/$APP"

echo "==> 打包 DMG 安装包（拖入 Applications 即完成安装）"
DMGROOT="build/dmgroot"
rm -rf "$DMGROOT"
mkdir -p "$DMGROOT"
cp -R "$APP" "$DMGROOT/"
ln -s /Applications "$DMGROOT/Applications"
hdiutil create -volname "晨云待办" -srcfolder "$DMGROOT" -ov -format UDZO "build/晨云待办.dmg" > /dev/null
rm -rf "$DMGROOT"
echo "安装包: $(pwd)/build/晨云待办.dmg"

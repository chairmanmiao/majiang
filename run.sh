#!/bin/bash
set -e

VERSION="1.5.2"
APP_NAME="麻将"
DMG_NAME="麻将游戏-v${VERSION}-macOS"

echo "🀄 正在构建麻将游戏 v${VERSION}..."
cd "$(dirname "$0")"

# 1. 构建 Release
swift build -c release

# 2. 创建 .app Bundle
APP_DIR=".build/release/${APP_NAME}.app"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"
cp ".build/release/MahjongGame" "$APP_DIR/Contents/MacOS/"

# 3. 写入 Info.plist（版本号 1.6.0）
cat > "$APP_DIR/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>zh_CN</string>
    <key>CFBundleExecutable</key>
    <string>MahjongGame</string>
    <key>CFBundleIdentifier</key>
    <string>com.kimi.mahjong</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>160</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

# 4. 生成应用图标（如果尚未生成）
ICONSET_DIR=".build/iconset.iconset"
ICNS_PATH=".build/icon.icns"
if [ ! -f "$ICNS_PATH" ]; then
    echo "🎨 生成应用图标..."
    mkdir -p "$ICONSET_DIR"
    
    # 用 Swift 生成一张 1024x1024 的图标底图（深墨绿 + 麻将文字）
    swift - << 'SWIFT_EOF'
import AppKit
import CoreGraphics
import CoreText
import Foundation
import ImageIO

let size = CGSize(width: 1024, height: 1024)
let colorSpace = CGColorSpaceCreateDeviceRGB()
let context = CGContext(data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!

// 深墨绿背景
context.setFillColor(CGColor(red: 0.102, green: 0.278, blue: 0.165, alpha: 1.0))
context.fill(CGRect(origin: .zero, size: size))

// 圆角裁切
let path = CGPath(roundedRect: CGRect(origin: .zero, size: size), cornerWidth: 224, cornerHeight: 224, transform: nil)
context.addPath(path)
context.clip()

// 重新填充背景（裁切后）
context.setFillColor(CGColor(red: 0.102, green: 0.278, blue: 0.165, alpha: 1.0))
context.fill(CGRect(origin: .zero, size: size))

// 内圈渐变
let gradientColors = [CGColor(red: 0.13, green: 0.35, blue: 0.20, alpha: 1.0), CGColor(red: 0.08, green: 0.22, blue: 0.12, alpha: 1.0)] as CFArray
let gradient = CGGradient(colorsSpace: colorSpace, colors: gradientColors, locations: [0.0, 1.0])!
context.drawRadialGradient(gradient, startCenter: CGPoint(x: 512, y: 512), startRadius: 0, endCenter: CGPoint(x: 512, y: 512), endRadius: 600, options: .drawsBeforeStartLocation)

// 绘制 "麻" 字
let font = CTFontCreateWithName("PingFangSC-Semibold" as CFString, 480, nil)
let attrString = NSAttributedString(string: "麻", attributes: [
    .font: font,
    .foregroundColor: NSColor(red: 0.851, green: 0.129, blue: 0.129, alpha: 1.0)
])
let line = CTLineCreateWithAttributedString(attrString)
let bounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
context.textMatrix = CGAffineTransform(scaleX: 1.0, y: -1.0)
context.textPosition = CGPoint(x: 512 - bounds.width/2, y: 512 + bounds.height/2 - 40)
CTLineDraw(line, context)

// 保存
let image = context.makeImage()!
let url = URL(fileURLWithPath: ".build/icon_1024.png")
let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)!
CGImageDestinationAddImage(dest, image, nil)
CGImageDestinationFinalize(dest)
SWIFT_EOF

    # 用 sips 生成各种尺寸
    sips -z 16 16   .build/icon_1024.png --out "${ICONSET_DIR}/icon_16x16.png" >/dev/null 2>&1
    sips -z 32 32   .build/icon_1024.png --out "${ICONSET_DIR}/icon_16x16@2x.png" >/dev/null 2>&1
    sips -z 32 32   .build/icon_1024.png --out "${ICONSET_DIR}/icon_32x32.png" >/dev/null 2>&1
    sips -z 64 64   .build/icon_1024.png --out "${ICONSET_DIR}/icon_32x32@2x.png" >/dev/null 2>&1
    sips -z 128 128 .build/icon_1024.png --out "${ICONSET_DIR}/icon_128x128.png" >/dev/null 2>&1
    sips -z 256 256 .build/icon_1024.png --out "${ICONSET_DIR}/icon_128x128@2x.png" >/dev/null 2>&1
    sips -z 256 256 .build/icon_1024.png --out "${ICONSET_DIR}/icon_256x256.png" >/dev/null 2>&1
    sips -z 512 512 .build/icon_1024.png --out "${ICONSET_DIR}/icon_256x256@2x.png" >/dev/null 2>&1
    sips -z 512 512 .build/icon_1024.png --out "${ICONSET_DIR}/icon_512x512.png" >/dev/null 2>&1
    cp .build/icon_1024.png "${ICONSET_DIR}/icon_512x512@2x.png"
    
    iconutil -c icns "$ICONSET_DIR" -o "$ICNS_PATH"
    rm -rf "$ICONSET_DIR" .build/icon_1024.png
fi
cp "$ICNS_PATH" "$APP_DIR/Contents/Resources/AppIcon.icns"

# 5. 生成 DMG 背景图（如果尚未生成）
BG_PATH=".build/dmg_bg.png"
if [ ! -f "$BG_PATH" ]; then
    echo "🖼️ 生成 DMG 背景图..."
    mkdir -p ".build"
    swift - << 'SWIFT_EOF'
import AppKit
import CoreGraphics
import CoreText
import Foundation
import ImageIO

let size = CGSize(width: 800, height: 520)
let colorSpace = CGColorSpaceCreateDeviceRGB()
let context = CGContext(data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!

// 深墨绿背景
context.setFillColor(CGColor(red: 0.08, green: 0.20, blue: 0.12, alpha: 1.0))
context.fill(CGRect(origin: .zero, size: size))

//  subtle radial glow
let gradientColors = [CGColor(red: 0.12, green: 0.30, blue: 0.18, alpha: 1.0), CGColor(red: 0.06, green: 0.16, blue: 0.09, alpha: 1.0)] as CFArray
let gradient = CGGradient(colorsSpace: colorSpace, colors: gradientColors, locations: [0.0, 1.0])!
context.drawRadialGradient(gradient, startCenter: CGPoint(x: 400, y: 260), startRadius: 0, endCenter: CGPoint(x: 400, y: 260), endRadius: 500, options: .drawsBeforeStartLocation)

// 标题
let titleFont = CTFontCreateWithName("PingFangSC-Semibold" as CFString, 36, nil)
let titleAttr = NSAttributedString(string: "macOS 麻将", attributes: [
    .font: titleFont,
    .foregroundColor: NSColor(red: 0.722, green: 0.525, blue: 0.043, alpha: 1.0)
])
let titleLine = CTLineCreateWithAttributedString(titleAttr)
let titleBounds = CTLineGetBoundsWithOptions(titleLine, .useGlyphPathBounds)
context.textMatrix = CGAffineTransform(scaleX: 1.0, y: -1.0)
context.textPosition = CGPoint(x: 400 - titleBounds.width/2, y: 420)
CTLineDraw(titleLine, context)

// 提示文字
let hintFont = CTFontCreateWithName("PingFangSC-Regular" as CFString, 18, nil)
let hintAttr = NSAttributedString(string: "将应用拖拽到右侧 Applications 文件夹安装", attributes: [
    .font: hintFont,
    .foregroundColor: NSColor(white: 0.7, alpha: 0.8)
])
let hintLine = CTLineCreateWithAttributedString(hintAttr)
let hintBounds = CTLineGetBoundsWithOptions(hintLine, .useGlyphPathBounds)
context.textPosition = CGPoint(x: 400 - hintBounds.width/2, y: 380)
CTLineDraw(hintLine, context)

// 箭头
let arrowFont = CTFontCreateWithName("SFPro-Regular" as CFString, 48, nil)
let arrowAttr = NSAttributedString(string: "→", attributes: [
    .font: arrowFont,
    .foregroundColor: NSColor(white: 0.6, alpha: 0.5)
])
let arrowLine = CTLineCreateWithAttributedString(arrowAttr)
let arrowBounds = CTLineGetBoundsWithOptions(arrowLine, .useGlyphPathBounds)
context.textPosition = CGPoint(x: 400 - arrowBounds.width/2, y: 260)
CTLineDraw(arrowLine, context)

let image = context.makeImage()!
let url = URL(fileURLWithPath: ".build/dmg_bg.png")
let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)!
CGImageDestinationAddImage(dest, image, nil)
CGImageDestinationFinalize(dest)
SWIFT_EOF
fi

# 6. 创建 DMG
TMP_DMG="/tmp/mahjong_temp_${VERSION}.dmg"
FINAL_DMG="${DMG_NAME}.dmg"
VOLUME_NAME="macOS 麻将"

rm -f "$TMP_DMG" "$FINAL_DMG"

echo "📦 创建 DMG 安装包..."

# 创建临时 DMG
hdiutil create -size 20m -fs HFS+ -volname "$VOLUME_NAME" -o "$TMP_DMG" >/dev/null 2>&1

# 挂载（自动挂载到 /Volumes/）
MOUNT_OUTPUT=$(hdiutil attach "$TMP_DMG" -nobrowse 2>&1)
VOLUME_PATH=$(echo "$MOUNT_OUTPUT" | grep -o '/Volumes/.*' | head -1 | awk '{$1=$1};1')

if [ -z "$VOLUME_PATH" ]; then
    echo "❌ DMG 挂载失败"
    exit 1
fi

# 复制应用
cp -R "$APP_DIR" "$VOLUME_PATH/"

# 创建 Applications 快捷方式
ln -s /Applications "$VOLUME_PATH/Applications"

# 复制背景图
mkdir -p "$VOLUME_PATH/.background"
cp "$BG_PATH" "$VOLUME_PATH/.background/dmg_bg.png"

# 设置 Finder 窗口布局（AppleScript）
osascript << APPLESCRIPT
 tell application "Finder"
     delay 1
     tell disk "$VOLUME_NAME"
         open
         delay 1
         set current view of container window to icon view
         set toolbar visible of container window to false
         set statusbar visible of container window to false
         set bounds of container window to {100, 100, 900, 620}
         set viewOptions to icon view options of container window
         set arrangement of viewOptions to not arranged
         set icon size of viewOptions to 100
         set text size of viewOptions to 13
         set background picture of viewOptions to POSIX file "$VOLUME_PATH/.background/dmg_bg.png"
         set position of item "${APP_NAME}.app" of container window to {220, 260}
         set position of item "Applications" of container window to {580, 260}
         delay 1
     end tell
 end tell
APPLESCRIPT

# 卸载
hdiutil detach "$VOLUME_PATH" -force >/dev/null 2>&1

# 压缩为最终 DMG
hdiutil convert "$TMP_DMG" -format UDZO -o "$FINAL_DMG" >/dev/null 2>&1

# 清理
rm -f "$TMP_DMG"

echo "✅ 打包完成: ${FINAL_DMG}"
echo "🚀 启动应用..."
open "$APP_DIR"

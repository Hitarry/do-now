#!/bin/bash
cd "$(dirname "$0")"
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer

echo "=== 生成 Xcode 项目 ==="
rm -rf "Do Now.xcodeproj"
xcodegen generate

echo ""
echo "=== 编译 ==="
xcodebuild -project "Do Now.xcodeproj" -scheme "Do Now" -configuration Debug build

if [ $? -eq 0 ]; then
    echo ""
    echo "=== 编译成功 ==="
    BUILD_DIR=$(xcodebuild -project "Do Now.xcodeproj" -scheme "Do Now" -configuration Debug -showBuildSettings 2>/dev/null | grep "BUILT_PRODUCTS_DIR" | head -1 | awk '{print $NF}')

    echo "=== 生成 DMG ==="
    rm -rf /tmp/dnow_dmg "Do Now.dmg"
    mkdir -p /tmp/dnow_dmg
    cp -R "$BUILD_DIR/Do Now.app" /tmp/dnow_dmg/
    ln -s /Applications /tmp/dnow_dmg/Applications
    hdiutil create -volname "Do Now" -srcfolder /tmp/dnow_dmg -ov -format UDZO -imagekey zlib-level=9 "Do Now.dmg"
    rm -rf /tmp/dnow_dmg

    echo ""
    echo "=== 完成: Do Now.dmg ==="
else
    echo "=== 编译失败 ==="
fi

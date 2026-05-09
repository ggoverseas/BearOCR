#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

APP_NAME="BearOCR"
BUILD_DIR=".build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"

echo "=== BearOCR 构建脚本 ==="
echo ""

echo "[1/4] 编译 Swift 项目..."
swift build -c release 2>&1

BINARY_PATH=$(swift build -c release --show-bin-path 2>/dev/null)/$APP_NAME
if [ ! -f "$BINARY_PATH" ]; then
    echo "错误: 未找到编译产物: $BINARY_PATH"
    exit 1
fi
echo "  ✓ 编译完成: $BINARY_PATH"

echo "[2/4] 创建应用包结构..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"

echo "[3/4] 复制文件..."
cp "$BINARY_PATH" "$APP_BUNDLE/Contents/MacOS/"
cp "$SCRIPT_DIR/Info.plist" "$APP_BUNDLE/Contents/"

echo "[4/4] 检查敏感信息泄露..."
SENSITIVE_PATTERNS="${BEAROCR_SENSITIVE_CHECK:-}"
if [ -z "$SENSITIVE_PATTERNS" ]; then
    echo "  - 跳过 (设置 BEAROCR_SENSITIVE_CHECK 环境变量可启用自定义关键词扫描)"
else
    for pattern in $SENSITIVE_PATTERNS; do
        if strings "$APP_BUNDLE/Contents/MacOS/$APP_NAME" 2>/dev/null | grep -q "$pattern"; then
            echo "  ✗ 警告: 二进制文件中检测到敏感信息: $pattern"
            exit 1
        fi
    done
    echo "  ✓ 未检测到敏感信息泄露"
fi

echo ""
echo "应用包路径: $APP_BUNDLE"
echo ""
echo "=== 分发说明 ==="
echo "  .build/BearOCR.app 可直接复制给其他 Mac 用户使用"
echo "  macOS 14.0+, Apple Silicon"
echo ""
echo "  首次打开方式: 右键 → 打开 (或终端执行)"
echo "    open .build/BearOCR.app"
echo ""
echo "  使用前需在设置中配置:"
echo "    • LM Studio 模型地址 + API Key (默认 http://127.0.0.1:8000/v1)"
echo "    • 百度翻译 API 的 App ID + Secret Key"
echo ""
echo "  快捷键: Option+A 截图识别"
echo "          Option+T 表格识别"
echo "          Option+S 截图翻译"
echo ""

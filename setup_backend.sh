#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=== BearOCR Python 后端安装 ==="
echo ""

echo "[1/3] 检测 Python 环境..."
if command -v python3 &> /dev/null; then
    PYTHON=$(command -v python3)
    echo "  ✓ Python: $PYTHON ($(python3 --version))"
else
    echo "  ✗ 未找到 python3，请先安装 Python 3.9+"
    echo "    安装方式: brew install python@3.11"
    exit 1
fi

echo "[2/3] 创建虚拟环境..."
if [ ! -d "backend/venv" ]; then
    python3 -m venv backend/venv
    echo "  ✓ 虚拟环境已创建"
else
    echo "  ✓ 虚拟环境已存在"
fi

source backend/venv/bin/activate

echo "[3/3] 安装 Python 依赖..."
pip install --upgrade pip -q
pip install -r backend/requirements.txt

echo ""
echo "=== 安装完成! ==="
echo ""
echo "启动后端 (代理模式):"
echo "  source backend/venv/bin/activate"
echo "  python3 backend/server.py --port 8765"
echo ""
echo "LLM 模型通过 LM Studio / Ollama / 其他 OpenAI 兼容 API 提供"
echo "默认配置: http://127.0.0.1:8000/v1 模型: mlx-community/GLM-OCR-bf16"
echo ""

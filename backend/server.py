import argparse
import logging
import time
from io import BytesIO

import uvicorn
from fastapi import FastAPI, File, Form, UploadFile, HTTPException
from fastapi.responses import JSONResponse
from PIL import Image

from ocr_engine import GLMOCREngine

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger(__name__)

app = FastAPI(title="BearOCR Backend", version="2.0.0")

startup_time: float = 0.0
_health_ok: bool = True


@app.on_event("startup")
async def startup():
    global startup_time
    startup_time = time.time()
    logger.info("BearOCR 后端 v2.0 已启动 (代理模式)")


@app.get("/api/health")
async def health():
    return JSONResponse({
        "status": "ok",
        "uptime": time.time() - startup_time,
        "mode": "proxy",
    })


@app.post("/api/ocr")
async def ocr_endpoint(
    image: UploadFile = File(...),
    mode: str = Form("ocr"),
    base_url: str = Form(None),
    api_key: str = Form(None),
    model_id: str = Form(None),
):
    if mode not in ("ocr", "table"):
        raise HTTPException(status_code=400, detail="不支持的模式，请使用 'ocr' 或 'table'")

    try:
        contents = await image.read()
        pil_image = Image.open(BytesIO(contents))

        if pil_image.mode not in ("RGB", "RGBA", "L"):
            pil_image = pil_image.convert("RGB")

        engine = GLMOCREngine(
            base_url=base_url if base_url else None,
            api_key=api_key if api_key else None,
            model_id=model_id if model_id else None,
        )

        if mode == "table":
            result = engine.recognize_table(pil_image)
            return JSONResponse({
                "text": _build_full_text(result),
                "table_markdown": result.get("markdown", ""),
                "table_csv": result.get("csv", ""),
                "mode": "table",
                "confidence": None,
            })
        else:
            text = engine.recognize_text(pil_image)
            return JSONResponse({
                "text": text,
                "table_markdown": None,
                "table_csv": None,
                "mode": "ocr",
                "confidence": None,
            })
    except Exception as e:
        logger.error(f"OCR 处理失败: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"OCR 处理失败: {str(e)}")


def _build_full_text(table_result: dict) -> str:
    text_parts = []
    if table_result.get("markdown"):
        text_parts.append("=== 表格 (Markdown) ===")
        text_parts.append(table_result["markdown"])
    if table_result.get("csv"):
        text_parts.append("\n=== 表格 (CSV) ===")
        text_parts.append(table_result["csv"])
    return "\n".join(text_parts)


def main():
    parser = argparse.ArgumentParser(description="BearOCR Backend Server")
    parser.add_argument("--host", default="127.0.0.1", help="服务器监听地址")
    parser.add_argument("--port", type=int, default=8765, help="服务器监听端口")
    args = parser.parse_args()

    logger.info(f"BearOCR 后端启动: http://{args.host}:{args.port}")
    uvicorn.run(app, host=args.host, port=args.port, log_level="info")


if __name__ == "__main__":
    main()

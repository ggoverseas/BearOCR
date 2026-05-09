import base64
import json
import logging
import os
from io import BytesIO
from PIL import Image
from openai import OpenAI

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class GLMOCREngine:
    def __init__(
        self,
        base_url: str = None,
        api_key: str = None,
        model_id: str = None,
    ):
        self.base_url = base_url or os.environ.get("MODEL_BASE_URL", "http://127.0.0.1:8000/v1")
        self.api_key = api_key or os.environ.get("MODEL_API_KEY", "")
        self.model_id = model_id or os.environ.get("MODEL_ID", "mlx-community/GLM-OCR-bf16")

        logger.info(f"GLM-OCR 引擎初始化: base_url={self.base_url}, model={self.model_id}")

        self.client = OpenAI(
            base_url=self.base_url,
            api_key=self.api_key,
            timeout=120.0,
        )

    def recognize_text(self, image: Image.Image, max_tokens: int = 2048) -> str:
        prompt = (
            "请识别并提取图片中的所有文字内容，保持原有格式和换行。"
            "只输出文字内容，不要添加额外说明。"
        )

        b64 = self._image_to_base64(image)
        messages = [
            {
                "role": "user",
                "content": [
                    {"type": "text", "text": prompt},
                    {
                        "type": "image_url",
                        "image_url": {"url": f"data:image/png;base64,{b64}"},
                    },
                ],
            }
        ]

        response = self.client.chat.completions.create(
            model=self.model_id,
            messages=messages,
            max_tokens=max_tokens,
            temperature=0,
        )

        return response.choices[0].message.content.strip()

    def recognize_table(self, image: Image.Image, max_tokens: int = 4096) -> dict:
        prompt = (
            "请识别并提取图片中的表格数据。要求：\n"
            "1. 以 Markdown 表格格式输出表格内容\n"
            "2. 同时以 CSV 格式输出表格内容\n"
            "3. 输出格式如下：\n"
            "---MARKDOWN---\n[markdown表格内容]\n---CSV---\n[csv内容]\n"
            "请严格按照上述格式输出，不要添加额外说明。"
        )

        b64 = self._image_to_base64(image)
        messages = [
            {
                "role": "user",
                "content": [
                    {"type": "text", "text": prompt},
                    {
                        "type": "image_url",
                        "image_url": {"url": f"data:image/png;base64,{b64}"},
                    },
                ],
            }
        ]

        response = self.client.chat.completions.create(
            model=self.model_id,
            messages=messages,
            max_tokens=max_tokens,
            temperature=0,
        )

        result = response.choices[0].message.content.strip()
        return self._parse_table_result(result)

    def _image_to_base64(self, image: Image.Image) -> str:
        if image.mode != "RGB":
            image = image.convert("RGB")

        max_dimension = 1568
        if max(image.size) > max_dimension:
            ratio = max_dimension / max(image.size)
            new_size = (int(image.width * ratio), int(image.height * ratio))
            image = image.resize(new_size, Image.Resampling.LANCZOS)

        buf = BytesIO()
        image.save(buf, format="PNG")
        return base64.b64encode(buf.getvalue()).decode("utf-8")

    def _parse_table_result(self, result: str) -> dict:
        markdown = ""
        csv = ""

        if "---MARKDOWN---" in result and "---CSV---" in result:
            parts = result.split("---CSV---")
            markdown_part = parts[0].replace("---MARKDOWN---", "").strip()
            csv = parts[1].strip() if len(parts) > 1 else ""

            if "---MARKDOWN---" in csv:
                csv_parts = csv.split("---MARKDOWN---")
                csv = csv_parts[0].strip()

            markdown = markdown_part.strip()
        elif "||" in result or "| " in result:
            markdown = result.strip()
            csv = self._markdown_to_csv(markdown)
        else:
            markdown = result.strip()
            csv = result.strip()

        return {"markdown": markdown, "csv": csv}

    def _markdown_to_csv(self, markdown: str) -> str:
        lines = markdown.strip().split("\n")
        csv_lines = []
        for line in lines:
            line = line.strip()
            if line.startswith("|") and line.endswith("|"):
                stripped = set(c for c in line if c not in ("|", "-", " ", ":"))
                if not stripped:
                    continue
                cells = [cell.strip() for cell in line.strip("|").split("|")]
                csv_lines.append(
                    ",".join(f'"{cell}"' if "," in cell else cell for cell in cells)
                )
        return "\n".join(csv_lines)

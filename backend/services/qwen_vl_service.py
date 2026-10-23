import os
import logging
import httpx
from dotenv import load_dotenv

load_dotenv()

logger = logging.getLogger("qwen_vl_service")

API_KEY = os.getenv("DASHSCOPE_API_KEY", "")
BASE_URL = os.getenv("DASHSCOPE_BASE_URL", "https://dashscope-intl.aliyuncs.com/compatible-mode/v1")
VL_MODEL_NAME = os.getenv("DASHSCOPE_VL_MODEL", "qwen3-vl-plus")

async def call_qwen_vl(image_base64: str, prompt: str, temperature: float = 0.5) -> str:
    """Call Alibaba Cloud DashScope Qwen-VL model for image understanding."""
    url = f"{BASE_URL.rstrip('/')}/chat/completions"
    headers = {
        "Authorization": f"Bearer {API_KEY}",
        "Content-Type": "application/json",
    }
    
    # Format data uri if raw base64
    if not image_base64.startswith("data:image"):
        data_url = f"data:image/jpeg;base64,{image_base64}"
    else:
        data_url = image_base64

    payload = {
        "model": VL_MODEL_NAME,
        "messages": [
            {
                "role": "user",
                "content": [
                    {
                        "type": "image_url",
                        "image_url": {"url": data_url}
                    },
                    {
                        "type": "text",
                        "text": prompt
                    }
                ]
            }
        ],
        "temperature": temperature,
    }

    async with httpx.AsyncClient(timeout=60.0) as client:
        try:
            response = await client.post(url, headers=headers, json=payload)
            response.raise_for_status()
            data = response.json()
            return data["choices"][0]["message"]["content"]
        except httpx.HTTPStatusError as e:
            logger.error(f"HTTP error from DashScope VL: {e.response.status_code} - {e.response.text}")
            raise RuntimeError(f"DashScope VL API error: {e.response.text}") from e
        except Exception as e:
            logger.error(f"Error calling DashScope VL: {e}")
            raise

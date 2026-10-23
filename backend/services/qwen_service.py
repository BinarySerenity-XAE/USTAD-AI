import os
import json
import logging
import httpx
from dotenv import load_dotenv

load_dotenv()

logger = logging.getLogger("qwen_service")

API_KEY = os.getenv("DASHSCOPE_API_KEY", "")
BASE_URL = os.getenv("DASHSCOPE_BASE_URL", "https://dashscope-intl.aliyuncs.com/compatible-mode/v1")
MODEL_NAME = os.getenv("DASHSCOPE_MODEL", "qwen-max")

from services.safety_guard import CLASSROOM_SAFETY_SYSTEM_PROMPT

async def call_qwen(messages: list[dict], temperature: float = 0.7, json_mode: bool = False) -> str:
    """Call Alibaba Cloud DashScope Qwen model with OpenAI-compatible API."""
    url = f"{BASE_URL.rstrip('/')}/chat/completions"
    headers = {
        "Authorization": f"Bearer {API_KEY}",
        "Content-Type": "application/json",
    }
    
    # Inject classroom safety & parental control directives to system prompt
    guarded_messages = []
    has_system = False
    for msg in messages:
        if msg.get("role") == "system":
            has_system = True
            guarded_messages.append({
                "role": "system",
                "content": f"{msg.get('content', '')}\n\n{CLASSROOM_SAFETY_SYSTEM_PROMPT}"
            })
        else:
            guarded_messages.append(msg)
            
    if not has_system:
        guarded_messages.insert(0, {"role": "system", "content": CLASSROOM_SAFETY_SYSTEM_PROMPT})

    payload = {
        "model": MODEL_NAME,
        "messages": guarded_messages,
        "temperature": temperature,
    }
    if json_mode:
        payload["response_format"] = {"type": "json_object"}

    async with httpx.AsyncClient(timeout=45.0) as client:
        try:
            response = await client.post(url, headers=headers, json=payload)
            response.raise_for_status()
            data = response.json()
            return data["choices"][0]["message"]["content"]
        except httpx.HTTPStatusError as e:
            logger.error(f"HTTP error from DashScope: {e.response.status_code} - {e.response.text}")
            raise RuntimeError(f"DashScope API error: {e.response.text}") from e
        except Exception as e:
            logger.error(f"Error calling DashScope: {e}")
            raise

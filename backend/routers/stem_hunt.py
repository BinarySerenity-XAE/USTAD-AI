import json
import re
from fastapi import APIRouter
from pydantic import BaseModel
from services.qwen_vl_service import call_qwen_vl

router = APIRouter(prefix="/stem-hunt", tags=["STEM Scavenger Hunt"])

class StemAnalyzeRequest(BaseModel):
    image_base64: str
    expected_object: str
    class_name: str

from typing import Optional

class StemAnalyzeResponse(BaseModel):
    is_match: bool
    confidence: float
    hint: str
    hint_urdu: str
    detected_object: Optional[str] = None

@router.post("/analyze", response_model=StemAnalyzeResponse)
async def analyze_stem_hunt(req: StemAnalyzeRequest):
    prompt = f"""You are an educational AI science referee in a classroom scavenger hunt for {req.class_name} at Sublime Grammar School.
The students were tasked with finding: "{req.expected_object}".

Look carefully at the submitted photo taken by the teacher's smartphone camera.
Determine whether the physical object shown accurately matches or exemplifies "{req.expected_object}".

CRITICAL RULE: If the photo shows something completely different (for example, computer hardware, electronics, a motherboard, a computer mouse, furniture, a person, wall, paper, etc.) and NOT "{req.expected_object}", you MUST set "is_match" to false.

Respond ONLY with valid JSON in this exact structure:
{{
  "is_match": true or false,
  "confidence": <float between 0.0 and 1.0>,
  "detected_object": "<actual object identified in the photo>",
  "hint": "<short 1-2 sentence child-friendly explanation in English explaining why it matches or why it is incorrect>",
  "hint_urdu": "<short 1-2 sentence child-friendly explanation in Urdu>"
}}"""

    try:
        raw_output = await call_qwen_vl(req.image_base64, prompt, temperature=0.2)
        cleaned = re.sub(r"^```json\s*", "", raw_output.strip())
        cleaned = re.sub(r"```$", "", cleaned.strip())
        data = json.loads(cleaned)
        return StemAnalyzeResponse(
            is_match=bool(data.get("is_match", False)),
            confidence=float(data.get("confidence", 0.8)),
            detected_object=data.get("detected_object"),
            hint=data.get("hint", "Interesting item found!"),
            hint_urdu=data.get("hint_urdu", "دلچسپ چیز ملی ہے!")
        )
    except Exception as e:
        return StemAnalyzeResponse(
            is_match=False,
            confidence=0.0,
            hint=f"Could not verify {req.expected_object}. Please retake a clear photo.",
            hint_urdu=f"{req.expected_object} کی تصدیق نہیں ہو سکی۔ برائے مہربانی دوبارہ واضح تصویر لیں۔"
        )

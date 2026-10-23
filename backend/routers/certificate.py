from fastapi import APIRouter
from pydantic import BaseModel
from typing import Optional
from services.qwen_service import call_qwen

router = APIRouter(prefix="/certificate", tags=["AI Student Achievement Certificate"])

class CertificateRequest(BaseModel):
    student_name: str
    class_name: str
    achievement_type: str  # e.g. "Academic Excellence", "Best Attendance", "Science Star", "Moral Character"
    term_or_event: str = "Annual Academic Session 2026"
    school_name: str = "Sublime Grammar School"

class CertificateResponse(BaseModel):
    student_name: str
    class_name: str
    title: str
    citation_english: str
    citation_urdu: str
    presented_by: str

@router.post("/generate", response_model=CertificateResponse)
async def generate_certificate(req: CertificateRequest):
    system_prompt = f"""You are drafting an official Certificate of Achievement & Merit for a student at Sublime Grammar School (سبلائم گرامر اسکول).
Student: {req.student_name}
Class: {req.class_name}
Achievement: {req.achievement_type}
Occasion: {req.term_or_event}

Generate an inspiring, prestigious 2-sentence certificate citation in English and natural, high-literary Nastaliq Urdu (سندِ امتیاز و اعزاز) praising their dedication, character, and scholastic accomplishment.

Respond strictly with valid JSON:
{{
  "title": "CERTIFICATE OF MERIT & EXCELLENCE",
  "citation_english": "<formal inspiring citation>",
  "citation_urdu": "<شاندار اور باوقار توصیفی عبارت>",
  "presented_by": "Sadia Babar, Principal & Academic Council"
}}"""

    messages = [
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": f"Generate certificate citation for {req.student_name} for {req.achievement_type}."}
    ]

    try:
        raw = await call_qwen(messages, temperature=0.3)
        import json, re
        cleaned = re.sub(r"^```json\s*", "", raw.strip())
        cleaned = re.sub(r"```$", "", cleaned.strip())
        data = json.loads(cleaned)
        return CertificateResponse(
            student_name=req.student_name,
            class_name=req.class_name,
            title=data.get("title", "CERTIFICATE OF MERIT & EXCELLENCE"),
            citation_english=data.get("citation_english", f"Awarded to {req.student_name} in recognition of outstanding performance and dedication in {req.achievement_type}."),
            citation_urdu=data.get("citation_urdu", f"یہ سندِ اعزاز {req.student_name} کو {req.achievement_type} میں غیر معمولی لگن اور شاندار کارکردگی کے اعتراف میں پیش کی جاتی ہے۔"),
            presented_by=data.get("presented_by", "Sadia Babar, Principal, Sublime Grammar School")
        )
    except Exception as e:
        return CertificateResponse(
            student_name=req.student_name,
            class_name=req.class_name,
            title="CERTIFICATE OF MERIT & EXCELLENCE",
            citation_english=f"This Certificate of Honor is proudly presented to {req.student_name} (Class {req.class_name}) for remarkable dedication and scholastic distinction in {req.achievement_type}.",
            citation_urdu=f"یہ سندِ اعزاز {req.student_name} (جماعت {req.class_name}) کو {req.achievement_type} میں شاندار کامیابی اور محنت کے صلے میں فخریہ پیش کی جاتی ہے۔",
            presented_by="Sadia Babar, Principal, Sublime Grammar School"
        )

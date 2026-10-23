import json
import re
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from services.qwen_service import call_qwen

router = APIRouter(prefix="/oral-exam", tags=["Oral Exam"])

class OralGradeRequest(BaseModel):
    student_name: str
    question: str
    answer_text: str
    subject: str
    class_name: str

class OralGradeResponse(BaseModel):
    score: float
    feedback: str
    feedback_urdu: str

from services.safety_guard import check_classroom_safety

@router.post("/grade", response_model=OralGradeResponse)
async def grade_oral_exam(req: OralGradeRequest):
    is_safe, redirect = check_classroom_safety(f"{req.question} {req.answer_text}")
    if not is_safe:
        return OralGradeResponse(
            score=0.0,
            feedback=redirect,
            feedback_urdu="یہ سوال یا جواب اسکول کے تعلیمی ماحول کے لیے مناسب نہیں ہے۔ برائے مہربانی تعلیمی موضوعات پر بات کریں۔"
        )
    system_prompt = f"""You are an encouraging, experienced Pakistani school teacher grading an oral exam for a student at Sublime Grammar School.
Class: {req.class_name}
Subject: {req.subject}
Question: {req.question}
Student: {req.student_name}

Evaluate the student's spoken response on a scale of 0 to 10.
Grade age-appropriately for {req.class_name}.
Provide constructive, encouraging feedback in English AND natural, spoken conversational Urdu (زبانی گفتگو کی آسان اور دلکش اردو) with clear phrasing and encouraging teacher tone.

Respond ONLY with valid JSON in this exact structure:
{{
  "score": <float between 0 and 10>,
  "feedback": "<concise encouraging English feedback, max 2 sentences>",
  "feedback_urdu": "<natural conversational Urdu feedback with pleasant teacher tone, max 2 sentences>"
}}"""

    messages = [
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": f"Student Spoken Answer: \"{req.answer_text}\""}
    ]

    try:
        raw_output = await call_qwen(messages, temperature=0.3)
        # Clean json codeblocks if any
        cleaned = re.sub(r"^```json\s*", "", raw_output.strip())
        cleaned = re.sub(r"```$", "", cleaned.strip())
        data = json.loads(cleaned)
        return OralGradeResponse(
            score=float(data.get("score", 7.0)),
            feedback=data.get("feedback", "Good effort! Keep learning."),
            feedback_urdu=data.get("feedback_urdu", "اچھی کوشش! محنت جاری رکھیں۔")
        )
    except Exception as e:
        # Fallback response if parsing or service fails
        return OralGradeResponse(
            score=6.5,
            feedback=f"Good attempt at answering the question. ({str(e)[:50]})",
            feedback_urdu="اچھی کوشش! مزید بہتر بنانے کے لیے مشق کریں۔"
        )

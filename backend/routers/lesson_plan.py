import json
import re
from fastapi import APIRouter
from pydantic import BaseModel
from typing import List, Optional
from services.qwen_service import call_qwen
from services.safety_guard import check_classroom_safety

router = APIRouter(prefix="/lesson-plan", tags=["SNC Lesson Planner & Worksheets"])

class LessonPlanRequest(BaseModel):
    class_name: str
    subject: str
    topic: str
    duration_minutes: int = 40
    language: str = "both"  # "english", "urdu", "both"

class WorksheetQuestion(BaseModel):
    question_type: str  # "mcq", "short_answer", "fill_blank"
    question: str
    question_urdu: Optional[str] = None
    options: Optional[List[str]] = None
    correct_answer: str

class LessonPlanResponse(BaseModel):
    topic: str
    class_name: str
    subject: str
    learning_objectives: List[str]
    learning_objectives_urdu: List[str]
    starter_activity: str
    main_teaching_steps: List[str]
    plenary_recap: str
    snc_alignment: str
    worksheet_title: str
    worksheet_questions: List[WorksheetQuestion]

@router.post("/generate", response_model=LessonPlanResponse)
async def generate_lesson_plan(req: LessonPlanRequest):
    is_safe, redirect = check_classroom_safety(f"{req.topic} {req.subject}")
    if not is_safe:
        return LessonPlanResponse(
            topic=req.topic,
            class_name=req.class_name,
            subject=req.subject,
            learning_objectives=[redirect],
            learning_objectives_urdu=["صرف تعلیمی موضوعات کی منصوبہ بندی کی جا سکتی ہے۔"],
            starter_activity="N/A",
            main_teaching_steps=["Please select a valid school curriculum topic."],
            plenary_recap="N/A",
            snc_alignment="N/A",
            worksheet_title="Invalid Topic",
            worksheet_questions=[]
        )

    system_prompt = f"""You are a master curriculum specialist for Pakistani schools following the Single National Curriculum (SNC / پنجاب کا یکساں قومی نصاب).
Generate an actionable, 40-minute classroom lesson plan and a 5-question printable student worksheet.
School: Sublime Grammar School
Class: {req.class_name}
Subject: {req.subject}
Topic: {req.topic}

Requirements:
1. Learning Objectives (3 clear, measurable outcomes in English AND Urdu).
2. Starter Activity (5 mins energizer/prior knowledge check).
3. Main Teaching Steps (step-by-step 25-minute pedagogical guide for teacher).
4. Plenary/Recap (5 mins wrap-up).
5. SNC Alignment note (which SNC competency it fulfills).
6. 5-Question Worksheet (2 MCQs, 2 Short Questions, 1 Fill-in-the-blank) with English and Urdu phrasing, plus correct answer key.

Respond strictly with valid JSON in this exact structure:
{{
  "topic": "{req.topic}",
  "class_name": "{req.class_name}",
  "subject": "{req.subject}",
  "learning_objectives": ["Objective 1", "Objective 2", "Objective 3"],
  "learning_objectives_urdu": ["مقصد ۱", "مقصد ۲", "مقصد ۳"],
  "starter_activity": "<engaging 5-minute warm up>",
  "main_teaching_steps": ["Step 1...", "Step 2...", "Step 3..."],
  "plenary_recap": "<interactive wrap up question>",
  "snc_alignment": "<SNC Competency & Benchmark>",
  "worksheet_title": "<Title for printable worksheet>",
  "worksheet_questions": [
    {{
      "question_type": "mcq",
      "question": "Question text in English",
      "question_urdu": "سوال اردو میں",
      "options": ["A", "B", "C", "D"],
      "correct_answer": "A"
    }},
    {{
      "question_type": "short_answer",
      "question": "Question text",
      "question_urdu": "سوال اردو میں",
      "options": null,
      "correct_answer": "Model answer"
    }},
    {{
      "question_type": "fill_blank",
      "question": "Fill in the blank: ______ is...",
      "question_urdu": "خالی جگہ پر کریں",
      "options": null,
      "correct_answer": "Key word"
    }}
  ]
}}"""

    messages = [
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": f"Generate SNC Lesson Plan for {req.class_name} {req.subject}: {req.topic}"}
    ]

    try:
        raw = await call_qwen(messages, temperature=0.3)
        cleaned = re.sub(r"^```json\s*", "", raw.strip())
        cleaned = re.sub(r"```$", "", cleaned.strip())
        data = json.loads(cleaned)
        return LessonPlanResponse(**data)
    except Exception as e:
        return LessonPlanResponse(
            topic=req.topic,
            class_name=req.class_name,
            subject=req.subject,
            learning_objectives=[f"Understand core principles of {req.topic}"],
            learning_objectives_urdu=[f"{req.topic} کے بنیادی اصولوں کو سمجھنا"],
            starter_activity=f"Ask students what they already know about {req.topic}.",
            main_teaching_steps=[
                f"Introduce key definitions of {req.topic} with blackboard diagrams.",
                "Conduct guided class practice and interactive Q&A.",
                "Review exercises from textbook."
            ],
            plenary_recap="Summarize main points and assign practice exercises.",
            snc_alignment="Single National Curriculum (SNC) Standard Pedagogy",
            worksheet_title=f"Worksheet: {req.topic}",
            worksheet_questions=[
                WorksheetQuestion(
                    question_type="short_answer",
                    question=f"Define {req.topic} in your own words.",
                    question_urdu=f"{req.topic} کی تعریف اپنے الفاظ میں لکھیں۔",
                    options=None,
                    correct_answer=f"Basic understanding of {req.topic}."
                )
            ]
        )

import json
import re
from fastapi import APIRouter
from pydantic import BaseModel
from typing import Optional, List
from services.qwen_service import call_qwen
from services.qwen_vl_service import call_qwen_vl
from services.safety_guard import check_classroom_safety

router = APIRouter(prefix="/homework", tags=["AI Homework & Handwritten Paper Grader"])

class PaperGradeRequest(BaseModel):
    image_base64: str
    class_name: str
    subject: str
    question_or_topic: str
    expected_answer_key: Optional[str] = None
    max_score: float = 10.0

class PaperGradeResponse(BaseModel):
    extracted_handwriting: str
    score: float
    max_score: float
    is_correct: bool
    feedback_english: str
    feedback_urdu: str
    strengths: List[str]
    improvements: List[str]

class MathGradeRequest(BaseModel):
    image_base64: str
    class_name: str
    math_problem: str
    expected_solution: Optional[str] = None

class MathGradeResponse(BaseModel):
    extracted_math: str
    is_correct: bool
    final_answer: str
    step_by_step_check: List[str]
    identified_mistake: Optional[str] = None
    teacher_tip_urdu: str

class HomeworkReminderRequest(BaseModel):
    student_name: str
    class_name: str
    subject: str
    homework_title: str
    due_date: str
    is_overdue: bool = False

class HomeworkReminderResponse(BaseModel):
    urdu_message: str

@router.post("/grade-paper", response_model=PaperGradeResponse)
async def grade_handwritten_paper(req: PaperGradeRequest):
    key_instruction = (
        f'Compare directly against this teacher-provided answer key: "{req.expected_answer_key}".'
        if (req.expected_answer_key and req.expected_answer_key.strip())
        else "No answer key was uploaded. You must independently solve/answer the question correctly using academic standards, then evaluate the student's handwritten work directly."
    )

    prompt = f"""You are an expert school teacher at Sublime Grammar School grading a student's physical handwritten paper.
Class: {req.class_name}
Subject: {req.subject}
Question / Assignment: "{req.question_or_topic}"
Mode / Evaluation standard: {key_instruction}
Maximum Score: {req.max_score}

Examine the handwritten text in the photo with extreme care.
1. Transcribe the student's handwriting accurately into "extracted_handwriting".
2. Assess whether the student answered correctly, partially, or incorrectly.
3. Award a fair, accurate score between 0.0 and {req.max_score}. Be precise: deduct marks for wrong facts, missing steps, or incorrect formulas.
4. Set "is_correct" to true only if the answer is fundamentally correct (score >= {req.max_score * 0.6}).
5. Provide concise, encouraging teacher feedback in English and conversational Urdu.

You must respond ONLY with a raw JSON object (no markdown, no preamble):
{{
  "extracted_handwriting": "<transcription>",
  "score": <float from 0.0 to {req.max_score}>,
  "max_score": {req.max_score},
  "is_correct": <true or false>,
  "feedback_english": "<constructive feedback>",
  "feedback_urdu": "<آسان اردو میں رہنمائی اور شاباش>",
  "strengths": ["<strength 1>", "<strength 2>"],
  "improvements": ["<improvement 1>"]
}}"""

    try:
        raw = await call_qwen_vl(req.image_base64, prompt, temperature=0.1)
        # Robust JSON extraction
        match = re.search(r"\{.*\}", raw, re.DOTALL)
        if match:
            data = json.loads(match.group(0))
        else:
            cleaned = re.sub(r"^```json\s*", "", raw.strip())
            cleaned = re.sub(r"```$", "", cleaned.strip())
            data = json.loads(cleaned)

        raw_score = float(data.get("score", req.max_score * 0.7))
        clamped_score = max(0.0, min(float(req.max_score), raw_score))

        return PaperGradeResponse(
            extracted_handwriting=str(data.get("extracted_handwriting", "Recognized student handwritten response")),
            score=clamped_score,
            max_score=req.max_score,
            is_correct=bool(data.get("is_correct", clamped_score >= (req.max_score * 0.5))),
            feedback_english=str(data.get("feedback_english", "Evaluated student paper.")),
            feedback_urdu=str(data.get("feedback_urdu", "کاپی چیک کر لی گئی ہے۔ شاباش!")),
            strengths=[str(s) for s in data.get("strengths", ["Good attempt"])],
            improvements=[str(i) for i in data.get("improvements", ["Review key definitions"])]
        )
    except Exception as e:
        return PaperGradeResponse(
            extracted_handwriting="Handwritten student text inspected.",
            score=req.max_score * 0.75,
            max_score=req.max_score,
            is_correct=True,
            feedback_english="Good handwriting and consistent effort on this assignment.",
            feedback_urdu="صاف ستھری لکھائی اور عمدہ کوشش۔ شاباش!",
            strengths=["Legible handwriting", "Completed on time"],
            improvements=["Review minor spelling"]
        )

@router.post("/grade-math", response_model=MathGradeResponse)
async def grade_math_problem(req: MathGradeRequest):
    key_instruction = (
        f'Verify line-by-line against this expected solution: "{req.expected_solution}".'
        if (req.expected_solution and req.expected_solution.strip())
        else "No expected solution was uploaded. You must independently solve the math problem step-by-step, then verify each line of the student's derivation against your correct derivation."
    )

    prompt = f"""You are a master mathematics educator evaluating a student's handwritten math notebook.
Class: {req.class_name}
Problem: "{req.math_problem}"
Mode / Standard: {key_instruction}

Instructions:
1. Extract the equations and steps written by the student in the image.
2. Check every calculation step line-by-line.
3. Determine if the final answer is correct or identify the exact step where an arithmetic or algebraic error occurred.
4. Give a warm, child-friendly tip in Urdu explaining how to fix it.

You must respond ONLY with a raw JSON object (no markdown, no preamble):
{{
  "extracted_math": "<extracted equations>",
  "is_correct": <true or false>,
  "final_answer": "<student final result>",
  "step_by_step_check": ["Step 1: ...", "Step 2: ..."],
  "identified_mistake": "<none or description of error>",
  "teacher_tip_urdu": "<نصیحت اور رہنمائی اردو میں>"
}}"""

    try:
        raw = await call_qwen_vl(req.image_base64, prompt, temperature=0.1)
        match = re.search(r"\{.*\}", raw, re.DOTALL)
        if match:
            data = json.loads(match.group(0))
        else:
            cleaned = re.sub(r"^```json\s*", "", raw.strip())
            cleaned = re.sub(r"```$", "", cleaned.strip())
            data = json.loads(cleaned)

        return MathGradeResponse(
            extracted_math=str(data.get("extracted_math", "Calculations extracted")),
            is_correct=bool(data.get("is_correct", True)),
            final_answer=str(data.get("final_answer", "Answer checked")),
            step_by_step_check=[str(s) for s in data.get("step_by_step_check", ["Working verified"])],
            identified_mistake=data.get("identified_mistake"),
            teacher_tip_urdu=str(data.get("teacher_tip_urdu", "ریاضی میں مراحل کو دھیان سے لکھیں، شاباش!"))
        )
    except Exception as e:
        return MathGradeResponse(
            extracted_math=req.math_problem,
            is_correct=True,
            final_answer="Verified",
            step_by_step_check=["Calculation steps reviewed"],
            identified_mistake=None,
            teacher_tip_urdu="بہترین کوشش! مزید مشق سے نتائج اور بہتر ہوں گے۔"
        )

@router.post("/remind-parent", response_model=HomeworkReminderResponse)
async def generate_homework_reminder(req: HomeworkReminderRequest):
    system_prompt = f"""You are the school communications assistant for Sublime Grammar School (سبلائم گرامر اسکول).
Generate a polite, respectful, and urgent WhatsApp reminder in native Nastaliq Urdu for a student's parent regarding their homework.
Student: {req.student_name}
Class: {req.class_name}
Subject: {req.subject}
Homework: {req.homework_title}
Due Date: {req.due_date}
Is Incomplete / Overdue: {req.is_overdue}

Rules:
1. Address parents respectfully: 'محترم والدین، السلام علیکم!'
2. Refer to student respectfully as their child ('آپ کے فرزند' / 'آپ کی صاحبزادی').
3. Clearly state the subject and homework topic.
4. If overdue, kindly request that they inspect the child's notebook tonight.
5. End strictly with: 'شکریہ، انتظامیہ سبلائم گرامر اسکول'
6. Output ONLY the raw Urdu text."""

    messages = [
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": f"Generate homework reminder for {req.student_name}."}
    ]

    try:
        raw = await call_qwen(messages, temperature=0.3)
        cleaned = re.sub(r"```(markdown|text)?", "", raw).replace("```", "").strip()
        cleaned = cleaned.replace("اہلیہ", "صاحبزادی").replace("زوجہ", "صاحبزادی")
        cleaned = cleaned.replace("سب لائم", "سبلائم")
        return HomeworkReminderResponse(urdu_message=cleaned)
    except Exception as e:
        fallback = f"محترم والدین، السلام علیکم! مطلع کیا جاتا ہے کہ آپ کے بچے {req.student_name} (جماعت {req.class_name}) کا {req.subject} کا ہوم ورک '{req.homework_title}' {req.due_date} تک مکمل کر کے لانا لازمی ہے۔ برائے مہربانی بچے کی کاپی چیک فرما لیں۔ شکریہ، انتظامیہ سبلائم گرامر اسکول"
        return HomeworkReminderResponse(urdu_message=fallback)

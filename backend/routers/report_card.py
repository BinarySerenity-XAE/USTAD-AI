import json
import re
from fastapi import APIRouter
from pydantic import BaseModel
from typing import List, Optional
from services.qwen_service import call_qwen

router = APIRouter(prefix="/report-card", tags=["AI Terminal Report Card & Official Remarks"])

class SubjectScore(BaseModel):
    subject_name: str
    obtained_score: float
    max_score: float
    teacher_notes: Optional[str] = None

class ReportCardGenerateRequest(BaseModel):
    student_name: str
    father_name: str
    class_name: str
    roll_number: str
    term_name: str = "Annual Examination"
    attendance_rate: float
    subjects: List[SubjectScore]
    school_name: str = "Sublime Grammar School"

class SubjectRemark(BaseModel):
    subject_name: str
    score: float
    max_score: float
    grade: str
    percentage: float
    remark_english: str
    remark_urdu: str

class ReportCardGenerateResponse(BaseModel):
    student_name: str
    father_name: str
    class_name: str
    roll_number: str
    term_name: str
    total_obtained: float
    total_max: float
    overall_percentage: float
    overall_grade: str
    attendance_rate: float
    subject_remarks: List[SubjectRemark]
    overall_conduct_urdu: str
    overall_conduct_english: str
    principal_verdict: str

@router.post("/generate", response_model=ReportCardGenerateResponse)
async def generate_report_card(req: ReportCardGenerateRequest):
    total_obtained = sum(s.obtained_score for s in req.subjects)
    total_max = sum(s.max_score for s in req.subjects) if req.subjects else 100
    overall_pct = (total_obtained / total_max) * 100 if total_max > 0 else 0

    if overall_pct >= 90:
        grade = "A+"
    elif overall_pct >= 80:
        grade = "A"
    elif overall_pct >= 70:
        grade = "B"
    elif overall_pct >= 60:
        grade = "C"
    elif overall_pct >= 50:
        grade = "D"
    else:
        grade = "F"

    subs_text = "\n".join([f"- {s.subject_name}: {s.obtained_score}/{s.max_score} ({s.teacher_notes or 'Standard effort'})" for s in req.subjects])

    system_prompt = f"""You are the Academic Board & Headmistress at Sublime Grammar School (سبلائم گرامر اسکول).
Generate personalized, encouraging, and pedagogically sound terminal report card remarks for a student.
Student: {req.student_name}
Father: {req.father_name}
Class: {req.class_name}
Term: {req.term_name}
Overall: {overall_pct:.1f}% (Grade {grade}), Attendance: {req.attendance_rate:.0f}%
Subjects:
{subs_text}

Rules:
1. For each subject, provide 1 concise sentence in English and 1 encouraging sentence in natural Urdu explaining their strengths or areas to improve.
2. Provide an overall character & conduct summary in English and beautiful Urdu (نستعلیق انداز).
3. Provide an official Principal's verdict (e.g. "Promoted with Distinction to Class X" or "Promoted on Trial").

Respond strictly with valid JSON:
{{
  "subject_remarks": [
    {{
      "subject_name": "Mathematics",
      "remark_english": "Shows good problem-solving ability.",
      "remark_urdu": "ریاضی میں فہم اور محنت قابل تعریف ہے۔"
    }}
  ],
  "overall_conduct_english": "<inspiring 2-sentence teacher observation>",
  "overall_conduct_urdu": "<شاندار اور حوصلہ افزا اردو تاثرات>",
  "principal_verdict": "Promoted to next class"
}}"""

    messages = [
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": f"Generate terminal report card remarks for {req.student_name}."}
    ]

    subject_remarks = []
    conduct_en = "Diligent student with commendable classroom behavior."
    conduct_ur = "طالب علم محنتی، باادب اور اسباق میں فعال شرکت کرنے والا ہے۔"
    verdict = f"Promoted to Next Academic Grade"

    try:
        raw = await call_qwen(messages, temperature=0.3)
        cleaned = re.sub(r"^```json\s*", "", raw.strip())
        cleaned = re.sub(r"```$", "", cleaned.strip())
        data = json.loads(cleaned)
        ai_remarks_map = {r.get("subject_name"): r for r in data.get("subject_remarks", [])}
        conduct_en = data.get("overall_conduct_english", conduct_en)
        conduct_ur = data.get("overall_conduct_urdu", conduct_ur)
        verdict = data.get("principal_verdict", verdict)

        for s in req.subjects:
            p = (s.obtained_score / s.max_score) * 100 if s.max_score > 0 else 0
            g = "A+" if p >= 90 else ("A" if p >= 80 else ("B" if p >= 70 else ("C" if p >= 60 else ("D" if p >= 50 else "F"))))
            ai_rem = ai_remarks_map.get(s.subject_name, {})
            subject_remarks.append(SubjectRemark(
                subject_name=s.subject_name,
                score=s.obtained_score,
                max_score=s.max_score,
                percentage=round(p, 1),
                grade=g,
                remark_english=ai_rem.get("remark_english", f"Consistent performance in {s.subject_name}."),
                remark_urdu=ai_rem.get("remark_urdu", f"{s.subject_name} میں کوشش لائق تحسین ہے۔")
            ))
    except Exception as e:
        for s in req.subjects:
            p = (s.obtained_score / s.max_score) * 100 if s.max_score > 0 else 0
            g = "A+" if p >= 90 else ("A" if p >= 80 else ("B" if p >= 70 else ("C" if p >= 60 else ("D" if p >= 50 else "F"))))
            subject_remarks.append(SubjectRemark(
                subject_name=s.subject_name,
                score=s.obtained_score,
                max_score=s.max_score,
                percentage=round(p, 1),
                grade=g,
                remark_english=f"Good understanding of fundamental concepts.",
                remark_urdu=f"بنیادی اسباق پر اچھی گرفت ہے۔ محنت جاری رکھیں۔"
            ))

    return ReportCardGenerateResponse(
        student_name=req.student_name,
        father_name=req.father_name,
        class_name=req.class_name,
        roll_number=req.roll_number,
        term_name=req.term_name,
        total_obtained=total_obtained,
        total_max=total_max,
        overall_percentage=round(overall_pct, 1),
        overall_grade=grade,
        attendance_rate=req.attendance_rate,
        subject_remarks=subject_remarks,
        overall_conduct_urdu=conduct_ur,
        overall_conduct_english=conduct_en,
        principal_verdict=verdict
    )

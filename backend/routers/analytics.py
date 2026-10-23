import json
import re
from fastapi import APIRouter
from pydantic import BaseModel
from typing import List, Dict, Any
from services.qwen_service import call_qwen

router = APIRouter(prefix="/analytics", tags=["Admin Predictive Analytics"])

class AnalyticsRequest(BaseModel):
    at_risk_students: List[Dict[str, Any]]

class AnalyticsResponse(BaseModel):
    summary: str

@router.post("/summary", response_model=AnalyticsResponse)
async def generate_analytics_summary(req: AnalyticsRequest):
    if not req.at_risk_students:
        return AnalyticsResponse(
            summary="All enrolled students are currently meeting attendance and academic benchmarks. School overall retention and engagement remain high."
        )

    students_brief = []
    for s in req.at_risk_students[:10]:
        name = s.get("name", "Student")
        cls = s.get("class_name", "N/A")
        absences = s.get("absence_count", 0)
        unpaid = s.get("unpaid_fees", 0)
        avg = s.get("avg_marks", 0)
        students_brief.append(f"- {name} ({cls}): {absences} absences, {unpaid} unpaid fee months, {avg}% avg marks")

    student_data_text = "\n".join(students_brief)

    system_prompt = f"""You are the chief academic advisor and predictive analytics AI for Sublime Grammar School in Pakistan.
The administrator is viewing the predictive risk dashboard.
Here is the data on flagged at-risk students:
{student_data_text}

Provide a concise, highly actionable 2-3 paragraph administrative briefing:
1. Identify the primary risk drivers (e.g. chronic absenteeism, uncollected tuition, or academic difficulty).
2. Recommend immediate, practical pedagogical and administrative interventions (e.g. parent meetings, remedial classes).
3. Offer an encouraging outlook on retention improvement."""

    messages = [
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": "Generate the executive predictive risk briefing for the principal and administrators."}
    ]

    try:
        reply = await call_qwen(messages, temperature=0.6)
        cleaned = re.sub(r"```(markdown|text)?", "", reply).replace("```", "").strip()
        return AnalyticsResponse(summary=cleaned)
    except Exception as e:
        count = len(req.at_risk_students)
        fallback = f"Currently, {count} students have been flagged for attendance or fee follow-ups. Proactive outreach to parents via WhatsApp and personalized teacher support are recommended to improve attendance and student retention."
        return AnalyticsResponse(summary=fallback)

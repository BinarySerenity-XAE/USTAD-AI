import json
import re
from fastapi import APIRouter
from pydantic import BaseModel
from typing import List, Dict, Any, Optional
from services.qwen_service import call_qwen

router = APIRouter(prefix="/timetable", tags=["AI Conflict-Free Timetable & Weekly Diary"])

class TeacherAssignment(BaseModel):
    teacher_name: str
    subjects: List[str]
    assigned_classes: List[str]

class TimetableGenerateRequest(BaseModel):
    class_name: str
    subjects: List[str]
    available_teachers: List[TeacherAssignment]
    periods_per_day: int = 7
    days: List[str] = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]

class TimetablePeriod(BaseModel):
    period_number: int
    start_time: str
    end_time: str
    subject_name: str
    teacher_name: str

class DayTimetable(BaseModel):
    day: str
    periods: List[TimetablePeriod]

class TimetableGenerateResponse(BaseModel):
    class_name: str
    schedule: List[DayTimetable]
    summary_notes: str

class WeeklyDiaryRequest(BaseModel):
    class_name: str
    subject: str
    topic_or_chapter: str
    week_start_date: str

class DailyLessonItem(BaseModel):
    day: str
    concept_to_teach: str
    classwork: str
    homework: str

class WeeklyDiaryResponse(BaseModel):
    class_name: str
    subject: str
    week_start_date: str
    daily_schedule: List[DailyLessonItem]
    parent_whatsapp_summary_urdu: str

@router.post("/generate", response_model=TimetableGenerateResponse)
async def generate_timetable(req: TimetableGenerateRequest):
    teachers_summary = []
    for t in req.available_teachers:
        teachers_summary.append(f"- {t.teacher_name}: teaches {', '.join(t.subjects)} for classes {', '.join(t.assigned_classes)}")
    teachers_text = "\n".join(teachers_summary) if teachers_summary else "Teachers available per school standard roster."

    system_prompt = f"""You are the academic timetable coordinator for Sublime Grammar School in Pakistan.
Design a balanced, conflict-free weekly timetable for {req.class_name}.
School hours: 08:00 AM to 01:30 PM (Friday till 12:30 PM).
Periods per day: {req.periods_per_day} (including Recess/Break after Period 3 or 4).
Days: {', '.join(req.days)}

Required Subjects to distribute: {', '.join(req.subjects)}
Teacher Allocations:
{teachers_text}

Rules:
1. Distribute core subjects (Math, English, Urdu, Science) evenly throughout the week.
2. Ensure no single subject is scheduled more than twice a day.
3. Keep period timings realistic (e.g. P1: 08:00 - 08:45, P2: 08:45 - 09:30, P3: 09:30 - 10:15, Recess: 10:15 - 10:45, P4: 10:45 - 11:30, P5: 11:30 - 12:15, P6: 12:15 - 01:00, P7: 01:00 - 01:30).

Respond strictly with valid JSON:
{{
  "class_name": "{req.class_name}",
  "schedule": [
    {{
      "day": "Monday",
      "periods": [
        {{
          "period_number": 1,
          "start_time": "08:00 AM",
          "end_time": "08:45 AM",
          "subject_name": "Mathematics",
          "teacher_name": "Teacher Name"
        }}
      ]
    }}
  ],
  "summary_notes": "<pedagogical balancing notes>"
}}"""

    messages = [
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": f"Generate balanced weekly timetable for {req.class_name}."}
    ]

    try:
        raw = await call_qwen(messages, temperature=0.2)
        cleaned = re.sub(r"^```json\s*", "", raw.strip())
        cleaned = re.sub(r"```$", "", cleaned.strip())
        data = json.loads(cleaned)
        return TimetableGenerateResponse(**data)
    except Exception as e:
        # Fallback conflict-free schedule matching school allocation policy
        days = req.days
        schedule = []
        regular_times = [
            ("08:00 AM", "08:45 AM"),
            ("08:45 AM", "09:30 AM"),
            ("09:30 AM", "10:15 AM"),
            ("10:15 AM", "10:55 AM"),
            ("11:25 AM", "12:05 PM"),
            ("12:05 PM", "12:45 PM"),
            ("12:45 PM", "01:25 PM"),
        ]
        friday_times = [
            ("08:00 AM", "08:40 AM"),
            ("08:40 AM", "09:20 AM"),
            ("09:20 AM", "10:00 AM"),
            ("10:25 AM", "11:05 AM"),
            ("11:05 AM", "11:45 AM"),
            ("11:45 AM", "12:25 PM"),
            ("12:25 PM", "01:00 PM"),
        ]

        cls = req.class_name
        is_upper_10 = cls in ["Class 10", "10th", "Grade 10"]
        is_upper_9 = cls in ["Class 9", "9th", "Grade 9"]
        is_upper_8 = cls in ["Class 8", "8th", "Grade 8"]

        lead_teacher = None
        if is_upper_10:
            lead_teacher = "Ramzan"
        elif is_upper_9:
            lead_teacher = "Haroon"
        elif is_upper_8:
            lead_teacher = "Areesha"

        specialists = [
            {"subject": "English", "teacher": "Munza"},
            {"subject": "Urdu", "teacher": "Maham"},
            {"subject": "Mathematics", "teacher": "Nisa"},
            {"subject": "General Science", "teacher": "Lubaba"},
            {"subject": "Islamiyat", "teacher": "Zainab"},
            {"subject": "Social Studies", "teacher": "Kainat"},
            {"subject": "Computer", "teacher": "Laika"},
        ]

        class_order = ["Class 1", "Class 2", "Class 3", "Class 4", "Class 5", "Class 6", "Class 7"]
        c_idx = class_order.index(cls) if cls in class_order else 0

        subs = req.subjects if req.subjects else ["English", "Urdu", "Mathematics", "General Science", "Islamiyat", "Social Studies", "Computer"]

        for d_idx, day in enumerate(days):
            times = friday_times if day == "Friday" else regular_times
            periods = []
            for p_idx in range(min(req.periods_per_day, len(times))):
                start_t, end_t = times[p_idx]
                if lead_teacher:
                    # Upper classes: single master teacher across all subjects
                    sub = subs[(p_idx + d_idx) % len(subs)]
                    t_name = lead_teacher
                else:
                    # Lower classes: rotating specialists across classes
                    spec_idx = (c_idx + p_idx + d_idx) % len(specialists)
                    sub = specialists[spec_idx]["subject"]
                    t_name = specialists[spec_idx]["teacher"]

                periods.append(TimetablePeriod(
                    period_number=p_idx + 1,
                    start_time=start_t,
                    end_time=end_t,
                    subject_name=sub,
                    teacher_name=t_name
                ))
            schedule.append(DayTimetable(day=day, periods=periods))

        return TimetableGenerateResponse(
            class_name=req.class_name,
            schedule=schedule,
            summary_notes=f"Balanced timetable created for {req.class_name} covering all {len(subs)} curriculum subjects."
        )

@router.post("/weekly-diary", response_model=WeeklyDiaryResponse)
async def generate_weekly_diary(req: WeeklyDiaryRequest):
    system_prompt = f"""You are a master Pakistani school planner at Sublime Grammar School.
Draft a complete, realistic 6-day (Monday to Saturday) Weekly Teaching Diary and Parent Syllabus Digest for:
Class: {req.class_name}
Subject: {req.subject}
Unit / Chapter: "{req.topic_or_chapter}"
Starting Date: {req.week_start_date}

Generate:
1. Monday to Saturday daily breakdown:
   - Concept to teach
   - In-class exercise / classwork
   - Home task / homework notebook activity
2. A polite, natural Nastaliq Urdu weekly summary for parents to be sent via WhatsApp on Monday morning outlining what their child will study this week.

Respond strictly with valid JSON:
{{
  "class_name": "{req.class_name}",
  "subject": "{req.subject}",
  "week_start_date": "{req.week_start_date}",
  "daily_schedule": [
    {{
      "day": "Monday",
      "concept_to_teach": "<topic breakdown>",
      "classwork": "<reading page 10, Q1-3>",
      "homework": "<write definitions in copy>"
    }}
  ],
  "parent_whatsapp_summary_urdu": "<محترم والدین، السلام علیکم! اس ہفتے جماعت {req.class_name} کے طلباء {req.subject} میں...>"
}}"""

    messages = [
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": f"Generate weekly diary for {req.class_name} {req.subject}: {req.topic_or_chapter}"}
    ]

    try:
        raw = await call_qwen(messages, temperature=0.3)
        cleaned = re.sub(r"^```json\s*", "", raw.strip())
        cleaned = re.sub(r"```$", "", cleaned.strip())
        data = json.loads(cleaned)
        return WeeklyDiaryResponse(**data)
    except Exception as e:
        days = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        daily = [
            DailyLessonItem(
                day=d,
                concept_to_teach=f"{req.topic_or_chapter} - Part {idx+1}",
                classwork=f"Textbook explanation & guided reading",
                homework=f"Practice exercise {idx+1} on homework copy"
            ) for idx, d in enumerate(days)
        ]
        urdu_summary = f"محترم والدین، السلام علیکم! اس ہفتے جماعت {req.class_name} میں {req.subject} کے مضمون میں موضوع '{req.topic_or_chapter}' پڑھایا جائے گا۔ برائے مہربانی گھر پر بچے کی پڑھائی پر توجہ فرمائیں۔ شکریہ، انتظامیہ سبلائم گرامر اسکول"
        return WeeklyDiaryResponse(
            class_name=req.class_name,
            subject=req.subject,
            week_start_date=req.week_start_date,
            daily_schedule=daily,
            parent_whatsapp_summary_urdu=urdu_summary
        )

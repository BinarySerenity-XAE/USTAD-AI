import json
import re
from fastapi import APIRouter
from pydantic import BaseModel
from typing import Optional, Dict, Any
from services.qwen_service import call_qwen
from services.safety_guard import check_classroom_safety

router = APIRouter(prefix="/voice", tags=["Ustad Bol Voice Assistant & Voice-to-Admin"])

class VoiceCommandRequest(BaseModel):
    transcript: str
    current_role: str = "teacher"  # "teacher" or "admin"
    active_class: Optional[str] = "Class 5"

class VoiceCommandResponse(BaseModel):
    action: str  # "navigate", "info", "action_performed"
    target_route: str  # "homework", "attendance", "lesson_plan", "paper_grader", "oral_exam", "roleplay", "timetable", "report_card", "assembly", "parent_comms"
    class_name: Optional[str] = None
    subject: Optional[str] = None
    spoken_reply_urdu: str
    spoken_reply_english: str

class VoiceNoteRequest(BaseModel):
    student_name: str
    class_name: str
    teacher_voice_transcript: str

class VoiceNoteResponse(BaseModel):
    student_name: str
    class_name: str
    formalized_english_note: str
    formalized_urdu_note: str
    category: str  # "Academic", "Behavior", "Attendance", "Appreciation"
    recommended_action: str

@router.post("/command", response_model=VoiceCommandResponse)
async def process_voice_command(req: VoiceCommandRequest):
    is_safe, redirect = check_classroom_safety(req.transcript)
    if not is_safe:
        return VoiceCommandResponse(
            action="info",
            target_route="none",
            spoken_reply_urdu="برائے مہربانی تعلیمی امور کے متعلق بات کریں۔",
            spoken_reply_english=redirect
        )

    t = req.transcript.lower().strip()

    # Fast keyword heuristics for instant response & offline resilience
    if any(k in t for k in ["homework", "ہوم ورک", "ڈائری", "diary", "گھر کا کام"]):
        if req.current_role == "admin":
            return VoiceCommandResponse(
                action="none",
                target_route="none",
                spoken_reply_urdu="معذرت ایڈمن صاحب! ہوم ورک کا سیکشن صرف اساتذہ کے لیے ہے۔",
                spoken_reply_english="Homework management is only accessible in Teacher mode."
            )
        return VoiceCommandResponse(
            action="navigate",
            target_route="homework",
            class_name=req.active_class,
            spoken_reply_urdu=f"جی استاد جی! {req.active_class or ''} کا ہوم ورک اور ڈائری کاپی کھولی جا رہی ہے۔",
            spoken_reply_english="Opening homework and diary register."
        )
    elif any(k in t for k in ["staff attendance", "teacher attendance", "عملہ حاضری", "اساتذہ حاضری", "اسٹاف حاضری"]):
        return VoiceCommandResponse(
            action="navigate",
            target_route="staff_attendance",
            class_name=req.active_class,
            spoken_reply_urdu="جی استاد جی! اساتذہ و عملہ کی حاضری کھولی جا رہی ہے۔",
            spoken_reply_english="Opening Staff Attendance register."
        )
    elif any(k in t for k in ["attendance", "حاضری", "roll call", "حاضر"]):
        if req.current_role == "admin" and any(k in t for k in ["staff", "teacher", "عملہ", "اساتذہ"]):
            return VoiceCommandResponse(
                action="navigate",
                target_route="staff_attendance",
                class_name=req.active_class,
                spoken_reply_urdu="جی استاد جی! اساتذہ و عملہ کی حاضری کھولی جا رہی ہے۔",
                spoken_reply_english="Opening Staff Attendance."
            )
        return VoiceCommandResponse(
            action="navigate",
            target_route="attendance",
            class_name=req.active_class,
            spoken_reply_urdu="جی استاد جی! کلاس حاضری کا رجسٹر کھولا جا رہا ہے۔",
            spoken_reply_english="Opening daily attendance register."
        )
    elif any(k in t for k in ["mark", "marks", "نمبر", "مارکس", "رزلٹ", "امتحانی نمبر", "نمبرات", "score", "grades"]):
        return VoiceCommandResponse(
            action="navigate",
            target_route="marks",
            class_name=req.active_class,
            spoken_reply_urdu="جی استاد جی! طلباء کے امتحانی نمبرات کھولے جا رہے ہیں۔",
            spoken_reply_english="Opening examination marks."
        )
    elif any(k in t for k in ["certificate", "سرٹیفکیٹ", "سند", "اعزازی سند", "تعریفی سند", "award", "merit"]):
        return VoiceCommandResponse(
            action="navigate",
            target_route="certificate",
            class_name=req.active_class,
            spoken_reply_urdu="جی استاد جی! طلباء کے اعزازی سرٹیفکیٹ کھولے جا رہے ہیں۔",
            spoken_reply_english="Opening Student Merit Certificates."
        )
    elif any(k in t for k in ["fee", "fees", "فیس", "بقایا جات", "چالان", "challan", "dues"]):
        return VoiceCommandResponse(
            action="navigate",
            target_route="fee",
            class_name=req.active_class,
            spoken_reply_urdu="جی استاد جی! فیس مینجمنٹ اور بقایا جات کھولے جا رہے ہیں۔",
            spoken_reply_english="Opening Fee Management."
        )
    elif any(k in t for k in ["student", "students", "داخلہ", "داخلے", "طالب علم", "طلباء", "admission"]):
        return VoiceCommandResponse(
            action="navigate",
            target_route="students",
            class_name=req.active_class,
            spoken_reply_urdu="جی استاد جی! طلباء کا ریکارڈ اور داخلے کھولے جا رہے ہیں۔",
            spoken_reply_english="Opening Student Records."
        )
    elif any(k in t for k in ["paper", "پیپر", "test", "ٹیسٹ", "چیک", "کاپی چیک", "math grader", "ریاضی"]):
        return VoiceCommandResponse(
            action="navigate",
            target_route="paper_grader",
            class_name=req.active_class,
            spoken_reply_urdu="جی استاد جی! پیپر چیک کرنے کے لیے کیمرہ ویژن کھولا جا رہا ہے۔",
            spoken_reply_english="Opening AI Handwritten Paper Grader."
        )
    elif any(k in t for k in ["lesson plan", "لیسن پلان", "سبق", "منصوبہ", "یکساں نصاب", "worksheet", "ورک شیٹ"]):
        return VoiceCommandResponse(
            action="navigate",
            target_route="lesson_plan",
            class_name=req.active_class,
            spoken_reply_urdu="جی استاد جی! یکساں قومی نصاب کا لیسن پلانر کھولا جا رہا ہے۔",
            spoken_reply_english="Opening SNC Lesson Planner and Worksheets."
        )
    elif any(k in t for k in ["timetable", "ٹائم ٹیبل", "شیڈول", "schedule", "routine", "پیریڈ"]):
        return VoiceCommandResponse(
            action="navigate",
            target_route="timetable",
            class_name=req.active_class,
            spoken_reply_urdu="جی استاد جی! اسکول کا ماسٹر ٹائم ٹیبل کھولا جا رہا ہے۔",
            spoken_reply_english="Opening Master Timetable schedule."
        )
    elif any(k in t for k in ["report card", "رپورٹ کارڈ", "نتیجہ کارڈ", "کارنامہ", "terminal report"]):
        return VoiceCommandResponse(
            action="navigate",
            target_route="report_card",
            class_name=req.active_class,
            spoken_reply_urdu="جی استاد جی! سالانہ امتحانی رپورٹ کارڈ کھولا جا رہا ہے۔",
            spoken_reply_english="Opening Terminal Report Card generator."
        )
    elif any(k in t for k in ["oral exam", "زبانی امتحان", "زبانی", "وائیوا", "viva"]):
        return VoiceCommandResponse(
            action="navigate",
            target_route="oral_exam",
            class_name=req.active_class,
            spoken_reply_urdu="جی استاد جی! زبانی امتحانی معاون شروع کیا جا رہا ہے۔",
            spoken_reply_english="Starting AI Voice Oral Examiner."
        )
    elif any(k in t for k in ["roleplay", "role play", "مکالمہ", "کردار", "قائد", "اقبال", "سر سید"]):
        return VoiceCommandResponse(
            action="navigate",
            target_route="roleplay",
            class_name=req.active_class,
            spoken_reply_urdu="جی استاد جی! تاریخی کرداروں سے گفتگو شروع کی جا رہی ہے۔",
            spoken_reply_english="Starting Historical Roleplay."
        )
    elif any(k in t for k in ["assembly", "اسمبلی", "حدیث", "hadith", "morning talk", "مارننگ ٹاک", "صبح کی گفتگو"]):
        return VoiceCommandResponse(
            action="navigate",
            target_route="assembly",
            class_name=req.active_class,
            spoken_reply_urdu="جی استاد جی! صبح کی اسمبلی اور حدیث شریف کھولی جا رہی ہے۔",
            spoken_reply_english="Opening Morning Assembly AI Hub."
        )
    elif any(k in t for k in ["parent", "parents", "والدین", "واٹس ایپ", "whatsapp", "پیغامات"]):
        return VoiceCommandResponse(
            action="navigate",
            target_route="parent_comms",
            class_name=req.active_class,
            spoken_reply_urdu="جی استاد جی! والدین سے رابطہ اور پیغامات کھولے جا رہے ہیں۔",
            spoken_reply_english="Opening Parent Comms."
        )
    elif any(k in t for k in ["stem", "سٹیم", "سٹیم ہنٹ", "سائنس پروجیکٹ"]):
        return VoiceCommandResponse(
            action="navigate",
            target_route="stem_hunt",
            class_name=req.active_class,
            spoken_reply_urdu="جی استاد جی! سٹیم ہنٹ سرگرمی کھولی جا رہی ہے۔",
            spoken_reply_english="Opening STEM Hunt."
        )
    elif any(k in t for k in ["settings", "setting", "سیٹنگز", "ترتیبات", "پروفائل"]):
        return VoiceCommandResponse(
            action="navigate",
            target_route="settings",
            class_name=req.active_class,
            spoken_reply_urdu="جی استاد جی! ترتیبات کا صفحہ کھولا جا رہا ہے۔",
            spoken_reply_english="Opening Settings."
        )

    # Advanced intent routing via Qwen-Max
    system_prompt = f"""You are 'Ustad Bol' (استاد بول), an intelligent Urdu-English hands-free voice assistant inside the Ustad-AI school app for Sublime Grammar School in Pakistan.
The user (role: {req.current_role}) just spoke this voice command:
"{req.transcript}"

Determine their pedagogical or operational intent.
Map to one of these routes:
- "attendance" (mark attendance, roll call)
- "marks" (class marks entry, exam marks, test results)
- "timetable" (class periods, timetable schedule)
- "report_card" (terminal results, marks card)
- "assembly" (morning assembly, daily hadith, morning talk)
- "homework" (assign homework, check notebooks - only if user role is teacher or asks for homework)
- "lesson_plan" (curriculum lesson planner, worksheets)
- "paper_grader" (check handwritten exam, grade math)
- "oral_exam" (voice viva testing)
- "roleplay" (Quaid, Iqbal, historical dialogue)
- "parent_comms" (whatsapp message to parents)
- "certificate" (student merit certificates)
- "fee" (fee management and challans)
- "students" (student records and admissions)
- "staff_attendance" (staff and teacher attendance)
- "none" (if the command is unrecognized, ambiguous, or not a school feature)

Generate an encouraging, brief confirmation in natural Urdu (جی استاد جی...) and English.

Respond strictly with valid JSON:
{{
  "action": "navigate",
  "target_route": "timetable",
  "class_name": "{req.active_class}",
  "subject": null,
  "spoken_reply_urdu": "<مختصر اور دلکش جوابی آواز>",
  "spoken_reply_english": "<brief confirmation>"
}}"""

    messages = [
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": req.transcript}
    ]

    try:
        raw = await call_qwen(messages, temperature=0.2)
        cleaned = re.sub(r"^```json\s*", "", raw.strip())
        cleaned = re.sub(r"```$", "", cleaned.strip())
        data = json.loads(cleaned)
        route = data.get("target_route", "none")
        if req.current_role == "admin" and route == "homework":
            data["target_route"] = "none"
            data["action"] = "none"
            data["spoken_reply_urdu"] = "معذرت ایڈمن صاحب! ہوم ورک کا سیکشن صرف اساتذہ کے لیے ہے۔"
            data["spoken_reply_english"] = "Homework management is only accessible in Teacher mode."
        return VoiceCommandResponse(**data)
    except Exception as e:
        return VoiceCommandResponse(
            action="none",
            target_route="none",
            class_name=req.active_class,
            spoken_reply_urdu="جی استاد جی! آپ کیا کھولنا چاہتے ہیں؟ برائے مہربانی اپنا حکم واضح فرمائیں۔",
            spoken_reply_english="Ji Ustad Ji! What would you like to open? Please specify your command."
        )

@router.post("/note", response_model=VoiceNoteResponse)
async def process_voice_note(req: VoiceNoteRequest):
    system_prompt = f"""You are the administrative registrar AI at Sublime Grammar School.
A teacher spoke a 30-second spontaneous voice note about a student:
Student: {req.student_name} ({req.class_name})
Voice Note Transcript: "{req.teacher_voice_transcript}"

Task:
1. Formalize the spoken observation into a clear, professional English academic record note.
2. Formalize into a polite, respectful Urdu note suitable for the student's file and parent conference.
3. Categorize (Academic, Behavior, Attendance, Appreciation).
4. Provide a 1-sentence recommended action for the teacher/principal.

Respond strictly with valid JSON:
{{
  "student_name": "{req.student_name}",
  "class_name": "{req.class_name}",
  "formalized_english_note": "<clear professional record note>",
  "formalized_urdu_note": "<شاندار اور باوقار اردو اندراج>",
  "category": "Academic",
  "recommended_action": "<1-sentence teacher intervention>"
}}"""

    messages = [
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": f"Formalize note for {req.student_name}: {req.teacher_voice_transcript}"}
    ]

    try:
        raw = await call_qwen(messages, temperature=0.3)
        cleaned = re.sub(r"^```json\s*", "", raw.strip())
        cleaned = re.sub(r"```$", "", cleaned.strip())
        data = json.loads(cleaned)
        return VoiceNoteResponse(**data)
    except Exception as e:
        return VoiceNoteResponse(
            student_name=req.student_name,
            class_name=req.class_name,
            formalized_english_note=f"Teacher recorded observation: {req.teacher_voice_transcript}",
            formalized_urdu_note=f"استاد کی زبانی مشاہداتی رپورٹ: {req.teacher_voice_transcript}",
            category="Academic",
            recommended_action="Follow up during next parent meeting."
        )

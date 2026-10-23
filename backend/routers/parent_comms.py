import json
import re
from fastapi import APIRouter
from pydantic import BaseModel
from typing import Dict, Any
from services.qwen_service import call_qwen

router = APIRouter(prefix="/parent-comms", tags=["Automated Urdu Parent Communication"])

class ParentCommsRequest(BaseModel):
    student_name: str
    class_name: str
    message_type: str  # 'attendance', 'fees', 'marks', 'general'
    context: Dict[str, Any] = {}

class ParentCommsResponse(BaseModel):
    urdu_message: str

from services.safety_guard import check_classroom_safety

@router.post("/generate", response_model=ParentCommsResponse)
async def generate_parent_message(req: ParentCommsRequest):
    all_text = f"{req.student_name} {req.message_type} " + " ".join(str(v) for v in req.context.values())
    is_safe, redirect = check_classroom_safety(all_text)
    if not is_safe:
        return ParentCommsResponse(urdu_message=redirect)
    context_str = "\n".join([f"- {k}: {v}" for k, v in req.context.items()]) if req.context else "Standard communication"

    system_prompt = f"""You are the administrative communications assistant for Sublime Grammar School (سبلائم گرامر اسکول) in Pakistan.
Draft a respectful, polite, and culturally empathetic Urdu message (نستعلیق انداز) intended to be sent to parents via WhatsApp or SMS.
School Name: سبلائم گرامر اسکول
Student Name: {req.student_name}
Class: {req.class_name}
Notice Type: {req.message_type.upper()}
Details:
{context_str}

CRITICAL RULES FOR RELATIONSHIP & TERMINOLOGY:
1. The recipient is the student's parent/guardian (محترم والدین / محترم والد صاحب).
2. The student "{req.student_name}" is the parent's CHILD / PUPIL (آپ کا بچہ / آپ کی بچی / آپ کا بیٹا / آپ کی بیٹی / آپ کے فرزند / آپ کی صاحبزادی).
3. ABSOLUTE PROHIBITION: NEVER use the word "اہلیہ" (which means wife) or "زوجہ" or "شوہر"! The student is a schoolchild, NOT a wife or spouse.
4. Correct School Name: ALWAYS write the school name strictly as "سبلائم گرامر اسکول" (no spaces inside سبلائم).
5. Message Guidelines:
   - Begin with: 'محترم والدین، السلام علیکم!'
   - Refer to student respectfully as their child/student: e.g. 'آپ کے بچے / آپ کے صاحبزادے / آپ کی صاحبزادی {req.student_name} (جماعت {req.class_name})...'
   - Clearly state the purpose of the message ({req.message_type}).
   - Maintain an encouraging, dignified, supportive tone.
   - End strictly with: 'شکریہ، انتظامیہ سبلائم گرامر اسکول'
6. Only output the final Urdu message text in proper Urdu script. Do not output English or markdown tags."""

    messages = [
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": f"Generate the WhatsApp notice in Urdu for student {req.student_name}."}
    ]

    try:
        reply = await call_qwen(messages, temperature=0.4)
        # Strip any formatting
        cleaned = re.sub(r"```(markdown|text)?", "", reply).replace("```", "").strip()
        # Defensive cleanup for terminology and school name
        cleaned = cleaned.replace("اہلیہ", "صاحبزادی").replace("زوجہ", "صاحبزادی")
        cleaned = cleaned.replace("سب لائم", "سبلائم").replace("سب لائِم", "سبلائم")
        return ParentCommsResponse(urdu_message=cleaned)
    except Exception as e:
        fallback = f"محترم والدین، السلام علیکم۔ مطلع کیا جاتا ہے کہ آپ کے بچے {req.student_name} کے حوالے سے اسکول ریکارڈ میں کچھ امور زیرِ توجہ ہیں۔ برائے مہربانی اسکول انتظامیہ سے رابطہ فرمائیں۔ شکریہ، انتظامیہ سبلائم گرامر اسکول۔"
        return ParentCommsResponse(urdu_message=fallback)

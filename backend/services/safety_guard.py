# c:\XC\backend\services\safety_guard.py
import re
from typing import Tuple

# Parental Control & School-Safety keyword patterns (English, Urdu, Roman Urdu)
PROHIBITED_PATTERNS = [
    # Adult / NSFW / Inappropriate
    r"\b(porn|sex|nude|naked|nsfw|erotic|xxx|boobs|penis|vagina)\b",
    r"\b(fuhsh|chudai|gandi|nangi|jinsi)\b",
    # Violence / Weapons / Harm
    r"\b(kill\s+yourself|suicide|how\s+to\s+make\s+a\s+bomb|terrorist|gun\s+attack|shoot\s+school)\b",
    r"\b(khudkushi|qatal|dhamaka|hathyar)\b",
    # Severe Profanity / Abuse / Bullying
    r"\b(fuck|shit|bitch|bastard|asshole|cunt|dick)\b",
    r"\b(kutta|kameena|kanjar|beghairat|randi|madarchod|bhenchod|harami|bhosdi)\b",
    # Drugs / Illicit substances
    r"\b(cocaine|heroin|meth|buy\s+drugs|charas|afeem|shisha)\b",
]

# Standard School Safety Response (English & Urdu)
SAFETY_REDIRECT_EN = (
    "🛡️ Classroom Parental Control: I am your school learning companion for Sublime Grammar School. "
    "I am strictly programmed to discuss safe, inspiring educational topics such as science, history, "
    "mathematics, literature, and general knowledge. Let's focus on our school studies!"
)

SAFETY_REDIRECT_UR = (
    "🛡️ اسکول حفاظتی رہنما: میں سبلائم گرامر اسکول کا تعلیمی معاون ہوں۔ "
    "میرا مقصد صرف محفوظ اور مفید تعلیمی موضوعات جیسے سائنس، تاریخ، ریاضی اور ادب پر رہنمائی فراہم کرنا ہے۔ "
    "آئیے اپنے اسباق اور پڑھائی پر توجہ دیں!"
)

CLASSROOM_SAFETY_SYSTEM_PROMPT = """
[CRITICAL PARENTAL CONTROL & CLASSROOM SAFETY POLICY]
You are operating inside a primary and secondary classroom at Sublime Grammar School, Pakistan.
1. NEVER generate, discuss, or acknowledge inappropriate, sexually explicit, vulgar, violent, or abusive content.
2. If a student or teacher asks anything unsuitable for school children, politely decline and redirect them to school curriculum topics (science, history, mathematics, literature).
3. Always maintain an encouraging, respectful, culturally appropriate, and uplifting educational tone.
"""

def check_classroom_safety(text: str) -> Tuple[bool, str]:
    """
    Evaluates input text against parental control and classroom safety policies.
    Returns (is_safe: bool, redirect_message: str)
    """
    if not text or not text.strip():
        return True, ""

    normalized = text.lower()
    for pattern in PROHIBITED_PATTERNS:
        if re.search(pattern, normalized, re.IGNORECASE):
            # Check if Urdu script is present
            is_urdu = bool(re.search(r"[\u0600-\u06FF]", text))
            return False, SAFETY_REDIRECT_UR if is_urdu else SAFETY_REDIRECT_EN

    return True, ""

import json
import re
from fastapi import APIRouter
from pydantic import BaseModel
from services.qwen_service import call_qwen

router = APIRouter(prefix="/roleplay", tags=["Whole-Class Roleplay"])

class RoleplayGenerateRequest(BaseModel):
    scenario: str
    class_name: str
    subject: str

class RoleplayGenerateResponse(BaseModel):
    script: str
    character: str

class RoleplayRespondRequest(BaseModel):
    scenario: str
    student_question: str
    character: str

class RoleplayRespondResponse(BaseModel):
    response: str

from services.safety_guard import check_classroom_safety

@router.post("/generate", response_model=RoleplayGenerateResponse)
async def generate_roleplay(req: RoleplayGenerateRequest):
    is_safe, redirect = check_classroom_safety(f"{req.scenario} {req.subject}")
    if not is_safe:
        return RoleplayGenerateResponse(
            script=redirect,
            character="Safety Guard"
        )
    system_prompt = f"""You are creating an engaging, whole-class interactive roleplay for {req.class_name} students at Sublime Grammar School.
Subject: {req.subject}
Scenario / Character: {req.scenario}

Write a dramatic, exciting 3-4 paragraph introductory monologue that the teacher will read aloud or play via speaker to the entire class.
The character should introduce who they are, describe a defining moment from their life or nature, and invite the students to ask questions.
Make it inspiring, educational, and age-appropriate for Pakistani school students.

Respond ONLY with valid JSON:
{{
  "character": "{req.scenario}",
  "script": "<engaging monologue script with emotion and vivid storytelling>"
}}"""

    messages = [
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": f"Generate the introduction script for {req.scenario}."}
    ]

    try:
        raw_output = await call_qwen(messages, temperature=0.7)
        cleaned = re.sub(r"^```json\s*", "", raw_output.strip())
        cleaned = re.sub(r"```$", "", cleaned.strip())
        data = json.loads(cleaned)
        return RoleplayGenerateResponse(
            script=data.get("script", f"Greetings young scholars of {req.class_name}! I am {req.scenario}."),
            character=data.get("character", req.scenario)
        )
    except Exception as e:
        return RoleplayGenerateResponse(
            script=f"Assalam-o-Alaikum students of {req.class_name}! I am {req.scenario}. Today, I am here to share my knowledge with you. What would you like to ask me?",
            character=req.scenario
        )

@router.post("/respond", response_model=RoleplayRespondResponse)
async def respond_to_student(req: RoleplayRespondRequest):
    is_safe, redirect = check_classroom_safety(req.student_question)
    if not is_safe:
        return RoleplayRespondResponse(response=redirect)
    system_prompt = f"""You are roleplaying directly in character as: {req.character} in the scenario: {req.scenario} for students at Sublime Grammar School.
A Pakistani school student has just asked you a question from their desk.
Stay in character! Speak warmly, passionately, and clearly. Keep your response to 2 to 3 sentences so it can easily be spoken aloud in class over a speaker.
If the student asks in Urdu or the character is Pakistani/historic, use authentic, natural conversational Urdu (زبانی گفتگو کی آسان اور دلکش اردو) with warm inflection and natural punctuation pauses so speech sounds human and engaging, not robotic."""

    messages = [
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": f"Student asks: \"{req.student_question}\""}
    ]

    try:
        reply = await call_qwen(messages, temperature=0.7)
        return RoleplayRespondResponse(response=reply.strip())
    except Exception as e:
        return RoleplayRespondResponse(
            response=f"Ah, that is a marvelous question! Remember, true curiosity is the key to unlocking the secrets of the world."
        )

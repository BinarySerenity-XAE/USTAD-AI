import os
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from dotenv import load_dotenv

load_dotenv()

from routers import (
    oral_exam,
    stem_hunt,
    roleplay,
    parent_comms,
    analytics,
    lesson_plan,
    homework,
    timetable,
    report_card,
    parent_portal,
    certificate,
    voice_assistant,
    sync,
)

app = FastAPI(
    title="Ustad-AI Backend",
    description="Alibaba Cloud DashScope (Qwen-Max / Qwen3-VL) AI Engine for Sublime Grammar School",
    version="2.0.0"
)

# CORS configuration for Flutter Web (localhost) and mobile apps
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include Routers
app.include_router(oral_exam.router)
app.include_router(stem_hunt.router)
app.include_router(roleplay.router)
app.include_router(parent_comms.router)
app.include_router(analytics.router)
app.include_router(lesson_plan.router)
app.include_router(homework.router)
app.include_router(timetable.router)
app.include_router(report_card.router)
app.include_router(parent_portal.router)
app.include_router(certificate.router)
app.include_router(voice_assistant.router)
app.include_router(sync.router)

from fastapi.responses import RedirectResponse

@app.get("/parent")
async def parent_shortcut():
    return RedirectResponse(url="/parent/view")

@app.get("/health")
async def health_check():
    return {
        "status": "ok",
        "school": "Sublime Grammar School",
        "dashscope_configured": bool(os.getenv("DASHSCOPE_API_KEY")),
        "model": f"{os.getenv('DASHSCOPE_MODEL', 'qwen-max')} & {os.getenv('DASHSCOPE_VL_MODEL', 'qwen3-vl-plus')}"
    }

@app.get("/")
async def root():
    return {
        "app": "Ustad-AI AI Engine",
        "powered_by": "Alibaba Cloud DashScope (Bailian)",
        "school": "Sublime Grammar School",
        "docs": "/docs"
    }

if __name__ == "__main__":
    import uvicorn
    port = int(os.getenv("PORT", 8000))
    uvicorn.run("main:app", host="0.0.0.0", port=port, reload=True)

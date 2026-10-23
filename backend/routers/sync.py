import os
import json
import time
from fastapi import APIRouter
from pydantic import BaseModel
from typing import List, Dict, Any, Optional

router = APIRouter(prefix="/sync", tags=["Cloud Data Synchronization"])

DATA_FILE = os.path.join(os.path.dirname(os.path.dirname(__file__)), "data", "synced_school_data.json")
os.makedirs(os.path.dirname(DATA_FILE), exist_ok=True)

# In-memory synchronized store
SYNC_STORE: Dict[str, Any] = {
    "last_sync": time.strftime("%Y-%m-%d %H:%M:%S"),
    "students": [],
    "attendance": [],
    "marks": [],
    "homework": [],
    "homework_checks": [],
    "fees": [],
    "timetables": [],
    "weekly_diaries": []
}

def load_synced_data():
    global SYNC_STORE
    if os.path.exists(DATA_FILE):
        try:
            with open(DATA_FILE, "r", encoding="utf-8") as f:
                SYNC_STORE = json.load(f)
        except Exception:
            pass

def save_synced_data():
    try:
        with open(DATA_FILE, "w", encoding="utf-8") as f:
            json.dump(SYNC_STORE, f, ensure_ascii=False, indent=2)
    except Exception:
        pass

load_synced_data()

class SyncPayload(BaseModel):
    device_id: Optional[str] = "Teacher_Phone_01"
    school_name: str = "Sublime Grammar School"
    students: List[Dict[str, Any]] = []
    attendance: List[Dict[str, Any]] = []
    marks: List[Dict[str, Any]] = []
    homework: List[Dict[str, Any]] = []
    homework_checks: List[Dict[str, Any]] = []
    fees: List[Dict[str, Any]] = []
    timetables: List[Dict[str, Any]] = []
    weekly_diaries: List[Dict[str, Any]] = []

@router.post("/push")
async def push_sync(payload: SyncPayload):
    global SYNC_STORE
    SYNC_STORE["last_sync"] = time.strftime("%Y-%m-%d %H:%M:%S")
    SYNC_STORE["school_name"] = payload.school_name
    
    if payload.students:
        SYNC_STORE["students"] = payload.students
    if payload.attendance:
        SYNC_STORE["attendance"] = payload.attendance
    if payload.marks:
        SYNC_STORE["marks"] = payload.marks
    if payload.homework:
        SYNC_STORE["homework"] = payload.homework
    if payload.homework_checks:
        SYNC_STORE["homework_checks"] = payload.homework_checks
    if payload.fees:
        SYNC_STORE["fees"] = payload.fees
    if payload.timetables:
        SYNC_STORE["timetables"] = payload.timetables
    if payload.weekly_diaries:
        SYNC_STORE["weekly_diaries"] = payload.weekly_diaries

    save_synced_data()

    # Also dynamically update parent portal SAMPLE_FAMILIES so parent view reflects live synced data!
    try:
        from routers.parent_portal import update_parent_data_from_sync
        update_parent_data_from_sync(SYNC_STORE)
    except Exception:
        pass

    return {
        "status": "success",
        "synced_at": SYNC_STORE["last_sync"],
        "records_synced": {
            "students": len(SYNC_STORE["students"]),
            "attendance": len(SYNC_STORE["attendance"]),
            "marks": len(SYNC_STORE["marks"]),
            "homework": len(SYNC_STORE["homework"]),
            "homework_checks": len(SYNC_STORE["homework_checks"]),
            "fees": len(SYNC_STORE["fees"])
        }
    }

@router.get("/pull")
async def pull_sync():
    return {
        "status": "success",
        "last_sync": SYNC_STORE.get("last_sync"),
        "data": SYNC_STORE
    }

@router.get("/status")
async def sync_status():
    return {
        "online": True,
        "school": "Sublime Grammar School",
        "last_sync": SYNC_STORE.get("last_sync"),
        "total_students": len(SYNC_STORE.get("students", [])),
        "total_attendance": len(SYNC_STORE.get("attendance", [])),
        "total_marks": len(SYNC_STORE.get("marks", [])),
        "total_homework": len(SYNC_STORE.get("homework", []))
    }

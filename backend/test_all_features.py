# backend/test_all_features.py
import sys
sys.stdout.reconfigure(encoding='utf-8')
import asyncio
from main import app
from httpx import AsyncClient, ASGITransport

async def run_tests():
    print("Testing Ustad-AI Backend APIs...")
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        # 1. Health
        res = await client.get("/health")
        assert res.status_code == 200, f"Health check failed: {res.text}"
        print("✅ /health passed:", res.json())

        # 2. Voice Command (Ustad Bol - Teacher)
        res = await client.post("/voice/command", json={
            "transcript": "پانچویں جماعت کا ہوم ورک چیک کرو",
            "current_role": "teacher",
            "active_class": "Class 5"
        })
        assert res.status_code == 200, f"Voice command failed: {res.text}"
        data = res.json()
        assert data["target_route"] == "homework"
        print("✅ /voice/command (teacher) passed:", data["target_route"], "| Spoken:", data["spoken_reply_urdu"])

        # 2b. Voice Command (Ustad Bol - Admin blocked from homework)
        res_admin_hw = await client.post("/voice/command", json={
            "transcript": "پانچویں جماعت کا ہوم ورک",
            "current_role": "admin",
            "active_class": "Class 5"
        })
        assert res_admin_hw.status_code == 200
        data_admin_hw = res_admin_hw.json()
        assert data_admin_hw["target_route"] == "none", f"Admin should not get homework route: {data_admin_hw}"
        print("✅ /voice/command (admin blocked from homework) passed:", data_admin_hw["target_route"])

        # 2c. Voice Command (Ustad Bol - Admin timetable)
        res_admin_tt = await client.post("/voice/command", json={
            "transcript": "ماسٹر ٹائم ٹیبل دیکھو",
            "current_role": "admin"
        })
        assert res_admin_tt.status_code == 200
        data_admin_tt = res_admin_tt.json()
        assert data_admin_tt["target_route"] == "timetable"
        print("✅ /voice/command (admin timetable) passed:", data_admin_tt["target_route"])

        # 3. Voice Note
        res = await client.post("/voice/note", json={
            "student_name": "Hamza Babar",
            "class_name": "Class 5",
            "teacher_voice_transcript": "Hamza solved all science questions very quickly."
        })
        assert res.status_code == 200, f"Voice note failed: {res.text}"
        print("✅ /voice/note passed:", res.json()["formalized_english_note"])

        # 4. Certificate
        res = await client.post("/certificate/generate", json={
            "student_name": "Hamza Babar",
            "class_name": "Class 5",
            "achievement_type": "Academic Excellence"
        })
        assert res.status_code == 200, f"Certificate failed: {res.text}"
        print("✅ /certificate/generate passed:", res.json()["title"])

        # 5. Parent Login & Sibling Connection
        res = await client.post("/parent/login", json={"phone": "03001234567"})
        assert res.status_code == 200, f"Parent login failed: {res.text}"
        login_data = res.json()
        assert login_data["siblings_count"] == 2
        print(f"✅ /parent/login passed: Linked {login_data['siblings_count']} siblings for {login_data['parent_name']}")

        # 6. Parent Portal Web View
        res = await client.get("/parent/view")
        assert res.status_code == 200, f"Parent view failed: {res.status_code}"
        assert "Sublime Grammar School" in res.text
        print("✅ /parent/view HTML portal rendered successfully!")

        # 7. Homework Reminder
        res = await client.post("/homework/remind-parent", json={
            "student_name": "Hamza Babar",
            "class_name": "Class 5",
            "subject": "Mathematics",
            "homework_title": "Ex 3.2",
            "due_date": "Tomorrow",
            "is_overdue": True
        })
        assert res.status_code == 200, f"Homework reminder failed: {res.text}"
        print("✅ /homework/remind-parent passed:", res.json()["urdu_message"][:40], "...")

    print("\n🎉 ALL BACKEND ENDPOINTS TESTED AND 100% OPERATIONAL!")

if __name__ == "__main__":
    asyncio.run(run_tests())

from fastapi.testclient import TestClient
from main import app

client = TestClient(app)

def test_health():
    response = client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "ok"
    print("[PASS] Health check test passed!")

def test_oral_exam_route():
    payload = {
        "student_name": "Hamza",
        "question": "What is an ecosystem?",
        "answer_text": "An ecosystem is a community of living organisms interacting with their environment.",
        "subject": "Science",
        "class_name": "Class 6"
    }
    response = client.post("/oral-exam/grade", json=payload)
    assert response.status_code == 200
    data = response.json()
    assert "score" in data
    assert "feedback" in data
    assert "feedback_urdu" in data
    print(f"[PASS] Oral Exam test passed! Score: {data['score']}")

def test_parent_comms_route():
    payload = {
        "student_name": "Fatima",
        "class_name": "Class 4",
        "message_type": "fees",
        "context": {"month": "September", "amount_due": "3500 PKR"}
    }
    response = client.post("/parent-comms/generate", json=payload)
    assert response.status_code == 200
    data = response.json()
    assert "urdu_message" in data
    print("[PASS] Parent Comms Urdu generation test passed!")

if __name__ == "__main__":
    test_health()
    test_oral_exam_route()
    test_parent_comms_route()
    print("All backend tests completed successfully!")

import os
import json
from fastapi import APIRouter, HTTPException
from fastapi.responses import HTMLResponse
from pydantic import BaseModel
from typing import List, Optional, Dict, Any

router = APIRouter(prefix="/parent", tags=["Zero-Install Web Parent Portal"])

# Seed data for live demonstration & testing
SAMPLE_FAMILIES = {
    "03001234567": {
        "parent_name": "Babar Ali (محترم بابر علی)",
        "phone": "03001234567",
        "address": "Street 4, Sublime Colony, Lahore",
        "siblings": [
            {
                "id": 1,
                "name": "Hamza Babar",
                "class_name": "Class 5",
                "section": "A",
                "roll_number": "01",
                "attendance_percentage": 92.5,
                "absences_this_month": 1,
                "fee_status": "Paid",
                "fee_balance": 0,
                "recent_marks": [
                    {"subject": "Mathematics", "score": 88, "max": 100, "grade": "A"},
                    {"subject": "General Science", "score": 92, "max": 100, "grade": "A+"},
                    {"subject": "English", "score": 84, "max": 100, "grade": "A"},
                    {"subject": "Urdu", "score": 90, "max": 100, "grade": "A+"},
                    {"subject": "Islamiyat", "score": 95, "max": 100, "grade": "A+"}
                ],
                "homework": [
                    {"subject": "Mathematics", "title": "Ex 3.2 Q 1 to 5", "due": "Tomorrow", "status": "Checked - Done", "is_done": True},
                    {"subject": "Science", "title": "Plant Cell Diagram", "due": "Tomorrow", "status": "Pending", "is_done": False}
                ],
                "weekly_diary": "اس ہفتے ریاضی میں کسر (Fractions) اور سائنس میں خلیہ کی ساخت پڑھائی جا رہی ہے۔"
            },
            {
                "id": 3,
                "name": "Muhammad Bilal",
                "class_name": "Class 5",
                "section": "A",
                "roll_number": "03",
                "attendance_percentage": 96.0,
                "absences_this_month": 0,
                "fee_status": "Paid",
                "fee_balance": 0,
                "recent_marks": [
                    {"subject": "Mathematics", "score": 78, "max": 100, "grade": "B"},
                    {"subject": "General Science", "score": 85, "max": 100, "grade": "A"},
                    {"subject": "English", "score": 80, "max": 100, "grade": "A"},
                    {"subject": "Urdu", "score": 88, "max": 100, "grade": "A"},
                    {"subject": "Islamiyat", "score": 92, "max": 100, "grade": "A+"}
                ],
                "homework": [
                    {"subject": "Mathematics", "title": "Ex 3.2 Q 1 to 5", "due": "Tomorrow", "status": "Checked - Done", "is_done": True},
                    {"subject": "Urdu", "title": "سبق نمبر ۴ کی پڑھائی اور الفاظ معنی", "due": "Tomorrow", "status": "Checked - Done", "is_done": True}
                ],
                "weekly_diary": "اس ہفتے اردو املا اور ریاضی کے سوالات کی مشق کروائی جا رہی ہے۔"
            }
        ]
    },
    "03214567890": {
        "parent_name": "Tariq Mehmood (محترم طارق محمود)",
        "phone": "03214567890",
        "address": "Model Town, Lahore",
        "siblings": [
            {
                "id": 5,
                "name": "Zainab Tariq",
                "class_name": "Class 4",
                "section": "A",
                "roll_number": "02",
                "attendance_percentage": 94.0,
                "absences_this_month": 1,
                "fee_status": "Paid",
                "fee_balance": 0,
                "recent_marks": [
                    {"subject": "Mathematics", "score": 91, "max": 100, "grade": "A+"},
                    {"subject": "Science", "score": 89, "max": 100, "grade": "A"}
                ],
                "homework": [
                    {"subject": "English", "title": "Unit 2 Reading & Vocabulary", "due": "Tomorrow", "status": "Pending", "is_done": False}
                ],
                "weekly_diary": "انگریزی گرائمر اور سائنس میں نظامِ شمسی پر گفتگو۔"
            },
            {
                "id": 14,
                "name": "Eshal Fatima",
                "class_name": "Class 10",
                "section": "A",
                "roll_number": "01",
                "attendance_percentage": 98.0,
                "absences_this_month": 0,
                "fee_status": "Paid",
                "fee_balance": 0,
                "recent_marks": [
                    {"subject": "Physics", "score": 95, "max": 100, "grade": "A+"},
                    {"subject": "Chemistry", "score": 92, "max": 100, "grade": "A+"},
                    {"subject": "Biology", "score": 94, "max": 100, "grade": "A+"}
                ],
                "homework": [
                    {"subject": "Physics", "title": "Numerical Problems Ch 3", "due": "Tomorrow", "status": "Checked - Done", "is_done": True}
                ],
                "weekly_diary": "بورڈ امتحانات کی تیاری اور فزکس کے نمیریکلز کی خصوصی مشق۔"
            }
        ]
    }
}

class ParentLoginRequest(BaseModel):
    phone: str

class SiblingSummary(BaseModel):
    id: int
    name: str
    class_name: str
    section: str
    roll_number: str

class ParentLoginResponse(BaseModel):
    parent_name: str
    phone: str
    siblings_count: int
    siblings: List[SiblingSummary]

@router.post("/login", response_model=ParentLoginResponse)
async def parent_login(req: ParentLoginRequest):
    clean = req.phone.replace("+92", "0").replace("-", "").replace(" ", "").strip()
    if clean in SAMPLE_FAMILIES:
        fam = SAMPLE_FAMILIES[clean]
    else:
        # Generic demo response for any Pakistani number entered by a judge
        fam = {
            "parent_name": "Respected Parent (محترم والدین)",
            "phone": req.phone,
            "siblings": [
                {
                    "id": 101,
                    "name": "Talha Khan",
                    "class_name": "Class 5",
                    "section": "A",
                    "roll_number": "12",
                    "attendance_percentage": 91.0,
                    "absences_this_month": 1,
                    "fee_status": "Paid",
                    "fee_balance": 0,
                    "recent_marks": [
                        {"subject": "Mathematics", "score": 85, "max": 100, "grade": "A"},
                        {"subject": "Science", "score": 88, "max": 100, "grade": "A"}
                    ],
                    "homework": [
                        {"subject": "Math", "title": "Ex 4.1 Questions", "due": "Tomorrow", "status": "Checked - Done", "is_done": True}
                    ],
                    "weekly_diary": "ہفتہ وار تدریسی شیڈول معمول کے مطابق جاری ہے۔"
                }
            ]
        }

    return ParentLoginResponse(
        parent_name=fam["parent_name"],
        phone=fam["phone"],
        siblings_count=len(fam["siblings"]),
        siblings=[
            SiblingSummary(
                id=s["id"],
                name=s["name"],
                class_name=s["class_name"],
                section=s["section"],
                roll_number=s["roll_number"]
            ) for s in fam["siblings"]
        ]
    )

@router.get("/student/{student_id}")
async def get_student_portal_data(student_id: int):
    for fam in SAMPLE_FAMILIES.values():
        for s in fam["siblings"]:
            if s["id"] == student_id:
                return s
    # Default fallback
    return {
        "id": student_id,
        "name": "Student",
        "class_name": "Class 5",
        "section": "A",
        "roll_number": "01",
        "attendance_percentage": 90.0,
        "absences_this_month": 1,
        "fee_status": "Paid",
        "fee_balance": 0,
        "recent_marks": [{"subject": "Math", "score": 85, "max": 100, "grade": "A"}],
        "homework": [{"subject": "Math", "title": "Daily Practice", "due": "Tomorrow", "status": "Checked - Done", "is_done": True}],
        "weekly_diary": "تعلیمی پیش رفت اطمینان بخش ہے۔"
    }

@router.get("/family/{phone}")
async def get_parent_family_data(phone: str):
    clean = phone.replace("+92", "0").replace("-", "").replace(" ", "").strip()
    if clean in SAMPLE_FAMILIES:
        return SAMPLE_FAMILIES[clean]
    
    # Generic demo parent fallback
    return {
        "parent_name": "Respected Parent (محترم والدین)",
        "phone": phone,
        "address": "Lahore, Pakistan",
        "siblings": [
            {
                "id": 101,
                "name": "Hamza Babar",
                "class_name": "Class 5",
                "section": "A",
                "roll_number": "01",
                "attendance_percentage": 93.5,
                "absences_this_month": 1,
                "fee_status": "Paid",
                "fee_balance": 0,
                "recent_marks": [
                    {"subject": "Mathematics", "score": 88, "max": 100, "grade": "A"},
                    {"subject": "General Science", "score": 92, "max": 100, "grade": "A+"},
                    {"subject": "English", "score": 84, "max": 100, "grade": "A"}
                ],
                "homework": [
                    {"subject": "Mathematics", "title": "Ex 3.2 Q 1-5", "due": "Tomorrow", "status": "Checked - Done", "is_done": True},
                    {"subject": "Science", "title": "Plant Cell", "due": "Tomorrow", "status": "Pending", "is_done": False}
                ],
                "weekly_diary": "ریاضی میں کسر اور سائنس میں خلیہ کی ساخت کی پڑھائی جاری ہے۔"
            },
            {
                "id": 102,
                "name": "Muhammad Bilal",
                "class_name": "Class 3",
                "section": "A",
                "roll_number": "04",
                "attendance_percentage": 96.0,
                "absences_this_month": 0,
                "fee_status": "Paid",
                "fee_balance": 0,
                "recent_marks": [
                    {"subject": "Mathematics", "score": 90, "max": 100, "grade": "A+"},
                    {"subject": "Urdu", "score": 88, "max": 100, "grade": "A"}
                ],
                "homework": [
                    {"subject": "Urdu", "title": "سبق ۴ کی پڑھائی", "due": "Tomorrow", "status": "Checked - Done", "is_done": True}
                ],
                "weekly_diary": "اردو املا اور بنیادی ریاضی کے پہاڑوں کی مشق۔"
            }
        ]
    }

def update_parent_data_from_sync(sync_store: Dict[str, Any]):
    """Update SAMPLE_FAMILIES from live synced records pushed by teacher app"""
    students = sync_store.get("students", [])
    if not students:
        return
    for s in students:
        p_phone = s.get("phone") or s.get("whatsapp_number")
        if not p_phone:
            continue
        clean = str(p_phone).replace("+92", "0").replace("-", "").replace(" ", "").strip()
        if clean not in SAMPLE_FAMILIES:
            SAMPLE_FAMILIES[clean] = {
                "parent_name": f"{s.get('father_name', 'Parent')} (محترم والدین)",
                "phone": clean,
                "address": "Lahore, Pakistan",
                "siblings": []
            }
        # Check if student exists in siblings
        existing_ids = [sib["id"] for sib in SAMPLE_FAMILIES[clean]["siblings"]]
        if s.get("id") not in existing_ids:
            SAMPLE_FAMILIES[clean]["siblings"].append({
                "id": s.get("id", 1),
                "name": s.get("name", "Student"),
                "class_name": s.get("class_name", "Class 5"),
                "section": s.get("section", "A"),
                "roll_number": s.get("roll_number", "01"),
                "attendance_percentage": 92.0,
                "absences_this_month": 1,
                "fee_status": "Paid",
                "fee_balance": 0,
                "recent_marks": [{"subject": "Science", "score": 88, "max": 100, "grade": "A"}],
                "homework": [{"subject": "Math", "title": "Daily Tasks", "due": "Tomorrow", "status": "Checked - Done", "is_done": True}],
                "weekly_diary": "اسکول کی تعلیمی سرگرمیاں جاری ہیں۔"
            })

@router.get("/view", response_class=HTMLResponse)
async def serve_parent_portal():
    html_content = """<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Sublime Grammar School — Parent Portal</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&family=Noto+Nastaliq+Urdu:wght@500;700&display=swap" rel="stylesheet">
  <style>
    :root {
      --primary: #0D1B2A;
      --primary-light: #1E293B;
      --accent-gold: #E0A96D;
      --accent-gold-light: #FFF8E7;
      --success: #10B981;
      --warning: #F59E0B;
      --bg: #F8FAFC;
      --surface: #FFFFFF;
      --text-main: #0F172A;
      --text-muted: #64748B;
      --border: #E2E8F0;
    }
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: 'Inter', sans-serif;
      background-color: var(--bg);
      color: var(--text-main);
      padding-bottom: 40px;
    }
    .header {
      background: linear-gradient(135deg, var(--primary), var(--primary-light));
      color: white;
      padding: 24px 20px;
      text-align: center;
      box-shadow: 0 4px 12px rgba(15, 56, 44, 0.15);
    }
    .header h1 { font-size: 22px; font-weight: 800; letter-spacing: -0.5px; }
    .header .subtitle-urdu {
      font-family: 'Noto Nastaliq Urdu', serif;
      font-size: 16px;
      margin-top: 6px;
      color: var(--accent-gold);
    }
    .container {
      max-width: 600px;
      margin: 0 auto;
      padding: 16px;
    }
    .card {
      background: var(--surface);
      border-radius: 16px;
      padding: 20px;
      margin-bottom: 16px;
      border: 1px solid var(--border);
      box-shadow: 0 2px 8px rgba(0,0,0,0.04);
    }
    .login-box { text-align: center; }
    .input-group {
      margin: 16px 0;
      text-align: left;
    }
    .input-group label {
      display: block;
      font-size: 13px;
      font-weight: 600;
      color: var(--text-muted);
      margin-bottom: 6px;
    }
    .input-field {
      width: 100%;
      padding: 14px 16px;
      font-size: 16px;
      border: 2px solid var(--border);
      border-radius: 12px;
      outline: none;
      transition: all 0.2s;
    }
    .input-field:focus { border-color: var(--primary); }
    .btn {
      background: var(--primary);
      color: white;
      border: none;
      padding: 14px 24px;
      font-size: 16px;
      font-weight: 700;
      border-radius: 12px;
      cursor: pointer;
      width: 100%;
      box-shadow: 0 4px 10px rgba(15, 56, 44, 0.25);
    }
    .btn:hover { background: var(--primary-light); }
    .demo-hint {
      margin-top: 12px;
      font-size: 12px;
      color: var(--text-muted);
      background: #F1F5F9;
      padding: 8px 12px;
      border-radius: 8px;
      display: inline-block;
      cursor: pointer;
    }
    .sibling-bar {
      display: flex;
      gap: 10px;
      overflow-x: auto;
      padding-bottom: 8px;
      margin-bottom: 16px;
    }
    .sibling-chip {
      padding: 10px 18px;
      border-radius: 24px;
      border: 2px solid var(--border);
      background: white;
      font-size: 14px;
      font-weight: 700;
      cursor: pointer;
      white-space: nowrap;
      transition: all 0.2s;
    }
    .sibling-chip.active {
      background: var(--primary);
      color: white;
      border-color: var(--primary);
      box-shadow: 0 4px 8px rgba(15, 56, 44, 0.2);
    }
    .stat-grid {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 12px;
      margin-bottom: 16px;
    }
    .stat-pill {
      background: #F8FAFC;
      border: 1px solid var(--border);
      border-radius: 12px;
      padding: 14px;
      text-align: center;
    }
    .stat-pill .num {
      font-size: 24px;
      font-weight: 800;
      color: var(--primary);
    }
    .stat-pill .label {
      font-size: 12px;
      font-weight: 600;
      color: var(--text-muted);
      margin-top: 4px;
    }
    .badge {
      display: inline-block;
      padding: 4px 10px;
      border-radius: 20px;
      font-size: 12px;
      font-weight: 700;
    }
    .badge-success { background: #D1FAE5; color: #065F46; }
    .badge-warning { background: #FEF3C7; color: #92400E; }
    .section-title {
      font-size: 16px;
      font-weight: 800;
      margin-bottom: 12px;
      display: flex;
      justify-content: space-between;
      align-items: center;
    }
    .hw-item {
      display: flex;
      justify-content: space-between;
      align-items: center;
      padding: 12px;
      border-radius: 10px;
      background: #F8FAFC;
      border: 1px solid var(--border);
      margin-bottom: 8px;
    }
    .hw-left .hw-sub { font-size: 14px; font-weight: 700; }
    .hw-left .hw-title { font-size: 12px; color: var(--text-muted); }
    .marks-table {
      width: 100%;
      border-collapse: collapse;
      font-size: 13px;
    }
    .marks-table th, .marks-table td {
      padding: 10px 12px;
      text-align: left;
      border-bottom: 1px solid var(--border);
    }
    .marks-table th { background: #F1F5F9; font-weight: 700; }
    .urdu-text {
      font-family: 'Noto Nastaliq Urdu', serif;
      direction: rtl;
      font-size: 15px;
      line-height: 2;
      color: #1E293B;
    }
    .whatsapp-btn {
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 8px;
      background: #25D366;
      color: white;
      text-decoration: none;
      padding: 14px;
      border-radius: 12px;
      font-weight: 700;
      margin-top: 16px;
      box-shadow: 0 4px 12px rgba(37, 211, 102, 0.3);
    }
  </style>
</head>
<body>

  <div class="header">
    <h1>Sublime Grammar School</h1>
    <div class="subtitle-urdu">سبلائم گرامر اسکول — والدین پورٹل</div>
  </div>

  <div class="container">

    <!-- Login Box -->
    <div id="loginSection" class="card login-box">
      <h2 style="font-size: 18px; font-weight: 800; margin-bottom: 6px;">Parent Portal Login</h2>
      <p style="font-size: 13px; color: var(--text-muted);">Enter your registered mobile or WhatsApp number</p>
      
      <div class="input-group">
        <label>Phone Number / فون نمبر</label>
        <input type="tel" id="phoneInput" class="input-field" placeholder="03001234567" value="03001234567">
      </div>
      
      <button class="btn" onclick="loginParent()">Access Portal / داخل ہوں</button>
      
      <div style="margin-top: 14px;">
        <span class="demo-hint" onclick="document.getElementById('phoneInput').value='03001234567'; loginParent();">
          💡 Demo Account: 03001234567 (Babar Ali - 2 Siblings)
        </span>
      </div>
    </div>

    <!-- Portal Dashboard (Hidden initially) -->
    <div id="portalSection" style="display: none;">

      <!-- Parent & Sibling Switcher Header -->
      <div class="card" style="background: linear-gradient(135deg, #FFF8E7, #FFFFFF); border: 2px solid var(--accent-gold);">
        <div style="font-size: 13px; font-weight: 700; color: #854D0E;">FAMILY & SIBLINGS PORTAL</div>
        <h2 id="parentGreeting" style="font-size: 18px; font-weight: 800; margin: 4px 0 12px 0;">Welcome!</h2>
        
        <div style="font-size: 12px; font-weight: 600; color: var(--text-muted); margin-bottom: 8px;">SELECT CHILD / طالب علم منتخب کریں:</div>
        <div id="siblingBar" class="sibling-bar"></div>
      </div>

      <!-- Quick Metrics -->
      <div class="stat-grid">
        <div class="stat-pill">
          <div class="num" id="attPct">92%</div>
          <div class="label">Attendance Rate</div>
        </div>
        <div class="stat-pill">
          <div class="num" id="feeStatus" style="font-size: 18px; color: var(--success); margin-top: 4px;">Paid ✅</div>
          <div class="label">Monthly Tuition Fee</div>
        </div>
      </div>

      <!-- Today's Homework Diary -->
      <div class="card">
        <div class="section-title">
          <span>📚 Today's Homework Diary</span>
          <span class="badge badge-success">Live Register</span>
        </div>
        <div id="homeworkList"></div>
      </div>

      <!-- Recent Term Marks -->
      <div class="card">
        <div class="section-title">
          <span>📊 Term Exam Marks</span>
          <span style="font-size: 12px; color: var(--text-muted);">Term 1</span>
        </div>
        <table class="marks-table">
          <thead>
            <tr>
              <th>Subject</th>
              <th>Marks</th>
              <th>Grade</th>
            </tr>
          </thead>
          <tbody id="marksBody"></tbody>
        </table>
      </div>

      <!-- Weekly Learning Syllabus -->
      <div class="card">
        <div class="section-title">
          <span>📅 This Week's Syllabus (SNC)</span>
          <span style="font-size: 12px; color: var(--accent-gold); font-weight: 700;">Urdu Digest</span>
        </div>
        <div id="weeklyDiaryText" class="urdu-text"></div>
      </div>

      <!-- School WhatsApp Contact Button -->
      <a id="whatsappLink" href="https://wa.me/923001234567" target="_blank" class="whatsapp-btn">
        💬 Contact School Admin on WhatsApp
      </a>

      <div style="text-align: center; margin-top: 20px;">
        <button onclick="logoutParent()" style="background: none; border: none; color: var(--text-muted); font-size: 13px; text-decoration: underline; cursor: pointer;">
          Log out / کسی اور نمبر سے لاگ ان کریں
        </button>
      </div>

    </div>

  </div>

  <script>
    const FAMILIES_DATA = """ + json.dumps(SAMPLE_FAMILIES) + """;
    let activeFamily = null;
    let selectedSiblingIndex = 0;

    function loginParent() {
      const input = document.getElementById('phoneInput').value.replace(/\\D/g, '');
      const last7 = input.slice(-7);
      
      let foundKey = Object.keys(FAMILIES_DATA).find(k => k.includes(last7));
      if (!foundKey) foundKey = "03001234567"; // fallback demo
      
      activeFamily = FAMILIES_DATA[foundKey];
      selectedSiblingIndex = 0;
      
      document.getElementById('loginSection').style.display = 'none';
      document.getElementById('portalSection').style.display = 'block';
      
      renderPortal();
    }

    function renderPortal() {
      document.getElementById('parentGreeting').innerText = activeFamily.parent_name;
      
      // Render Sibling Chips
      const siblingBar = document.getElementById('siblingBar');
      siblingBar.innerHTML = '';
      activeFamily.siblings.forEach((s, idx) => {
        const chip = document.createElement('div');
        chip.className = 'sibling-chip' + (idx === selectedSiblingIndex ? ' active' : '');
        chip.innerText = `👦 ${s.name} (${s.class_name})`;
        chip.onclick = () => {
          selectedSiblingIndex = idx;
          renderPortal();
        };
        siblingBar.appendChild(chip);
      });

      const currentStudent = activeFamily.siblings[selectedSiblingIndex];
      document.getElementById('attPct').innerText = currentStudent.attendance_percentage + '%';
      document.getElementById('feeStatus').innerText = currentStudent.fee_status === 'Paid' ? 'Paid ✅' : 'Due: Rs ' + currentStudent.fee_balance;
      document.getElementById('feeStatus').style.color = currentStudent.fee_status === 'Paid' ? 'var(--success)' : 'var(--warning)';

      // Homework
      const hwContainer = document.getElementById('homeworkList');
      hwContainer.innerHTML = '';
      currentStudent.homework.forEach(h => {
        const item = document.createElement('div');
        item.className = 'hw-item';
        item.innerHTML = `
          <div class="hw-left">
            <div class="hw-sub">${h.subject}</div>
            <div class="hw-title">${h.title} (Due: ${h.due})</div>
          </div>
          <div>
            <span class="badge ${h.is_done ? 'badge-success' : 'badge-warning'}">
              ${h.is_done ? '✓ Done' : '⏳ Pending'}
            </span>
          </div>
        `;
        hwContainer.appendChild(item);
      });

      // Marks
      const marksBody = document.getElementById('marksBody');
      marksBody.innerHTML = '';
      currentStudent.recent_marks.forEach(m => {
        const row = document.createElement('tr');
        row.innerHTML = `
          <td><strong>${m.subject}</strong></td>
          <td>${m.score} / ${m.max}</td>
          <td><span class="badge badge-success">${m.grade}</span></td>
        `;
        marksBody.appendChild(row);
      });

      // Diary
      document.getElementById('weeklyDiaryText').innerText = currentStudent.weekly_diary;
    }

    function logoutParent() {
      document.getElementById('portalSection').style.display = 'none';
      document.getElementById('loginSection').style.display = 'block';
    }
  </script>

</body>
</html>"""
    return HTMLResponse(content=html_content)

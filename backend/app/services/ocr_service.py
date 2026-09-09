"""
OCR Service — Hybrid approach:
  Step 1: PyMuPDF converts PDF page → PNG image
  Step 2: Tesseract extracts raw text from image (free, local, fast)
  Step 3: GPT-4o-mini parses + corrects raw text → structured JSON

Two extraction modes based on project_type:
  'semester'  → single semester sheet  → extract that semester's subjects + SGPA
  'full_year' → combined sheet (SEM I + SEM II) → extract LATEST semester only + CGPA

Cost: ~$0.0004 per page → $3 = ~7,500 pages
"""
from typing import List, Dict, Any
import json
import re
import os
import shutil
import asyncio
import fitz
import pytesseract
from PIL import Image, ImageFilter, ImageEnhance
import io
from app.core.config import settings

# ── Prompt for SINGLE SEMESTER marksheet ──────────────────────────────────────
PROMPT_SEMESTER = """You are an expert at parsing Indian college marksheet OCR text.
The text was extracted by Tesseract OCR and may have errors. Fix them and return ONLY valid JSON.

MARKSHEET TYPE: Single Semester (one SEM block on the page)

FIELD IDENTIFICATION — CRITICAL:
The marksheet has these labeled fields near the top. Read the LABEL carefully:
  - "PRN" label → that value is the prn (usually 12 digits, e.g. 202103010076)
  - "Seat No" label → that value is the seat_no (usually 11 digits, e.g. 21151210002)
  - "Name" label → that value is the student name
  PRN and Seat No are DIFFERENT numbers. Do NOT put the same value in both fields.
  PRN is typically longer (12 digits starting with year e.g. 2021...).
  Seat No is typically shorter (11 digits e.g. 21151...).

COMMON OCR ERRORS TO FIX:
- PRN and Seat No are ALWAYS purely numeric. Fix letter-digit confusion:
  "O"→"0", "l"/"I"→"1", "S"→"5", "Z"→"2", "B"→"8", "G"→"6"
- Truncated digits: if PRN looks like 11 digits (e.g. 20210301007) check if last digit was cut — PRNs are 12 digits
- Names: fix missing spaces e.g. "SARIKAHEMANT" → "SARIKA HEMANT"
- Course codes: alphanumeric like "MTM101" — fix misreads
- Grades: only O, A+, A, B+, B, C, F are valid

JSON to return:
{
  "prn": "12 digit PRN from the PRN label",
  "seat_no": "11 digit seat number from the Seat No label",
  "name": "FULL NAME WITH SPACES",
  "program": "program name",
  "examination": "examination name",
  "semester": "semester label e.g. I SEMESTER",
  "sgpa": 0.00,
  "cgpa": 0.00,
  "status": "pass",
  "total_credits": 0.00,
  "total_egp": 0.00,
  "subject_marks": [
    {
      "sr_no": 1,
      "course_code": "MTM101",
      "course_name": "Research Methodology & IPR",
      "credits": 4.00,
      "grade_obtained": "A",
      "grade_point": 8.00,
      "earned_gp": 32.00,
      "remark": ""
    }
  ]
}

RULES:
1. Extract ALL subjects from the single semester table
2. status: lowercase "pass", "fail", or "atkt"
3. All numeric fields must be numbers not strings
4. PRN and Seat No must be digits only — they are DIFFERENT values, never the same
5. remark: use shown value (e.g. "E.X") or empty string ""
6. Missing fields: "" for strings, 0 for numbers
7. Return ONLY the JSON object

RAW OCR TEXT:
"""

# ── Prompt for FULL YEAR combined marksheet ────────────────────────────────────
PROMPT_FULL_YEAR = """You are an expert at parsing Indian college marksheet OCR text.
The text was extracted by Tesseract OCR and may have errors. Fix them and return ONLY valid JSON.

MARKSHEET TYPE: Full Year Combined (shows SEM I AND SEM II on same page)

COMMON OCR ERRORS TO FIX:
- PRN and Seat No are ALWAYS purely numeric. Fix letter-digit confusion:
  "O"→"0", "l"/"I"→"1", "S"→"5", "Z"→"2", "B"→"8", "G"→"6"
- Truncated digits: if PRN looks like 11 digits (e.g. 20210301007) the last digit was cut — PRNs are 12 digits
- Names: fix missing spaces e.g. "SARIKAHEMANT" → "SARIKA HEMANT"
- Course codes: alphanumeric like "MTC141" — fix misreads
- Grades: only O, A+, A, B+, B, C, F are valid

FIELD IDENTIFICATION — CRITICAL:
The marksheet has these labeled fields near the top. Read the LABEL carefully:
  - "PRN" label → that value is the prn (usually 12 digits, e.g. 202103010076)
  - "Seat No" label → that value is the seat_no (usually 11 digits, e.g. 21151210002)
  PRN and Seat No are DIFFERENT numbers. Do NOT put the same value in both fields.

EXTRACTION RULES FOR COMBINED SHEET:
- The page has TWO semester sections: SEM I block and SEM II block
- Extract subjects from the LATEST semester block ONLY (e.g. SEM II)
- Use the SGPA shown at the bottom of that latest semester block
- Use the CGPA shown at the very bottom of the page (covers both semesters)
- Set "semester" to the latest one (e.g. "II SEMESTER")
- Do NOT mix subjects from both semesters

JSON to return:
{
  "prn": "12 digit PRN from the PRN label",
  "seat_no": "11 digit seat number from the Seat No label",
  "name": "FULL NAME WITH SPACES",
  "program": "program name",
  "examination": "examination name",
  "semester": "LATEST semester e.g. II SEMESTER",
  "sgpa": 0.00,
  "cgpa": 0.00,
  "status": "pass",
  "total_credits": 0.00,
  "total_egp": 0.00,
  "subject_marks": [
    {
      "sr_no": 1,
      "course_code": "MTC141",
      "course_name": "Optimization Techniques",
      "credits": 4.00,
      "grade_obtained": "O",
      "grade_point": 10.00,
      "earned_gp": 40.00,
      "remark": "E.C"
    }
  ]
}

RULES:
1. Extract ONLY the latest semester subjects (SEM II if both shown)
2. status: lowercase "pass", "fail", or "atkt"
3. All numeric fields must be numbers not strings
4. PRN and Seat No must be digits only — they are DIFFERENT values, never the same
5. remark: use shown value (e.g. "E.C", "E.X") or empty string ""
6. Missing fields: "" for strings, 0 for numbers
7. Return ONLY the JSON object

RAW OCR TEXT:
"""


class OCRService:

    def __init__(self):
        tesseract_cmd = getattr(settings, 'tesseract_cmd', '')
        if tesseract_cmd and os.path.exists(tesseract_cmd):
            pytesseract.pytesseract.tesseract_cmd = tesseract_cmd
        elif shutil.which('tesseract'):
            pytesseract.pytesseract.tesseract_cmd = shutil.which('tesseract')
        elif os.name == 'nt':
            pytesseract.pytesseract.tesseract_cmd = r'C:\Program Files\Tesseract-OCR\tesseract.exe'
        else:
            pytesseract.pytesseract.tesseract_cmd = 'tesseract'
        self._openai_client = None

    def _get_openai_client(self):
        if self._openai_client is not None:
            return self._openai_client
        from openai import OpenAI
        api_key = getattr(settings, 'openai_api_key', '')
        if not api_key:
            raise ValueError("OPENAI_API_KEY not set in .env")
        self._openai_client = OpenAI(api_key=api_key)
        print("[OCR] OpenAI GPT-4o-mini client ready.")
        return self._openai_client

    def _pdf_to_images(self, file_bytes: bytes) -> List[bytes]:
        images = []
        try:
            doc = fitz.open(stream=file_bytes, filetype="pdf")
            for page_num in range(len(doc)):
                page = doc[page_num]
                mat = fitz.Matrix(250 / 72, 250 / 72)
                pix = page.get_pixmap(matrix=mat)
                images.append(pix.tobytes("png"))
            doc.close()
            print(f"[OCR] PDF has {len(images)} page(s).")
        except Exception as e:
            print(f"[OCR] PDF to image failed: {e}")
        return images

    def _preprocess_image(self, img_bytes: bytes) -> Image.Image:
        img = Image.open(io.BytesIO(img_bytes))
        img = img.convert('L')
        enhancer = ImageEnhance.Contrast(img)
        img = enhancer.enhance(2.0)
        img = img.filter(ImageFilter.SHARPEN)
        return img

    def _image_to_text(self, img_bytes: bytes) -> str:
        try:
            img = self._preprocess_image(img_bytes)
            config = r'--psm 6 --oem 3'
            text = pytesseract.image_to_string(img, config=config)
            return text.strip()
        except Exception as e:
            print(f"[OCR] Tesseract failed: {e}")
            return ""

    def _parse_with_gpt(self, raw_text: str, project_type: str) -> dict:
        client = self._get_openai_client()
        # Choose prompt based on project type
        prompt = PROMPT_FULL_YEAR if project_type == 'full_year' else PROMPT_SEMESTER

        response = client.chat.completions.create(
            model="gpt-4o-mini",
            messages=[
                {
                    "role": "system",
                    "content": "You are a precise JSON extractor for Indian college marksheets. Fix OCR errors and return only valid JSON."
                },
                {
                    "role": "user",
                    "content": prompt + raw_text
                }
            ],
            temperature=0.1,
            max_tokens=2048,
        )
        raw_response = response.choices[0].message.content or ""
        print(f"[OCR] GPT response: {len(raw_response)} chars")
        return self._extract_json(raw_response)

    def _extract_json(self, text: str) -> dict:
        text = text.strip()
        text = re.sub(r'```json\s*', '', text)
        text = re.sub(r'```\s*', '', text)
        text = text.strip()
        start = text.find('{')
        end = text.rfind('}')
        if start == -1 or end == -1:
            raise ValueError(f"No JSON found: {text[:200]}")
        return json.loads(text[start:end + 1])

    def _clean_student(self, data: dict) -> dict:
        for field in ['sgpa', 'cgpa', 'total_credits', 'total_egp']:
            try:
                data[field] = float(data.get(field) or 0)
            except (ValueError, TypeError):
                data[field] = 0.0

        # Force PRN and seat_no to digits only — safety net for any remaining OCR errors
        for field in ['prn', 'seat_no']:
            val = str(data.get(field) or '')
            digits_only = re.sub(r'[^\d]', '', val)
            if digits_only:
                data[field] = digits_only

        status = str(data.get('status', '')).lower().strip()
        if status not in ('pass', 'fail', 'atkt', 'absent'):
            status = 'pass' if data.get('sgpa', 0) >= 5.0 else 'fail'
        data['status'] = status

        clean_marks = []
        for m in data.get('subject_marks', []):
            try:
                clean_marks.append({
                    'sr_no':          int(m.get('sr_no') or 0),
                    'course_code':    str(m.get('course_code') or ''),
                    'course_name':    str(m.get('course_name') or ''),
                    'credits':        float(m.get('credits') or 0),
                    'grade_obtained': str(m.get('grade_obtained') or ''),
                    'grade_point':    float(m.get('grade_point') or 0),
                    'earned_gp':      float(m.get('earned_gp') or 0),
                    'remark':         str(m.get('remark') or ''),
                })
            except Exception as e:
                print(f"[OCR] Skipping malformed mark: {m} — {e}")

        data['subject_marks'] = clean_marks
        data['is_flagged'] = False
        data['errors'] = []
        return data

    async def process_pdf(
        self,
        file_bytes: bytes,
        filename: str,
        project_type: str = 'semester',   # 'semester' or 'full_year'
    ) -> List[Dict[str, Any]]:
        openai_key = getattr(settings, 'openai_api_key', '')
        if not openai_key:
            print("[OCR] No OPENAI_API_KEY — using mock data.")
            return self._mock_extract(filename)
        try:
            return await self._extract_hybrid(file_bytes, filename, project_type)
        except Exception as e:
            print(f"[OCR] Hybrid extraction failed: {e} — falling back to mock.")
            return self._mock_extract(filename)

    async def _extract_hybrid(
        self,
        file_bytes: bytes,
        filename: str,
        project_type: str,
    ) -> List[Dict[str, Any]]:
        images = await asyncio.to_thread(self._pdf_to_images, file_bytes)
        if not images:
            raise ValueError("Could not convert PDF to images")

        print(f"[OCR] Mode: {project_type} | Pages: {len(images)}")
        students = []

        for page_num, img_bytes in enumerate(images):
            print(f"[OCR] Page {page_num + 1}/{len(images)} — Tesseract...")
            try:
                raw_text = await asyncio.to_thread(self._image_to_text, img_bytes)

                if len(raw_text) < 50:
                    print(f"[OCR] Page {page_num + 1}: too little text, skipping.")
                    continue

                print(f"[OCR] Page {page_num + 1}: {len(raw_text)} chars → GPT-4o-mini ({project_type} mode)...")

                student_data = await asyncio.wait_for(
                    asyncio.to_thread(self._parse_with_gpt, raw_text, project_type),
                    timeout=60.0,
                )
                student_data = self._clean_student(student_data)

                if not student_data.get('prn'):
                    print(f"[OCR] Page {page_num + 1}: no PRN, skipping.")
                    continue

                existing_prns = [s['prn'] for s in students]
                if student_data['prn'] in existing_prns:
                    print(f"[OCR] Duplicate PRN {student_data['prn']} — updating.")
                    for i, s in enumerate(students):
                        if s['prn'] == student_data['prn']:
                            students[i] = student_data
                            break
                else:
                    students.append(student_data)
                    print(
                        f"[OCR] ✅ {student_data.get('name')} | "
                        f"PRN: {student_data.get('prn')} | "
                        f"Seat: {student_data.get('seat_no')} | "
                        f"SEM: {student_data.get('semester')} | "
                        f"SGPA: {student_data.get('sgpa')} | "
                        f"CGPA: {student_data.get('cgpa')}"
                    )

            except asyncio.TimeoutError:
                print(f"[OCR] Page {page_num + 1} timed out.")
            except Exception as e:
                print(f"[OCR] Page {page_num + 1} failed: {e}")

        if not students:
            raise ValueError("No student data extracted")

        print(f"[OCR] Done — {len(students)} student(s)")
        return students

    def _mock_extract(self, filename: str) -> List[Dict[str, Any]]:
        import random, hashlib
        courses = [
            {"sr_no": 1, "course_code": "MTM101", "course_name": "Research Methodology & IPR", "credits": 4.0},
            {"sr_no": 2, "course_code": "MTC102", "course_name": "Advanced Algorithms", "credits": 3.0},
            {"sr_no": 3, "course_code": "MTC103", "course_name": "Machine Learning", "credits": 3.0},
            {"sr_no": 4, "course_code": "MTC104", "course_name": "Advanced Operating System", "credits": 3.0},
            {"sr_no": 5, "course_code": "MTC121", "course_name": "Advanced Image Processing", "credits": 3.0},
            {"sr_no": 6, "course_code": "MTC111", "course_name": "Lab I: ML Techniques", "credits": 1.0},
            {"sr_no": 7, "course_code": "MTC112", "course_name": "Lab II: Advanced OS", "credits": 1.0},
            {"sr_no": 8, "course_code": "MTC113", "course_name": "Lab III: Elective I", "credits": 1.0},
            {"sr_no": 9, "course_code": "MTC114", "course_name": "Seminar", "credits": 2.0},
        ]
        grade_scale = {"O": 10.0, "A+": 9.0, "A": 8.0, "B+": 7.0, "B": 6.0, "C": 5.0, "F": 0.0}
        grades_pool = ["O", "A+", "A", "A", "A", "B+"]

        seed = int(hashlib.md5(filename.encode()).hexdigest(), 16) % 10000
        random.seed(seed)
        prn = f"202103{seed:06d}"

        subject_marks = []
        total_egp = total_credits = 0.0
        for c in courses:
            grade = random.choice(grades_pool)
            gp = grade_scale[grade]
            egp = round(gp * c["credits"], 2)
            total_egp += egp
            total_credits += c["credits"]
            subject_marks.append({
                "sr_no": c["sr_no"], "course_code": c["course_code"],
                "course_name": c["course_name"], "credits": c["credits"],
                "grade_obtained": grade, "grade_point": gp,
                "earned_gp": egp, "remark": "",
            })
        sgpa = round(total_egp / total_credits, 2) if total_credits else 0.0

        return [{
            "prn": prn, "seat_no": f"2115{seed:06d}",
            "name": f"MOCK STUDENT {seed}",
            "program": "M.TECH - COMPUTER SCIENCE & TECHNOLOGY",
            "examination": "End Semester Regular Examinations",
            "semester": "I SEMESTER",
            "total_credits": total_credits, "total_egp": round(total_egp, 2),
            "sgpa": sgpa, "cgpa": sgpa,
            "status": "pass" if sgpa >= 5.0 else "fail",
            "is_flagged": False, "errors": [],
            "subject_marks": subject_marks,
        }]
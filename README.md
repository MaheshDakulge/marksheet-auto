<div align="center">

# 📊 Marksheet Analytics App — College Edition

An AI-powered, end-to-end college marksheet scanner and academic analytics platform. Automatically extract student marks from scanned PDF marksheets, calculate SGPA/CGPA, generate class analytics, and export formatted Excel reports.

[![Live Demo](https://img.shields.io/badge/🌐_Live_Web_App-Click_Here_to_Launch-2563EB?style=for-the-badge&logo=githubpages&logoColor=white)](https://maheshdakulge.github.io/marksheet-auto/)
[![Backend API](https://img.shields.io/badge/⚡_Render_Backend_API-Active-46E3B7?style=for-the-badge&logo=render&logoColor=black)](https://marksheet-analytics-api.onrender.com/)

---

![Flutter](https://img.shields.io/badge/Flutter_3-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![FastAPI](https://img.shields.io/badge/FastAPI-005571?style=for-the-badge&logo=fastapi)
![Python](https://img.shields.io/badge/Python_3.11-3776AB?style=for-the-badge&logo=python&logoColor=white)
![Supabase](https://img.shields.io/badge/Supabase_DB-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white)
![Tesseract OCR](https://img.shields.io/badge/Tesseract_OCR-4285F4?style=for-the-badge&logo=google&logoColor=white)
![OpenAI](https://img.shields.io/badge/OpenAI_GPT--4o--mini-412991?style=for-the-badge&logo=openai&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white)

</div>

---

## 🌟 Live Demo & Quick Links

- 🚀 **Live Web Application**: [https://maheshdakulge.github.io/marksheet-auto/](https://maheshdakulge.github.io/marksheet-auto/)
- ⚙️ **Backend Health Endpoint**: [https://marksheet-analytics-api.onrender.com/](https://marksheet-analytics-api.onrender.com/)
- 📦 **GitHub Repository**: [https://github.com/MaheshDakulge/marksheet-auto](https://github.com/MaheshDakulge/marksheet-auto)

---

## 💡 What It Does & Key Features

College examination departments and professors spend hundreds of hours manually entering grades from physical/scanned marksheets. **Marksheet Analytics** automates this process end-to-end:

### 1. 🔍 Hybrid AI OCR Scanner
- **PDF & Image Support**: Converts multi-page marksheets (PNG, JPG, PDF) into crisp high-resolution images via **PyMuPDF**.
- **Local OCR Extraction**: Uses **Tesseract OCR** for instant local character extraction.
- **LLM Error Correction**: Leverages **GPT-4o-mini** to intelligently fix OCR noise, parse tabular course codes, marks, credits, and SGPA/CGPA.

### 2. 📊 Automated Grade & SGPA/CGPA Analytics
- **Semester & Full-Year Modes**: Supports single semester marksheets as well as combined annual transcripts.
- **Performance Dashboards**: View pass/fail percentages, class topper lists, subject-wise grade distributions, and trends.

### 3. 📥 One-Click Excel Export
- Generates formatted Excel spreadsheets (`.xlsx`) matching official college templates.
- Instant download for faculty record-keeping and official submission.

### 4. 🔒 Role-Based Security & Storage
- Authentication powered by **Supabase Auth** with JWT token security.
- Cloud database storing projects, student records, and extraction templates.

---

## 🏗️ Architecture Overview

```mermaid
graph TD;
    User[📱 Teacher / Admin User] -->|Flutter Web / App| Frontend[🌐 Flutter 3 Web Frontend]
    Frontend -->|REST API Requests| Backend[⚡ FastAPI Backend on Render]
    Backend -->|PDF / Image Processing| PyMuPDF[PyMuPDF + Tesseract OCR]
    PyMuPDF -->|Raw OCR Text| GPT[🤖 OpenAI GPT-4o-mini LLM]
    GPT -->|Structured JSON Results| Backend
    Backend -->|Store Data| Supabase[(🗄️ Supabase Database)]
    Backend -->|Generate .xlsx| Excel[📊 Excel Export Engine]
```

---

## 💻 Local Development Setup

### 1. Clone Repository
```bash
git clone https://github.com/MaheshDakulge/marksheet-auto.git
cd marksheet-auto
```

### 2. Run Backend (FastAPI)
```bash
cd backend
python -m venv venv
# On Windows: venv\Scripts\activate | On Linux/macOS: source venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

### 3. Run Frontend (Flutter Web)
```bash
cd marksheet_analytics
flutter pub get
flutter run -d chrome
```

---

## 🚢 Deployment Architecture

- **Frontend**: Automatically built and published to **GitHub Pages** using GitHub Actions (`.github/workflows/deploy-web.yml`).
- **Backend**: Containerized with **Docker** (Ubuntu Slim + Tesseract OCR + Poppler) and deployed on **Render**.

---

## 👤 Author & Support

Developed by **Mahesh Dakulge**.
For inquiries, contributions, or feedback, visit the [GitHub Repository](https://github.com/MaheshDakulge/marksheet-auto).

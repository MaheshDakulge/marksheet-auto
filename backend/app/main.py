from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.api import projects, upload, review, analytics, export, templates
from app.api.auth import router as auth_router   # FIX: was missing — caused 401 (no teacher rows)

app = FastAPI(
    title="Marksheet Analytics API",
    description="Backend for scanning, processing and analysing college marksheets.",
    version="2.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],       # Tighten to specific origins in production
    allow_credentials=False,   # Must be False when allow_origins=["*"]
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth_router)          # FIX: register + login endpoints
app.include_router(projects.router)
app.include_router(upload.router)
app.include_router(review.router)
app.include_router(analytics.router)
app.include_router(export.router)
app.include_router(templates.router)


@app.get("/", tags=["health"])
async def health():
    return {"status": "ok", "service": "Marksheet Analytics API v2"}
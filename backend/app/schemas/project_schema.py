from pydantic import BaseModel
from typing import Optional, Dict, Any
from uuid import UUID
from datetime import datetime


class ProjectBase(BaseModel):
    name: str
    program: Optional[str] = None
    examination: Optional[str] = None
    semester: Optional[str] = None
    passing_marks: int = 40
    credits_json: Dict[str, Any] = {}
    grade_scale: Dict[str, Any] = {}
    # NEW: project_type tells OCR which extraction mode to use
    # 'semester'  = single semester marksheet (1 page, one SEM block)
    # 'full_year' = combined marksheet (SEM I + SEM II on same page/PDF)
    project_type: str = "semester"


class ProjectCreate(ProjectBase):
    pass


class ProjectUpdate(BaseModel):
    name: Optional[str] = None
    program: Optional[str] = None
    examination: Optional[str] = None
    semester: Optional[str] = None
    passing_marks: Optional[int] = None
    credits_json: Optional[Dict[str, Any]] = None
    grade_scale: Optional[Dict[str, Any]] = None
    project_type: Optional[str] = None
    status: Optional[str] = None


class ProjectResponse(ProjectBase):
    id: UUID
    teacher_id: UUID
    status: str
    created_at: Optional[datetime] = None

    class Config:
        from_attributes = True
from pydantic import BaseModel
from typing import Optional, List, Dict, Any
from uuid import UUID
from datetime import datetime


class ColumnDefinition(BaseModel):
    order: int
    type: str   # sr_no | course_code | course_name | credits | grade | grade_point | earned_gp | remark
    label: str


class TemplateCreate(BaseModel):
    name: str
    columns: List[ColumnDefinition] = []
    # FIX: was missing — these columns were added to DB but never in the schema
    credits_map: Dict[str, Any] = {}   # e.g. {"MTM101": 4, "MTC102": 4}
    max_marks: Dict[str, Any] = {}     # e.g. {"MTM101": 100, "MTC102": 100}


# FIX: TemplateUpdate was missing entirely — needed for PUT /templates/{id}
class TemplateUpdate(BaseModel):
    name: Optional[str] = None
    columns: Optional[List[ColumnDefinition]] = None
    credits_map: Optional[Dict[str, Any]] = None
    max_marks: Optional[Dict[str, Any]] = None


class TemplateResponse(TemplateCreate):
    id: UUID
    teacher_id: UUID
    created_at: Optional[datetime] = None

    class Config:
        from_attributes = True

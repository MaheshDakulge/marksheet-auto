from pydantic import BaseModel
from typing import Optional, List
from uuid import UUID
from datetime import datetime
from decimal import Decimal


class SubjectMarkBase(BaseModel):
    sr_no: Optional[int] = None
    course_code: Optional[str] = None
    course_name: Optional[str] = None
    credits: Optional[Decimal] = None
    grade_obtained: Optional[str] = None
    grade_point: Optional[Decimal] = None
    earned_gp: Optional[Decimal] = None
    remark: Optional[str] = None


class SubjectMarkCreate(SubjectMarkBase):
    pass


class SubjectMarkResponse(SubjectMarkBase):
    id: UUID
    result_id: UUID
    created_at: Optional[datetime] = None

    class Config:
        from_attributes = True


class StudentCreate(BaseModel):
    prn: str
    seat_no: Optional[str] = None
    name: str
    program: Optional[str] = None


class StudentResponse(StudentCreate):
    created_at: Optional[datetime] = None

    class Config:
        from_attributes = True


class ValidationErrorItem(BaseModel):
    type: str
    message: str
    field_name: Optional[str] = None


class StudentResultCreate(BaseModel):
    student_prn: str
    examination: Optional[str] = None
    semester: Optional[str] = None
    total_credits: Optional[Decimal] = None
    total_egp: Optional[Decimal] = None
    sgpa: Optional[Decimal] = None
    cgpa: Optional[Decimal] = None
    status: str = "pending"
    is_flagged: bool = False
    errors: List[ValidationErrorItem] = []
    subject_marks: List[SubjectMarkCreate] = []


class StudentResultUpdate(BaseModel):
    prn: Optional[str] = None
    name: Optional[str] = None
    seat_no: Optional[str] = None
    subject_marks: Optional[List[SubjectMarkCreate]] = None


class StudentResultResponse(StudentResultCreate):
    id: UUID
    project_id: UUID
    job_id: Optional[UUID] = None
    is_confirmed: bool = False
    rank: Optional[int] = None
    created_at: Optional[datetime] = None
    subject_marks: List[SubjectMarkResponse] = []

    class Config:
        from_attributes = True


class ConfirmResultsRequest(BaseModel):
    result_ids: List[str]
    project_id: str

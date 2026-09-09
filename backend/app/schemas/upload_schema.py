from pydantic import BaseModel
from typing import Optional, List
from uuid import UUID
from datetime import datetime


class UploadJobCreate(BaseModel):
    project_id: str
    template_id: Optional[str] = None


class UploadJobResponse(BaseModel):
    id: UUID
    project_id: UUID
    template_id: Optional[UUID] = None
    status: str
    file_count: int = 0
    processed: int = 0
    error_message: Optional[str] = None
    created_at: Optional[datetime] = None

    class Config:
        from_attributes = True
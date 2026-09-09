from fastapi import APIRouter, Depends, HTTPException, status
from typing import List
from app.core.database import get_supabase
from app.core.security import get_current_teacher
from app.schemas.template_schema import TemplateCreate, TemplateUpdate, TemplateResponse
from supabase import Client

router = APIRouter(prefix="/templates", tags=["templates"])


@router.get("", response_model=List[TemplateResponse])
async def list_templates(
    teacher: dict = Depends(get_current_teacher),
    supabase: Client = Depends(get_supabase),
):
    result = (
        supabase.table("templates")
        .select("*")
        .eq("teacher_id", teacher["id"])
        .execute()
    )
    return result.data


@router.post("", response_model=TemplateResponse, status_code=status.HTTP_201_CREATED)
async def create_template(
    payload: TemplateCreate,
    teacher: dict = Depends(get_current_teacher),
    supabase: Client = Depends(get_supabase),
):
    # FIX: was missing credits_map and max_marks — added to DB, now persisted here too
    result = supabase.table("templates").insert({
        "teacher_id": teacher["id"],
        "name": payload.name,
        "columns": [c.model_dump() for c in payload.columns],
        "credits_map": payload.credits_map,
        "max_marks": payload.max_marks,
    }).execute()
    return result.data[0]


@router.put("/{template_id}", response_model=TemplateResponse)
async def update_template(
    template_id: str,
    payload: TemplateUpdate,
    teacher: dict = Depends(get_current_teacher),
    supabase: Client = Depends(get_supabase),
):
    # FIX: PUT /templates/{id} was completely missing from original
    existing = (
        supabase.table("templates")
        .select("id")
        .eq("id", template_id)
        .eq("teacher_id", teacher["id"])
        .execute()
    )
    if not existing.data:
        raise HTTPException(status_code=404, detail="Template not found")

    update_data = payload.model_dump(exclude_none=True)
    if "columns" in update_data and update_data["columns"] is not None:
        update_data["columns"] = [
            c.model_dump() if hasattr(c, "model_dump") else c
            for c in update_data["columns"]
        ]

    result = (
        supabase.table("templates")
        .update(update_data)
        .eq("id", template_id)
        .execute()
    )
    return result.data[0]


@router.delete("/{template_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_template(
    template_id: str,
    teacher: dict = Depends(get_current_teacher),
    supabase: Client = Depends(get_supabase),
):
    supabase.table("templates").delete().eq("id", template_id).eq("teacher_id", teacher["id"]).execute()

from fastapi import APIRouter, Depends, HTTPException, status
from typing import List
from app.core.database import get_supabase
from app.core.security import get_current_teacher
from app.schemas.project_schema import ProjectCreate, ProjectUpdate, ProjectResponse
from supabase import Client

router = APIRouter(prefix="/projects", tags=["projects"])


@router.get("", response_model=List[ProjectResponse])
async def list_projects(
    supabase: Client = Depends(get_supabase),
    teacher: dict = Depends(get_current_teacher),
):
    result = (
        supabase.table("projects")
        .select("*")
        .eq("teacher_id", teacher["id"])
        .order("created_at", desc=True)
        .execute()
    )
    return result.data


@router.post("", response_model=ProjectResponse, status_code=status.HTTP_201_CREATED)
async def create_project(
    payload: ProjectCreate,
    supabase: Client = Depends(get_supabase),
    teacher: dict = Depends(get_current_teacher),
):
    result = supabase.table("projects").insert({
        "teacher_id":    teacher["id"],
        "name":          payload.name,
        "program":       payload.program,
        "examination":   payload.examination,
        "semester":      payload.semester,
        "passing_marks": payload.passing_marks,
        "credits_json":  payload.credits_json,
        "grade_scale":   payload.grade_scale,
        "project_type":  payload.project_type,   # 'semester' or 'full_year'
        "status":        "created",
    }).execute()
    return result.data[0]


@router.get("/{project_id}", response_model=ProjectResponse)
async def get_project(
    project_id: str,
    teacher: dict = Depends(get_current_teacher),
    supabase: Client = Depends(get_supabase),
):
    result = (
        supabase.table("projects")
        .select("*")
        .eq("id", project_id)
        .eq("teacher_id", teacher["id"])
        .execute()
    )
    if not result.data:
        raise HTTPException(status_code=404, detail="Project not found")
    return result.data[0]


@router.put("/{project_id}", response_model=ProjectResponse)
async def update_project(
    project_id: str,
    payload: ProjectUpdate,
    teacher: dict = Depends(get_current_teacher),
    supabase: Client = Depends(get_supabase),
):
    existing = (
        supabase.table("projects")
        .select("id")
        .eq("id", project_id)
        .eq("teacher_id", teacher["id"])
        .execute()
    )
    if not existing.data:
        raise HTTPException(status_code=404, detail="Project not found")

    update_data = payload.model_dump(exclude_none=True)
    if not update_data:
        raise HTTPException(status_code=400, detail="No fields to update")

    result = (
        supabase.table("projects")
        .update(update_data)
        .eq("id", project_id)
        .execute()
    )
    return result.data[0]


@router.delete("/{project_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_project(
    project_id: str,
    teacher: dict = Depends(get_current_teacher),
    supabase: Client = Depends(get_supabase),
):
    supabase.table("projects").delete().eq("id", project_id).eq("teacher_id", teacher["id"]).execute()
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form, BackgroundTasks
from typing import Annotated, Optional, List
from app.core.database import get_supabase
from app.core.security import get_current_teacher
from app.schemas.upload_schema import UploadJobResponse
from app.services.ocr_service import OCRService
from supabase import Client
import uuid

router = APIRouter(prefix="/upload", tags=["upload"])
ocr_service = OCRService()


async def _process_uploads(
    job_id: str,
    project_id: str,
    project_type: str,      # 'semester' or 'full_year'
    files: list,
    supabase: Client,
):
    """
    Background task — processes one or many PDFs.
    project_type is passed to OCR so it knows which extraction mode to use.
    """
    try:
        supabase.table("upload_jobs").update({
            "status": "processing",
            "file_count": len(files),
        }).eq("id", job_id).execute()
        supabase.table("projects").update({"status": "processing"}).eq("id", project_id).execute()

        inserted = 0
        error_list = []

        for file_info in files:
            filename   = file_info["filename"]
            file_bytes = file_info["bytes"]
            try:
                # Pass project_type so OCR knows semester vs full_year mode
                extracted = await ocr_service.process_pdf(
                    file_bytes, filename, project_type=project_type
                )
                for student_data in extracted:
                    prn = student_data.get("prn")
                    if not prn:
                        error_list.append(f"{filename}: no PRN found")
                        continue

                    supabase.table("students").upsert({
                        "prn":     prn,
                        "seat_no": student_data.get("seat_no"),
                        "name":    student_data.get("name", "Unknown"),
                        "program": student_data.get("program"),
                    }, on_conflict="prn").execute()

                    existing = (
                        supabase.table("student_results")
                        .select("id")
                        .eq("project_id", project_id)
                        .eq("student_prn", prn)
                        .execute()
                    )
                    if existing.data:
                        supabase.table("subject_marks").delete().eq("result_id", existing.data[0]["id"]).execute()

                    result_resp = supabase.table("student_results").upsert({
                        "project_id":    project_id,
                        "job_id":        job_id,
                        "student_prn":   prn,
                        "examination":   student_data.get("examination"),
                        "semester":      student_data.get("semester"),
                        "total_credits": student_data.get("total_credits"),
                        "total_egp":     student_data.get("total_egp"),
                        "sgpa":          student_data.get("sgpa"),
                        "cgpa":          student_data.get("cgpa"),
                        "status":        student_data.get("status", "pending"),
                        "is_flagged":    student_data.get("is_flagged", False),
                        "errors":        student_data.get("errors", []),
                    }, on_conflict="project_id,student_prn").execute()
                    result_id = result_resp.data[0]["id"]

                    for mark in student_data.get("subject_marks", []):
                        m = {k: v for k, v in mark.items()}
                        m["result_id"] = result_id
                        supabase.table("subject_marks").insert(m).execute()

                    inserted += 1
                    supabase.table("upload_jobs").update({"processed": inserted}).eq("id", job_id).execute()

            except Exception as e:
                error_list.append(f"{filename}: {str(e)}")
                print(f"[upload] Error processing {filename}: {e}")
                continue

        supabase.table("upload_jobs").update({
            "status":        "done" if inserted > 0 else "failed",
            "processed":     inserted,
            "error_message": "; ".join(error_list[i] for i in range(min(5, len(error_list)))) if error_list else None,
        }).eq("id", job_id).execute()

        print(f"[upload] Job {job_id} complete — {inserted}/{len(files)} students processed")

    except Exception as exc:
        supabase.table("upload_jobs").update({
            "status": "failed", "error_message": str(exc),
        }).eq("id", job_id).execute()


@router.post("/{project_id}", response_model=UploadJobResponse, status_code=202)
async def upload_marksheets(
    project_id: str,
    background_tasks: BackgroundTasks,
    files: Annotated[
        List[UploadFile],
        File(description="Select one or more PDF marksheets. Each PDF = one student.")
    ],
    template_id: Optional[str] = Form(None),
    supabase: Client = Depends(get_supabase),
    teacher: dict = Depends(get_current_teacher),
):
    proj = (
        supabase.table("projects")
        .select("id, project_type")
        .eq("id", project_id)
        .eq("teacher_id", teacher["id"])
        .execute()
    )
    if not proj.data:
        raise HTTPException(status_code=404, detail="Project not found")

    # Get project_type to pass to OCR
    project_type = proj.data[0].get("project_type", "semester")

    file_list = []
    for f in files:
        content = await f.read()
        file_list.append({"bytes": content, "filename": f.filename or "upload.pdf"})

    if not file_list:
        raise HTTPException(status_code=400, detail="No files provided")

    job_id = str(uuid.uuid4())
    result = supabase.table("upload_jobs").insert({
        "id":             job_id,
        "project_id":     project_id,
        "template_id":    template_id,
        "status":         "queued",
        "file_count":     len(file_list),
        "processed":      0,
        "marksheet_type": project_type,
    }).execute()

    background_tasks.add_task(
        _process_uploads, job_id, project_id, project_type, file_list, supabase
    )
    print(f"[upload] Queued {len(file_list)} file(s) | type={project_type} | project={project_id}")
    return result.data[0]


@router.get("/{project_id}/status/{job_id}", response_model=UploadJobResponse)
async def get_job_status(
    project_id: str,
    job_id: str,
    supabase: Client = Depends(get_supabase),
    teacher: dict = Depends(get_current_teacher),
):
    proj = (
        supabase.table("projects").select("id")
        .eq("id", project_id).eq("teacher_id", teacher["id"]).execute()
    )
    if not proj.data:
        raise HTTPException(status_code=404, detail="Project not found")

    result = (
        supabase.table("upload_jobs").select("*")
        .eq("id", job_id).eq("project_id", project_id).execute()
    )
    if not result.data:
        raise HTTPException(status_code=404, detail="Job not found")
    return result.data[0]
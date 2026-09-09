from fastapi import APIRouter, Depends, HTTPException
from typing import List
from app.core.database import get_supabase
from app.core.security import get_current_teacher
from app.schemas.review_schema import StudentResultResponse, StudentResultUpdate, ConfirmResultsRequest
# FIX: removed unused `from app.services.gpa_service import compute_sgpa`
from supabase import Client

router = APIRouter(prefix="/review", tags=["review"])


def _determine_status(subject_marks: list, passing_marks: int = 40) -> str:
    """Recompute pass/fail/atkt status from subject marks."""
    if not subject_marks:
        return "pending"
    fail_count = sum(1 for m in subject_marks if m.get("grade_obtained") == "F")
    if fail_count == 0:
        return "pass"
    elif fail_count <= 2:
        return "atkt"
    return "fail"


@router.get("/{project_id}", response_model=List[StudentResultResponse])
async def get_results(
    project_id: str,
    teacher: dict = Depends(get_current_teacher),
    supabase: Client = Depends(get_supabase),
):
    proj = (
        supabase.table("projects")
        .select("id")
        .eq("id", project_id)
        .eq("teacher_id", teacher["id"])
        .execute()
    )
    if not proj.data:
        raise HTTPException(status_code=404, detail="Project not found")

    results = (
        supabase.table("student_results")
        .select("*, subject_marks(*), students(name, seat_no, prn, program)")
        .eq("project_id", project_id)
        .order("created_at")
        .execute()
    )
    return results.data


@router.put("/{project_id}/result/{result_id}", response_model=StudentResultResponse)
async def update_result(
    project_id: str,
    result_id: str,
    payload: StudentResultUpdate,
    teacher: dict = Depends(get_current_teacher),
    supabase: Client = Depends(get_supabase),
):
    existing = (
        supabase.table("student_results")
        .select("*, subject_marks(*)")
        .eq("id", result_id)
        .eq("project_id", project_id)
        .execute()
    )
    if not existing.data:
        raise HTTPException(status_code=404, detail="Result not found")

    existing_row = existing.data[0]

    if payload.name or payload.seat_no:
        prn = existing_row["student_prn"]
        student_update = {}
        if payload.name:
            student_update["name"] = payload.name
        if payload.seat_no:
            student_update["seat_no"] = payload.seat_no
        supabase.table("students").update(student_update).eq("prn", prn).execute()

    updated_marks = existing_row.get("subject_marks", [])
    if payload.subject_marks:
        for mark in payload.subject_marks:
            mark_dict = mark.model_dump(exclude_none=True)
            sr_no = mark_dict.get("sr_no")
            if sr_no is not None:
                supabase.table("subject_marks") \
                    .update(mark_dict) \
                    .eq("result_id", result_id) \
                    .eq("sr_no", sr_no) \
                    .execute()
        refreshed_marks_resp = (
            supabase.table("subject_marks")
            .select("*")
            .eq("result_id", result_id)
            .execute()
        )
        updated_marks = refreshed_marks_resp.data

    result_update: dict = {
        "is_flagged": False,
        "errors": [],
    }
    if payload.subject_marks and updated_marks:
        total_egp = sum(float(m.get("earned_gp") or 0) for m in updated_marks)
        total_credits = sum(float(m.get("credits") or 0) for m in updated_marks)
        new_sgpa = round(total_egp / total_credits, 2) if total_credits else 0.0
        new_status = _determine_status(updated_marks)
        result_update["total_egp"] = total_egp
        result_update["total_credits"] = total_credits
        result_update["sgpa"] = new_sgpa
        result_update["status"] = new_status

    supabase.table("student_results").update(result_update).eq("id", result_id).execute()

    refreshed = (
        supabase.table("student_results")
        .select("*, subject_marks(*), students(name, seat_no, prn, program)")

        .eq("id", result_id)
        .execute()
    )
    return refreshed.data[0]


@router.post("/{project_id}/confirm")
async def confirm_results(
    project_id: str,
    payload: ConfirmResultsRequest,
    teacher: dict = Depends(get_current_teacher),
    supabase: Client = Depends(get_supabase),
):
    proj = (
        supabase.table("projects")
        .select("id")
        .eq("id", project_id)
        .eq("teacher_id", teacher["id"])
        .execute()
    )
    if not proj.data:
        raise HTTPException(status_code=404, detail="Project not found")

    supabase.table("student_results") \
        .update({"is_confirmed": True, "is_flagged": False, "errors": []}) \
        .in_("id", payload.result_ids) \
        .eq("project_id", project_id) \
        .execute()

    all_results = (
        supabase.table("student_results")
        .select("id, sgpa, total_egp, is_confirmed, status")
        .eq("project_id", project_id)
        .execute()
    )

    all_confirmed = all(r["is_confirmed"] for r in all_results.data)

    confirmed = [r for r in all_results.data if r.get("status") != "fail"]
    failed    = [r for r in all_results.data if r.get("status") == "fail"]
    confirmed.sort(
        key=lambda r: (float(r.get("sgpa") or 0), float(r.get("total_egp") or 0)),
        reverse=True,
    )
    for rank_pos, row in enumerate(confirmed + failed, start=1):
        supabase.table("student_results").update({"rank": rank_pos}).eq("id", row["id"]).execute()

    if all_confirmed:
        supabase.table("projects").update({"status": "reviewed"}).eq("id", project_id).execute()

    return {"confirmed": len(payload.result_ids), "project_fully_reviewed": all_confirmed}
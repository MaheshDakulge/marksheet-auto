from fastapi import APIRouter, Depends, HTTPException
from app.core.database import get_supabase
from app.core.security import get_current_teacher
from app.services.analytics_service import AnalyticsService
from supabase import Client

router = APIRouter(prefix="/analytics", tags=["analytics"])
analytics_service = AnalyticsService()

# Empty response shape — same keys as full response, all zeros
EMPTY = {
    "total_students":  0,
    "pass_count":      0,
    "fail_count":      0,
    "atkt_count":      0,
    "absent_count":    0,
    "avg_sgpa":        0,
    "top_sgpa":        0,
    "min_sgpa":        0,
    "above_avg_count": 0,
    "below_avg_count": 0,
    "toppers":         [],
    "grade_distribution": {},
    "subject_averages":   [],
    "sgpa_histogram":     [],
}


@router.get("/{project_id}")
async def get_analytics(
    project_id: str,
    teacher: dict = Depends(get_current_teacher),
    supabase: Client = Depends(get_supabase),
):
    """
    Returns all analytics data for the Flutter frontend dashboard.
    Analytics are ONLY here — not in the Excel export.

    Returns:
    - total_students, pass_count, fail_count, atkt_count, absent_count
    - avg_sgpa, top_sgpa, min_sgpa
    - above_avg_count, below_avg_count
    - toppers: top 5 students [{prn, name, sgpa, rank, status}]
    - grade_distribution: {O: N, A+: N, A: N, B+: N, B: N, C: N, F: N}
    - subject_averages: [{subject, avg_gp}] sorted descending
    - sgpa_histogram: [{range, count}] for 9-10 / 8-9 / 7-8 / 6-7 / <6
    """
    proj = (
        supabase.table("projects").select("*")
        .eq("id", project_id).eq("teacher_id", teacher["id"]).execute()
    )
    if not proj.data:
        raise HTTPException(status_code=404, detail="Project not found")

    results = (
        supabase.table("student_results")
        .select("*, subject_marks(*), students(name, seat_no, prn)")
        .eq("project_id", project_id)
        .execute()
    )

    if not results.data:
        return EMPTY

    return analytics_service.compute(results.data)
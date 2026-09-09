from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, EmailStr
from app.core.database import get_supabase_sync
from app.core.security import get_current_teacher

router = APIRouter(prefix="/auth", tags=["auth"])


# ── Schemas ────────────────────────────────────────────────────────────────────

class RegisterRequest(BaseModel):
    email: EmailStr
    password: str
    name: str
    college: str = ""
    department: str = ""


class LoginRequest(BaseModel):
    email: EmailStr
    password: str


class UpdateProfileRequest(BaseModel):
    name: str
    college: str | None = None
    department: str | None = None


class AuthResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    teacher: dict


# ── Endpoints ──────────────────────────────────────────────────────────────────

@router.post("/register", response_model=AuthResponse, status_code=status.HTTP_201_CREATED)
async def register(payload: RegisterRequest):
    supabase = get_supabase_sync()
    try:
        auth_resp = supabase.auth.sign_up({
            "email": payload.email,
            "password": payload.password,
            "options": {
                "data": {
                    "name":       payload.name,
                    "college":    payload.college,
                    "department": payload.department,
                }
            }
        })
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Registration failed: {str(e)}")

    if not auth_resp.user:
        raise HTTPException(status_code=400, detail="Could not create user")

    teacher_id = auth_resp.user.id
    existing = supabase.table("teachers").select("id").eq("id", teacher_id).execute()
    if not existing.data:
        supabase.table("teachers").insert({
            "id":         teacher_id,
            "email":      payload.email,
            "name":       payload.name,
            "college":    payload.college,
            "department": payload.department,
        }).execute()

    teacher = supabase.table("teachers").select("*").eq("id", teacher_id).execute()
    access_token = auth_resp.session.access_token if auth_resp.session else ""
    return {
        "access_token": access_token,
        "token_type":   "bearer",
        "teacher":      teacher.data[0] if teacher.data else {},
    }


@router.post("/login", response_model=AuthResponse)
async def login(payload: LoginRequest):
    supabase = get_supabase_sync()
    try:
        auth_resp = supabase.auth.sign_in_with_password({
            "email":    payload.email,
            "password": payload.password,
        })
    except Exception:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid email or password")

    if not auth_resp.user or not auth_resp.session:
        raise HTTPException(status_code=401, detail="Login failed")

    teacher_id = auth_resp.user.id
    existing = supabase.table("teachers").select("*").eq("id", teacher_id).execute()
    if not existing.data:
        meta = auth_resp.user.user_metadata or {}
        supabase.table("teachers").insert({
            "id":         teacher_id,
            "email":      payload.email,
            "name":       meta.get("name", ""),
            "college":    meta.get("college", ""),
            "department": meta.get("department", ""),
        }).execute()
        teacher_row = supabase.table("teachers").select("*").eq("id", teacher_id).execute()
    else:
        teacher_row = existing

    return {
        "access_token": auth_resp.session.access_token,
        "token_type":   "bearer",
        "teacher":      teacher_row.data[0],
    }


@router.post("/logout")
async def logout():
    return {"message": "Logged out successfully"}


@router.get("/me")
async def me(teacher: dict = Depends(get_current_teacher)):
    return teacher


# FIX: was missing — Flutter profile_screen calls PUT /auth/profile
@router.put("/profile")
async def update_profile(
    payload: UpdateProfileRequest,
    teacher: dict = Depends(get_current_teacher),
):
    supabase = get_supabase_sync()
    result = (
        supabase.table("teachers")
        .update({
            "name":       payload.name,
            "college":    payload.college,
            "department": payload.department,
        })
        .eq("id", teacher["id"])
        .execute()
    )
    if not result.data:
        raise HTTPException(status_code=404, detail="Teacher not found")
    return result.data[0]
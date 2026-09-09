-- ============================================================
-- MARKSHEET ANALYTICS — COMPLETE SUPABASE SETUP (v2 — synced)
-- Safe to re-run: drops and recreates everything cleanly.
-- ============================================================

-- STEP 1: Drop everything cleanly
DROP TABLE IF EXISTS subject_marks    CASCADE;
DROP TABLE IF EXISTS student_results  CASCADE;
DROP TABLE IF EXISTS students         CASCADE;
DROP TABLE IF EXISTS upload_jobs      CASCADE;
DROP TABLE IF EXISTS templates        CASCADE;
DROP TABLE IF EXISTS projects         CASCADE;
DROP TABLE IF EXISTS teachers         CASCADE;
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS public.handle_new_user();

-- STEP 2: Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================
-- TABLE 1: teachers
-- ============================================================
CREATE TABLE public.teachers (
  id          UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email       TEXT UNIQUE NOT NULL,
  name        TEXT NOT NULL DEFAULT 'Unknown',
  college     TEXT,
  department  TEXT,
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  updated_at  TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- TRIGGER: Auto-create/update teacher profile on signup
-- FIX: original schema used 'full_name' key — changed to 'name'
--      to match what the Flutter app sends in raw_user_meta_data.
--      Also uses ON CONFLICT DO UPDATE so re-signup updates the row.
--      SET search_path = public fixes the mutable search_path warning.
-- ============================================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.teachers (id, email, name, college, department)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'name', 'Unknown'),
    NEW.raw_user_meta_data->>'college',
    NEW.raw_user_meta_data->>'department'
  )
  ON CONFLICT (id) DO UPDATE SET
    email      = EXCLUDED.email,
    name       = COALESCE(EXCLUDED.name, public.teachers.name),
    college    = COALESCE(EXCLUDED.college, public.teachers.college),
    department = COALESCE(EXCLUDED.department, public.teachers.department),
    updated_at = NOW();
  RETURN NEW;
END;
$$;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ============================================================
-- TABLE 2: projects
-- FIX: added passing_marks, credits_json, grade_scale (were missing)
-- ============================================================
CREATE TABLE public.projects (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  teacher_id    UUID NOT NULL REFERENCES public.teachers(id) ON DELETE CASCADE,
  name          TEXT NOT NULL,
  program       TEXT,
  examination   TEXT,
  semester      TEXT,
  passing_marks INT NOT NULL DEFAULT 40,
  credits_json  JSONB NOT NULL DEFAULT '{}',
  grade_scale   JSONB NOT NULL DEFAULT '{}',
  status        TEXT NOT NULL DEFAULT 'created'
                CHECK (status IN ('created','processing','reviewed','exported')),
  created_at    TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- TABLE 3: templates
-- FIX: added credits_map, max_marks (were missing)
-- ============================================================
CREATE TABLE public.templates (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  teacher_id  UUID NOT NULL REFERENCES public.teachers(id) ON DELETE CASCADE,
  name        TEXT NOT NULL,
  columns     JSONB NOT NULL DEFAULT '[]',
  credits_map JSONB NOT NULL DEFAULT '{}',
  max_marks   JSONB NOT NULL DEFAULT '{}',
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- TABLE 4: upload_jobs
-- ============================================================
CREATE TABLE public.upload_jobs (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  project_id    UUID NOT NULL REFERENCES public.projects(id) ON DELETE CASCADE,
  template_id   UUID REFERENCES public.templates(id) ON DELETE SET NULL,
  status        TEXT NOT NULL DEFAULT 'queued'
                CHECK (status IN ('queued','processing','done','failed')),
  file_count    INT DEFAULT 0,
  processed     INT DEFAULT 0,
  error_message TEXT,
  created_at    TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- TABLE 5: students
-- ============================================================
CREATE TABLE public.students (
  prn        TEXT PRIMARY KEY,
  seat_no    TEXT,
  name       TEXT NOT NULL,
  program    TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- TABLE 6: student_results
-- ============================================================
CREATE TABLE public.student_results (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  project_id    UUID NOT NULL REFERENCES public.projects(id) ON DELETE CASCADE,
  job_id        UUID REFERENCES public.upload_jobs(id) ON DELETE SET NULL,
  student_prn   TEXT NOT NULL REFERENCES public.students(prn) ON DELETE CASCADE,
  examination   TEXT,
  semester      TEXT,
  total_credits NUMERIC(5,2),
  total_egp     NUMERIC(7,2),
  sgpa          NUMERIC(4,2),
  cgpa          NUMERIC(4,2),
  rank          INT,
  status        TEXT NOT NULL DEFAULT 'pending'
                CHECK (status IN ('pass','fail','atkt','absent','pending')),
  is_flagged    BOOLEAN NOT NULL DEFAULT FALSE,
  is_confirmed  BOOLEAN NOT NULL DEFAULT FALSE,
  errors        JSONB NOT NULL DEFAULT '[]',
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (project_id, student_prn)
);

-- ============================================================
-- TABLE 7: subject_marks
-- ============================================================
CREATE TABLE public.subject_marks (
  id             UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  result_id      UUID NOT NULL REFERENCES public.student_results(id) ON DELETE CASCADE,
  sr_no          INT,
  course_code    TEXT,
  course_name    TEXT,
  credits        NUMERIC(3,2),
  grade_obtained TEXT,
  grade_point    NUMERIC(4,2),
  earned_gp      NUMERIC(6,2),
  remark         TEXT,
  created_at     TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- INDEXES
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_projects_teacher      ON public.projects(teacher_id);
CREATE INDEX IF NOT EXISTS idx_results_project       ON public.student_results(project_id);
CREATE INDEX IF NOT EXISTS idx_results_student       ON public.student_results(student_prn);
CREATE INDEX IF NOT EXISTS idx_results_job           ON public.student_results(job_id);
CREATE INDEX IF NOT EXISTS idx_marks_result          ON public.subject_marks(result_id);
CREATE INDEX IF NOT EXISTS idx_jobs_project          ON public.upload_jobs(project_id);
CREATE INDEX IF NOT EXISTS idx_templates_teacher     ON public.templates(teacher_id);
CREATE INDEX IF NOT EXISTS idx_jobs_template         ON public.upload_jobs(template_id);

-- ============================================================
-- ROW LEVEL SECURITY
-- FIX: all policies use (SELECT auth.uid()) not auth.uid() directly
--      to avoid per-row re-evaluation (performance advisory fix)
-- ============================================================
ALTER TABLE public.teachers        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.projects        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.templates       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.upload_jobs     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.students        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.student_results ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subject_marks   ENABLE ROW LEVEL SECURITY;

CREATE POLICY teacher_own ON public.teachers FOR ALL
  USING (id = (SELECT auth.uid()));

CREATE POLICY project_own ON public.projects FOR ALL
  USING (teacher_id = (SELECT auth.uid()));

CREATE POLICY template_own ON public.templates FOR ALL
  USING (teacher_id = (SELECT auth.uid()));

CREATE POLICY job_own ON public.upload_jobs FOR ALL
  USING (project_id IN (
    SELECT id FROM public.projects WHERE teacher_id = (SELECT auth.uid())
  ));

CREATE POLICY student_auth ON public.students FOR ALL
  USING ((SELECT auth.uid()) IS NOT NULL);

CREATE POLICY result_own ON public.student_results FOR ALL
  USING (project_id IN (
    SELECT id FROM public.projects WHERE teacher_id = (SELECT auth.uid())
  ));

CREATE POLICY marks_own ON public.subject_marks FOR ALL
  USING (result_id IN (
    SELECT sr.id FROM public.student_results sr
    JOIN public.projects p ON p.id = sr.project_id
    WHERE p.teacher_id = (SELECT auth.uid())
  ));

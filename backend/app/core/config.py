import os
from pydantic_settings import BaseSettings, SettingsConfigDict

_here     = os.path.dirname(os.path.abspath(__file__))
_app_dir  = os.path.dirname(_here)
_root     = os.path.dirname(_app_dir)
_env_file = os.path.join(_root, ".env")

print(f"[config] Loading .env from: {_env_file}")
print(f"[config] .env exists: {os.path.exists(_env_file)}")


class Settings(BaseSettings):
    supabase_url: str = ""
    supabase_service_key: str = ""
    jwt_secret: str = "change-me-in-production"
    jwt_algorithm: str = "HS256"
    access_token_expire_minutes: int = 1440

    # Google (legacy — no longer used)
    google_doc_ai_project_id: str = ""
    google_doc_ai_processor_id: str = ""
    google_doc_ai_location: str = "us"
    google_application_credentials: str = ""

    # Gemini (optional fallback)
    gemini_api_key: str = ""

    # OpenAI — primary OCR parser
    openai_api_key: str = ""

    # Tesseract path (Windows)
    tesseract_cmd: str = r"C:\Program Files\Tesseract-OCR\tesseract.exe"

    model_config = SettingsConfigDict(env_file=_env_file, extra="ignore")


settings = Settings()

print(f"[config] SUPABASE_URL loaded:    {bool(settings.supabase_url)}")
print(f"[config] SERVICE_KEY loaded:     {bool(settings.supabase_service_key)}")
print(f"[config] OPENAI_API_KEY loaded:  {bool(settings.openai_api_key)}")
print(f"[config] TESSERACT_CMD:          {settings.tesseract_cmd}")
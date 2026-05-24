from __future__ import annotations

from pathlib import Path

from clerk_backend_api import Clerk
from fastapi import FastAPI
from fastapi.responses import FileResponse
from fastapi.middleware.cors import CORSMiddleware

from .config import Settings, get_settings
from .database import Base, create_engine_and_session_factory
from .dependencies import (
    SubjectAuthenticator,
    default_subject_authenticator,
)
from .routers import auth_router, stats_router

_static_dir = Path(__file__).resolve().parent / "static"


def create_app(
    settings: Settings | None = None,
    *,
    subject_authenticator: SubjectAuthenticator | None = None,
) -> FastAPI:
  resolved_settings = settings or get_settings()
  engine, session_factory = create_engine_and_session_factory(
      resolved_settings.database_url
  )
  Base.metadata.create_all(bind=engine)

  app = FastAPI(title="Simon Says Shared Leaderboard API", version="1.0.0")
  app.state.settings = resolved_settings
  app.state.engine = engine
  app.state.session_factory = session_factory
  app.state.clerk_client = (
      Clerk(bearer_auth=resolved_settings.clerk_secret_key)
      if resolved_settings.clerk_secret_key
      else None
  )
  app.state.subject_authenticator = (
      subject_authenticator or default_subject_authenticator
  )

  if resolved_settings.cors_origins:
    app.add_middleware(
        CORSMiddleware,
        allow_origins=resolved_settings.cors_origins,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

  app.include_router(auth_router)
  app.include_router(stats_router)

  @app.get("/privacy", include_in_schema=False)
  def privacy_policy() -> FileResponse:
    return FileResponse(_static_dir / "privacy.html")

  @app.get("/account-deletion", include_in_schema=False)
  def account_deletion() -> FileResponse:
    return FileResponse(_static_dir / "account-deletion.html")

  @app.get("/healthz")
  def healthcheck() -> dict[str, str]:
    return {"status": "ok"}

  return app

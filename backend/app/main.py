from __future__ import annotations

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .config import Settings, get_settings
from .database import Base, create_engine_and_session_factory
from .routers import auth_router, stats_router


def create_app(settings: Settings | None = None) -> FastAPI:
  resolved_settings = settings or get_settings()
  engine, session_factory = create_engine_and_session_factory(
      resolved_settings.database_url
  )
  Base.metadata.create_all(bind=engine)

  app = FastAPI(title="Simon Says Shared Leaderboard API", version="1.0.0")
  app.state.settings = resolved_settings
  app.state.engine = engine
  app.state.session_factory = session_factory

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

  @app.get("/healthz")
  def healthcheck() -> dict[str, str]:
    return {"status": "ok"}

  return app

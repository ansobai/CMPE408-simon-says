from __future__ import annotations

from datetime import UTC, datetime

from fastapi import APIRouter, Depends, Query
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from ..config import Settings
from ..dependencies import get_current_user, get_db, get_settings
from ..models import GameSession, User
from ..schemas import GameSessionResponse, LeaderboardResponse, PlayerStatsResponse, SessionCreateRequest, SessionsResponse, UserResponse
from ..stats_service import build_player_stats

router = APIRouter(tags=["stats"])


@router.get("/leaderboard", response_model=LeaderboardResponse)
def leaderboard(
    limit: int | None = Query(default=None, ge=1),
    db: Session = Depends(get_db),
    settings: Settings = Depends(get_settings),
) -> LeaderboardResponse:
  resolved_limit = limit or settings.leaderboard_default_limit
  resolved_limit = min(resolved_limit, settings.leaderboard_max_limit)
  users = db.scalars(
      select(User)
      .order_by(
          User.best_score.desc(),
          User.last_played_at.desc().nullslast(),
          func.lower(User.username).asc(),
      )
      .limit(resolved_limit)
  ).all()
  return LeaderboardResponse(
      users=[UserResponse.model_validate(user) for user in users]
  )


@router.get("/sessions/me", response_model=SessionsResponse)
def read_my_sessions(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> SessionsResponse:
  sessions = db.scalars(
      select(GameSession)
      .where(GameSession.user_id == current_user.id)
      .order_by(GameSession.ended_at.desc())
  ).all()
  return SessionsResponse(
      sessions=[GameSessionResponse.model_validate(session) for session in sessions]
  )


@router.get("/stats/me", response_model=PlayerStatsResponse)
def read_my_stats(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> PlayerStatsResponse:
  sessions = db.scalars(
      select(GameSession)
      .where(GameSession.user_id == current_user.id)
      .order_by(GameSession.ended_at.desc())
  ).all()
  return build_player_stats(sessions)


@router.post("/sessions", response_model=GameSessionResponse, status_code=201)
def create_session(
    payload: SessionCreateRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> GameSessionResponse:
  ended_at_utc = payload.ended_at.astimezone(UTC)
  session = GameSession(
      user_id=current_user.id,
      mode=payload.mode.value,
      started_at=payload.started_at.astimezone(UTC),
      ended_at=ended_at_utc,
      score=payload.score,
      best_streak=payload.best_streak,
      round_reached=payload.round_reached,
      end_reason=payload.end_reason.value,
  )
  now = datetime.now(UTC)
  db.add(session)
  current_user.best_score = max(current_user.best_score, payload.score)
  current_user.updated_at = now
  existing_last_played = current_user.last_played_at
  if existing_last_played is not None and existing_last_played.tzinfo is None:
    existing_last_played = existing_last_played.replace(tzinfo=UTC)
  if existing_last_played is None or ended_at_utc > existing_last_played:
    current_user.last_played_at = ended_at_utc
  db.commit()
  db.refresh(session)
  return GameSessionResponse.model_validate(session)

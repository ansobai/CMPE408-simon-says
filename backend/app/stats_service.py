from __future__ import annotations

from .models import GameSession
from .schemas import PlayerStatsResponse


def build_player_stats(sessions: list[GameSession]) -> PlayerStatsResponse:
  if not sessions:
    return PlayerStatsResponse(
        best_streak=0,
        best_score=0,
        best_score_by_mode={"focus": 0, "overdrive": 0},
        total_sessions=0,
        total_score=0,
        total_rounds_reached=0,
        last_played_at=None,
    )

  best_score_by_mode = {"focus": 0, "overdrive": 0}
  best_streak = 0
  best_score = 0
  total_score = 0
  total_rounds_reached = 0
  last_played_at = None

  for session in sessions:
    total_score += session.score
    total_rounds_reached += session.round_reached
    if session.best_streak > best_streak:
      best_streak = session.best_streak
    if session.score > best_score:
      best_score = session.score
    if session.score > best_score_by_mode.get(session.mode, 0):
      best_score_by_mode[session.mode] = session.score
    if last_played_at is None or session.ended_at > last_played_at:
      last_played_at = session.ended_at

  return PlayerStatsResponse(
      best_streak=best_streak,
      best_score=best_score,
      best_score_by_mode=best_score_by_mode,
      total_sessions=len(sessions),
      total_score=total_score,
      total_rounds_reached=total_rounds_reached,
      last_played_at=last_played_at,
  )

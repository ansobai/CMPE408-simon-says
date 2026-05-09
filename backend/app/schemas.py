from __future__ import annotations

from datetime import UTC, datetime
from enum import Enum

from pydantic import BaseModel, ConfigDict, Field, field_serializer


class GameMode(str, Enum):
  focus = "focus"
  overdrive = "overdrive"


class SessionEndReason(str, Enum):
  wrong_tile = "wrongTile"
  timed_out = "timedOut"


class RegisterRequest(BaseModel):
  username: str
  password: str


class LoginRequest(BaseModel):
  username: str
  password: str


class UserResponse(BaseModel):
  model_config = ConfigDict(from_attributes=True)

  id: int
  username: str
  score: int
  created_at: datetime
  updated_at: datetime
  last_played_at: datetime | None = None

  @field_serializer("created_at", "updated_at", "last_played_at")
  def serialize_datetimes(self, value: datetime | None) -> str | None:
    return _serialize_datetime(value)


class AuthResponse(BaseModel):
  access_token: str
  token_type: str = "bearer"
  user: UserResponse


class LogoutResponse(BaseModel):
  success: bool = True


class SessionCreateRequest(BaseModel):
  mode: GameMode
  started_at: datetime
  ended_at: datetime
  score: int = Field(ge=0)
  best_streak: int = Field(ge=0)
  round_reached: int = Field(ge=0)
  end_reason: SessionEndReason


class GameSessionResponse(BaseModel):
  model_config = ConfigDict(from_attributes=True)

  id: str
  mode: str
  started_at: datetime
  ended_at: datetime
  score: int
  best_streak: int
  round_reached: int
  end_reason: str

  @field_serializer("started_at", "ended_at")
  def serialize_datetimes(self, value: datetime) -> str:
    serialized = _serialize_datetime(value)
    assert serialized is not None
    return serialized


class SessionsResponse(BaseModel):
  sessions: list[GameSessionResponse]


class LeaderboardResponse(BaseModel):
  users: list[UserResponse]


class PlayerStatsResponse(BaseModel):
  best_streak: int
  best_score: int
  best_score_by_mode: dict[str, int]
  total_sessions: int
  total_score: int
  total_rounds_reached: int
  last_played_at: datetime | None

  @field_serializer("last_played_at")
  def serialize_last_played_at(self, value: datetime | None) -> str | None:
    return _serialize_datetime(value)


def _serialize_datetime(value: datetime | None) -> str | None:
  if value is None:
    return None
  normalized = value if value.tzinfo is not None else value.replace(tzinfo=UTC)
  return normalized.astimezone(UTC).isoformat().replace("+00:00", "Z")

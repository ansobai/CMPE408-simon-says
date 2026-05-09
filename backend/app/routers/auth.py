from __future__ import annotations

from datetime import UTC, datetime

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from ..auth import create_access_token, hash_password, verify_password
from ..config import Settings
from ..dependencies import get_current_user, get_db, get_settings
from ..models import User
from ..schemas import AuthResponse, LoginRequest, LogoutResponse, RegisterRequest, UserResponse

router = APIRouter(tags=["auth"])


@router.post("/auth/register", response_model=AuthResponse, status_code=status.HTTP_201_CREATED)
def register(
    payload: RegisterRequest,
    db: Session = Depends(get_db),
    settings: Settings = Depends(get_settings),
) -> AuthResponse:
  normalized_username = _normalize_username(payload.username)
  _validate_password(payload.password)
  existing_user = db.scalar(
      select(User).where(User.username == normalized_username)
  )
  if existing_user is not None:
    raise HTTPException(
        status_code=status.HTTP_409_CONFLICT,
        detail="That username is already taken.",
    )

  now = datetime.now(UTC)
  user = User(
      username=normalized_username,
      password_hash=hash_password(payload.password),
      created_at=now,
      updated_at=now,
      best_score=0,
      last_played_at=None,
  )
  db.add(user)
  db.commit()
  db.refresh(user)
  return AuthResponse(
      access_token=create_access_token(user.id, settings),
      user=UserResponse.model_validate(user),
  )


@router.post("/auth/login", response_model=AuthResponse)
def login(
    payload: LoginRequest,
    db: Session = Depends(get_db),
    settings: Settings = Depends(get_settings),
) -> AuthResponse:
  normalized_username = payload.username.strip().lower()
  _validate_password(payload.password)
  user = db.scalar(select(User).where(User.username == normalized_username))
  if user is None or not verify_password(payload.password, user.password_hash):
    raise HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="That username or password does not match a shared account.",
    )

  return AuthResponse(
      access_token=create_access_token(user.id, settings),
      user=UserResponse.model_validate(user),
  )


@router.post("/auth/logout", response_model=LogoutResponse)
def logout(_: User = Depends(get_current_user)) -> LogoutResponse:
  return LogoutResponse()


@router.get("/me", response_model=UserResponse)
def read_me(current_user: User = Depends(get_current_user)) -> UserResponse:
  return UserResponse.model_validate(current_user)


def _normalize_username(username: str) -> str:
  normalized = username.strip()
  if len(normalized) < 3:
    raise HTTPException(
        status_code=status.HTTP_400_BAD_REQUEST,
        detail="Use a username with at least 3 characters.",
    )
  return normalized.lower()


def _validate_password(password: str) -> None:
  if len(password) < 4:
    raise HTTPException(
        status_code=status.HTTP_400_BAD_REQUEST,
        detail="Use a password with at least 4 characters.",
    )

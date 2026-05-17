from __future__ import annotations

import re
from dataclasses import dataclass
from datetime import UTC, datetime

from sqlalchemy import select
from sqlalchemy.orm import Session

from .models import User

_external_subject_prefix = "clerk:"
_generated_username_prefix = "player-"
_max_username_length = 64


@dataclass(frozen=True)
class AuthenticatedSubject:
  subject: str


def ensure_user_for_subject(db: Session, subject: str) -> User:
  user = load_user_by_subject(db, subject)
  if user is not None:
    return user

  now = datetime.now(UTC)
  user = User(
      username=_allocate_unique_username(db, _fallback_username(subject)),
      password_hash=_subject_marker(subject),
      created_at=now,
      updated_at=now,
      best_score=0,
      last_played_at=None,
  )
  db.add(user)
  db.commit()
  db.refresh(user)
  return user


def load_user_by_subject(db: Session, subject: str) -> User | None:
  return db.scalar(select(User).where(User.password_hash == _subject_marker(subject)))


def sync_user_for_subject(
    db: Session,
    subject: str,
    *,
    preferred_username: str | None,
    name: str | None,
    email: str | None,
) -> User:
  user = ensure_user_for_subject(db, subject)
  candidate = _resolve_preferred_username(
      preferred_username=preferred_username,
      name=name,
      email=email,
  )
  if candidate is None or not _is_generated_username(user.username):
    return user

  resolved = _allocate_unique_username(db, candidate, excluding_user_id=user.id)
  if resolved == user.username:
    return user

  user.username = resolved
  user.updated_at = datetime.now(UTC)
  db.add(user)
  db.commit()
  db.refresh(user)
  return user


def _resolve_preferred_username(
    *,
    preferred_username: str | None,
    name: str | None,
    email: str | None,
) -> str | None:
  for raw_value in (
      preferred_username,
      name,
      _email_local_part(email),
  ):
    normalized = normalize_username(raw_value)
    if normalized is not None:
      return normalized
  return None


def normalize_username(value: str | None) -> str | None:
  if value is None:
    return None

  normalized = re.sub(r"[^a-z0-9._-]+", "-", value.strip().lower())
  normalized = normalized.strip("._-")
  if len(normalized) < 3:
    return None
  return normalized[:_max_username_length]


def _email_local_part(email: str | None) -> str | None:
  if email is None or "@" not in email:
    return None
  return email.split("@", maxsplit=1)[0]


def _fallback_username(subject: str) -> str:
  compact = re.sub(r"[^a-z0-9]+", "", subject.lower())
  suffix = compact[-8:] if compact else "user"
  return f"{_generated_username_prefix}{suffix}"


def _is_generated_username(username: str) -> bool:
  return username.startswith(_generated_username_prefix)


def _subject_marker(subject: str) -> str:
  return f"{_external_subject_prefix}{subject}"


def _allocate_unique_username(
    db: Session,
    candidate: str,
    *,
    excluding_user_id: int | None = None,
) -> str:
  suffix = 1
  while True:
    proposal = candidate if suffix == 1 else _append_suffix(candidate, suffix)
    statement = select(User).where(User.username == proposal)
    if excluding_user_id is not None:
      statement = statement.where(User.id != excluding_user_id)
    if db.scalar(statement) is None:
      return proposal
    suffix += 1


def _append_suffix(candidate: str, suffix: int) -> str:
  suffix_text = f"-{suffix}"
  available = _max_username_length - len(suffix_text)
  trimmed = candidate[:available].rstrip("._-")
  return f"{trimmed}{suffix_text}"

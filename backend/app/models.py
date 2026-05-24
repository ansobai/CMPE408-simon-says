from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Index, Integer, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from .database import Base


class User(Base):
  __tablename__ = "users"
  __table_args__ = (
      Index("ix_users_best_score", "best_score", "last_played_at"),
  )

  id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
  username: Mapped[str] = mapped_column(String(64), nullable=False, unique=True)
  password_hash: Mapped[str] = mapped_column(String(255), nullable=False)
  created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
  updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
  best_score: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
  last_played_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
  sessions: Mapped[list["GameSession"]] = relationship(
      back_populates="user",
      cascade="all, delete-orphan",
  )

  @property
  def score(self) -> int:
    return self.best_score


class DeletedSubject(Base):
  __tablename__ = "deleted_subjects"

  subject: Mapped[str] = mapped_column(String(255), primary_key=True)
  deleted_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)


class GameSession(Base):
  __tablename__ = "game_sessions"
  __table_args__ = (
      Index("ix_game_sessions_user_id", "user_id"),
      Index("ix_game_sessions_ended_at", "ended_at"),
  )

  id: Mapped[str] = mapped_column(
      String(36),
      primary_key=True,
      default=lambda: str(uuid.uuid4()),
  )
  user_id: Mapped[int] = mapped_column(
      ForeignKey("users.id", ondelete="CASCADE"),
      nullable=False,
  )
  mode: Mapped[str] = mapped_column(String(32), nullable=False)
  started_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
  ended_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
  score: Mapped[int] = mapped_column(Integer, nullable=False)
  best_streak: Mapped[int] = mapped_column(Integer, nullable=False)
  round_reached: Mapped[int] = mapped_column(Integer, nullable=False)
  end_reason: Mapped[str] = mapped_column(String(32), nullable=False)
  user: Mapped[User] = relationship(back_populates="sessions")

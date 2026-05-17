from __future__ import annotations

from pathlib import Path

from fastapi import HTTPException, Request, status
from fastapi.testclient import TestClient

from backend.app.auth import AuthenticatedSubject
from backend.app.config import Settings
from backend.app.main import create_app


def _build_client(tmp_path: Path) -> TestClient:
  database_path = tmp_path / "test.db"
  settings = Settings(
      database_url=f"sqlite+pysqlite:///{database_path}",
      clerk_secret_key="sk_test_example",
      cors_origins=[],
  )
  app = create_app(settings, subject_authenticator=_fake_subject_authenticator)
  return TestClient(app)


def _fake_subject_authenticator(
    request: Request,
    _: Settings,
) -> AuthenticatedSubject:
  header = request.headers.get("Authorization", "")
  prefix = "Bearer test-subject:"
  if not header.startswith(prefix):
    raise HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Invalid access token.",
    )

  subject = header.removeprefix(prefix).strip()
  if not subject:
    raise HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Access token subject is invalid.",
    )

  return AuthenticatedSubject(subject=subject)


def _sync_user(
    client: TestClient,
    subject: str,
    *,
    username: str | None = None,
    name: str | None = None,
    email: str | None = None,
) -> dict:
  response = client.post(
      "/auth/sync",
      headers=_auth_headers(subject),
      json={
          "username": username,
          "name": name,
          "email": email,
      },
  )
  assert response.status_code == 200, response.text
  return response.json()


def _auth_headers(subject: str) -> dict[str, str]:
  return {"Authorization": f"Bearer test-subject:{subject}"}


def _session_payload(*, score: int, ended_at: str, mode: str = "focus") -> dict:
  return {
      "mode": mode,
      "started_at": "2026-05-04T10:00:00Z",
      "ended_at": ended_at,
      "score": score,
      "best_streak": 6,
      "round_reached": 6,
      "end_reason": "wrongTile",
  }


def test_sync_creates_user_and_prefers_clerk_identity(tmp_path: Path) -> None:
  client = _build_client(tmp_path)

  created = _sync_user(
      client,
      "user_alpha",
      username="Bara",
      email="bara@example.com",
  )
  repeated = _sync_user(
      client,
      "user_alpha",
      username="someone-else",
      email="bara@example.com",
  )

  assert created["username"] == "bara"
  assert repeated["id"] == created["id"]
  assert repeated["username"] == "bara"


def test_sync_resolves_duplicate_usernames(tmp_path: Path) -> None:
  client = _build_client(tmp_path)

  first = _sync_user(client, "user_1", username="bara")
  second = _sync_user(client, "user_2", username="bara")

  assert first["username"] == "bara"
  assert second["username"] == "bara-2"


def test_authenticated_me_returns_current_user(tmp_path: Path) -> None:
  client = _build_client(tmp_path)
  _sync_user(client, "user_bara", username="bara")

  me = client.get("/me", headers=_auth_headers("user_bara"))

  assert me.status_code == 200
  body = me.json()
  assert body["username"] == "bara"
  assert body["score"] == 0


def test_me_auto_creates_user_when_profile_is_not_synced(tmp_path: Path) -> None:
  client = _build_client(tmp_path)

  me = client.get("/me", headers=_auth_headers("user_without_sync"))

  assert me.status_code == 200
  assert me.json()["username"].startswith("player-")


def test_session_submission_updates_best_score_and_stats(tmp_path: Path) -> None:
  client = _build_client(tmp_path)
  _sync_user(client, "user_bara", username="bara")
  headers = _auth_headers("user_bara")

  first = client.post(
      "/sessions",
      json=_session_payload(score=120, ended_at="2026-05-04T10:05:00Z"),
      headers=headers,
  )
  second = client.post(
      "/sessions",
      json=_session_payload(
          score=90,
          ended_at="2026-05-04T10:08:00Z",
          mode="overdrive",
      ),
      headers=headers,
  )
  me = client.get("/me", headers=headers)
  stats = client.get("/stats/me", headers=headers)

  assert first.status_code == 201, first.text
  assert second.status_code == 201, second.text
  assert me.json()["score"] == 120
  assert stats.json() == {
      "best_streak": 6,
      "best_score": 120,
      "best_score_by_mode": {"focus": 120, "overdrive": 90},
      "total_sessions": 2,
      "total_score": 210,
      "total_rounds_reached": 12,
      "last_played_at": "2026-05-04T10:08:00Z",
  }


def test_leaderboard_orders_by_score_then_last_played_then_username_and_limit(
    tmp_path: Path,
) -> None:
  client = _build_client(tmp_path)

  _sync_user(client, "user_adam", username="adam")
  _sync_user(client, "user_bob", username="bob")
  _sync_user(client, "user_zoe", username="zoe")
  _sync_user(client, "user_low", username="low")

  client.post(
      "/sessions",
      json=_session_payload(score=500, ended_at="2026-05-04T11:00:00Z"),
      headers=_auth_headers("user_bob"),
  )
  client.post(
      "/sessions",
      json=_session_payload(score=500, ended_at="2026-05-04T11:00:00Z"),
      headers=_auth_headers("user_adam"),
  )
  client.post(
      "/sessions",
      json=_session_payload(score=500, ended_at="2026-05-04T10:00:00Z"),
      headers=_auth_headers("user_zoe"),
  )
  client.post(
      "/sessions",
      json=_session_payload(score=120, ended_at="2026-05-04T12:00:00Z"),
      headers=_auth_headers("user_low"),
  )

  leaderboard = client.get("/leaderboard?limit=3")

  assert leaderboard.status_code == 200
  usernames = [user["username"] for user in leaderboard.json()["users"]]
  assert usernames == ["adam", "bob", "zoe"]


def test_unauthorized_requests_are_rejected(tmp_path: Path) -> None:
  client = _build_client(tmp_path)

  me = client.get("/me")
  sessions = client.get("/sessions/me")
  stats = client.get("/stats/me")
  submit = client.post(
      "/sessions",
      json=_session_payload(score=50, ended_at="2026-05-04T10:05:00Z"),
  )

  assert me.status_code == 401
  assert sessions.status_code == 401
  assert stats.status_code == 401
  assert submit.status_code == 401

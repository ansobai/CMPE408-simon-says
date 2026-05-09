from __future__ import annotations

from pathlib import Path

from fastapi.testclient import TestClient

from backend.app.config import Settings
from backend.app.main import create_app


def _build_client(tmp_path: Path) -> TestClient:
  database_path = tmp_path / "test.db"
  settings = Settings(
      database_url=f"sqlite+pysqlite:///{database_path}",
      jwt_secret="test-secret-that-is-at-least-32-bytes",
      cors_origins=[],
  )
  app = create_app(settings)
  return TestClient(app)


def _register(client: TestClient, username: str, password: str = "1234") -> dict:
  response = client.post(
      "/auth/register",
      json={"username": username, "password": password},
  )
  assert response.status_code == 201, response.text
  return response.json()


def _login(client: TestClient, username: str, password: str = "1234") -> dict:
  response = client.post(
      "/auth/login",
      json={"username": username, "password": password},
  )
  assert response.status_code == 200, response.text
  return response.json()


def _auth_headers(token: str) -> dict[str, str]:
  return {"Authorization": f"Bearer {token}"}


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


def test_register_rejects_duplicate_username(tmp_path: Path) -> None:
  client = _build_client(tmp_path)
  _register(client, "bara")

  duplicate = client.post(
      "/auth/register",
      json={"username": "BARA", "password": "1234"},
  )

  assert duplicate.status_code == 409
  assert duplicate.json()["detail"] == "That username is already taken."


def test_login_success_and_failure(tmp_path: Path) -> None:
  client = _build_client(tmp_path)
  _register(client, "bara")

  success = client.post(
      "/auth/login",
      json={"username": "bara", "password": "1234"},
  )
  failure = client.post(
      "/auth/login",
      json={"username": "bara", "password": "wrong"},
  )

  assert success.status_code == 200
  assert "access_token" in success.json()
  assert failure.status_code == 401


def test_authenticated_me_returns_current_user(tmp_path: Path) -> None:
  client = _build_client(tmp_path)
  auth_payload = _register(client, "bara")

  me = client.get("/me", headers=_auth_headers(auth_payload["access_token"]))

  assert me.status_code == 200
  body = me.json()
  assert body["username"] == "bara"
  assert body["score"] == 0


def test_session_submission_updates_best_score_and_stats(tmp_path: Path) -> None:
  client = _build_client(tmp_path)
  auth_payload = _register(client, "bara")
  headers = _auth_headers(auth_payload["access_token"])

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

  adam = _register(client, "adam")
  bob = _register(client, "bob")
  zoe = _register(client, "zoe")
  low = _register(client, "low")

  client.post(
      "/sessions",
      json=_session_payload(score=500, ended_at="2026-05-04T11:00:00Z"),
      headers=_auth_headers(bob["access_token"]),
  )
  client.post(
      "/sessions",
      json=_session_payload(score=500, ended_at="2026-05-04T11:00:00Z"),
      headers=_auth_headers(adam["access_token"]),
  )
  client.post(
      "/sessions",
      json=_session_payload(score=500, ended_at="2026-05-04T10:00:00Z"),
      headers=_auth_headers(zoe["access_token"]),
  )
  client.post(
      "/sessions",
      json=_session_payload(score=120, ended_at="2026-05-04T12:00:00Z"),
      headers=_auth_headers(low["access_token"]),
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
  submit = client.post("/sessions", json=_session_payload(score=50, ended_at="2026-05-04T10:05:00Z"))

  assert me.status_code == 401
  assert sessions.status_code == 401
  assert stats.status_code == 401
  assert submit.status_code == 401

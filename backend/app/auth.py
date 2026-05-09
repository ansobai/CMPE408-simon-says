from __future__ import annotations

import base64
import hashlib
import hmac
import os
from datetime import UTC, datetime, timedelta

import jwt
from jwt import InvalidTokenError

from .config import Settings


class TokenError(Exception):
  pass


def hash_password(password: str) -> str:
  salt = os.urandom(16)
  derived_key = hashlib.scrypt(
      password.encode("utf-8"),
      salt=salt,
      n=16384,
      r=8,
      p=1,
      dklen=64,
  )
  return (
      f"{base64.urlsafe_b64encode(salt).decode('ascii')}"
      f":{base64.urlsafe_b64encode(derived_key).decode('ascii')}"
  )


def verify_password(password: str, password_hash: str) -> bool:
  try:
    salt_b64, expected_b64 = password_hash.split(":", maxsplit=1)
  except ValueError:
    return False

  salt = base64.urlsafe_b64decode(salt_b64.encode("ascii"))
  expected = base64.urlsafe_b64decode(expected_b64.encode("ascii"))
  candidate = hashlib.scrypt(
      password.encode("utf-8"),
      salt=salt,
      n=16384,
      r=8,
      p=1,
      dklen=len(expected),
  )
  return hmac.compare_digest(candidate, expected)


def create_access_token(user_id: int, settings: Settings) -> str:
  now = datetime.now(UTC)
  payload = {
      "sub": str(user_id),
      "iat": int(now.timestamp()),
      "exp": int(
          (now + timedelta(minutes=settings.access_token_expire_minutes)).timestamp()
      ),
  }
  return jwt.encode(payload, settings.jwt_secret, algorithm=settings.jwt_algorithm)


def decode_access_token(token: str, settings: Settings) -> int:
  try:
    payload = jwt.decode(
        token,
        settings.jwt_secret,
        algorithms=[settings.jwt_algorithm],
    )
  except InvalidTokenError as error:
    raise TokenError("Invalid access token.") from error

  subject = payload.get("sub")
  if subject is None:
    raise TokenError("Access token is missing the subject claim.")

  try:
    return int(subject)
  except ValueError as error:
    raise TokenError("Access token subject is invalid.") from error

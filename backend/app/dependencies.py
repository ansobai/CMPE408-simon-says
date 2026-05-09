from collections.abc import Generator

from fastapi import Depends, HTTPException, Request, status
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.orm import Session

from .auth import TokenError, decode_access_token
from .config import Settings
from .models import User

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/login", auto_error=False)


def get_settings(request: Request) -> Settings:
  return request.app.state.settings


def get_db(request: Request) -> Generator[Session, None, None]:
  session_factory = request.app.state.session_factory
  database_session = session_factory()
  try:
    yield database_session
  finally:
    database_session.close()


def get_current_user(
    token: str | None = Depends(oauth2_scheme),
    settings: Settings = Depends(get_settings),
    db: Session = Depends(get_db),
) -> User:
  if token is None:
    raise HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Missing access token.",
    )

  try:
    user_id = decode_access_token(token, settings)
  except TokenError as error:
    raise HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail=str(error),
    ) from error

  user = db.get(User, user_id)
  if user is None:
    raise HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="The access token no longer matches an active user.",
    )

  return user

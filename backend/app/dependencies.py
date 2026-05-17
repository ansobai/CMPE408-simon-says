from collections.abc import Callable, Generator

from fastapi import Depends, HTTPException, Request, status
from fastapi.security import OAuth2PasswordBearer
from clerk_backend_api.security.types import AuthenticateRequestOptions
from sqlalchemy.orm import Session

from .auth import AuthenticatedSubject, ensure_user_for_subject
from .config import Settings
from .models import User

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/sync", auto_error=False)
SubjectAuthenticator = Callable[[Request, Settings], AuthenticatedSubject]


def get_settings(request: Request) -> Settings:
  return request.app.state.settings


def get_db(request: Request) -> Generator[Session, None, None]:
  session_factory = request.app.state.session_factory
  database_session = session_factory()
  try:
    yield database_session
  finally:
    database_session.close()


def default_subject_authenticator(
    request: Request,
    settings: Settings,
) -> AuthenticatedSubject:
  clerk_client = request.app.state.clerk_client
  if clerk_client is None:
    raise HTTPException(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        detail="Clerk authentication is not configured on the server.",
    )

  request_state = clerk_client.authenticate_request(
      request,
      AuthenticateRequestOptions(
          authorized_parties=settings.clerk_authorized_parties or None,
      ),
  )
  if not request_state.is_signed_in:
    raise HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail=request_state.reason or "Invalid access token.",
    )

  payload = request_state.payload or {}
  subject = payload.get("sub")
  if not isinstance(subject, str) or not subject:
    raise HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Access token subject is invalid.",
    )

  return AuthenticatedSubject(subject=subject)


def get_authenticated_subject(
    request: Request,
    token: str | None = Depends(oauth2_scheme),
    settings: Settings = Depends(get_settings),
) -> AuthenticatedSubject:
  if token is None:
    raise HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Missing access token.",
    )

  authenticator: SubjectAuthenticator = request.app.state.subject_authenticator
  return authenticator(request, settings)


def get_current_user(
    authenticated_subject: AuthenticatedSubject = Depends(get_authenticated_subject),
    db: Session = Depends(get_db),
) -> User:
  return ensure_user_for_subject(db, authenticated_subject.subject)

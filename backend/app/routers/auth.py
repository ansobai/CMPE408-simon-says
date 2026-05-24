from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Response, status
from sqlalchemy.orm import Session

from ..auth import (
    AuthenticatedSubject,
    SubjectDeletedError,
    delete_user_for_subject,
    sync_user_for_subject,
)
from ..dependencies import get_authenticated_subject, get_current_user, get_db
from ..models import User
from ..schemas import SyncUserRequest, UserResponse

router = APIRouter(tags=["auth"])


@router.post("/auth/sync", response_model=UserResponse)
def sync_user(
    payload: SyncUserRequest,
    authenticated_subject: AuthenticatedSubject = Depends(get_authenticated_subject),
    db: Session = Depends(get_db),
 ) -> UserResponse:
  try:
    user = sync_user_for_subject(
        db,
        authenticated_subject.subject,
        preferred_username=payload.username,
        name=payload.name,
        email=payload.email,
    )
  except SubjectDeletedError as error:
    raise HTTPException(
        status_code=status.HTTP_410_GONE,
        detail="This account has been deleted.",
    ) from error
  return UserResponse.model_validate(user)


@router.get("/me", response_model=UserResponse)
def read_me(current_user: User = Depends(get_current_user)) -> UserResponse:
  return UserResponse.model_validate(current_user)


@router.delete("/me", status_code=status.HTTP_204_NO_CONTENT)
def delete_me(
    authenticated_subject: AuthenticatedSubject = Depends(get_authenticated_subject),
    db: Session = Depends(get_db),
) -> Response:
  delete_user_for_subject(db, authenticated_subject.subject)
  return Response(status_code=status.HTTP_204_NO_CONTENT)

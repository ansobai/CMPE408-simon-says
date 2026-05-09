from sqlalchemy import create_engine
from sqlalchemy.orm import DeclarativeBase, Session, sessionmaker


class Base(DeclarativeBase):
  pass


def create_engine_and_session_factory(database_url: str) -> tuple[object, sessionmaker[Session]]:
  connect_args: dict[str, object] = {}
  if database_url.startswith("sqlite"):
    connect_args["check_same_thread"] = False

  engine = create_engine(
      database_url,
      connect_args=connect_args,
      future=True,
      pool_pre_ping=True,
  )
  session_factory = sessionmaker(
      bind=engine,
      autoflush=False,
      autocommit=False,
      expire_on_commit=False,
      class_=Session,
  )
  return engine, session_factory

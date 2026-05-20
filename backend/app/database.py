from sqlalchemy import create_engine
from sqlalchemy.orm import DeclarativeBase, Session, sessionmaker


class Base(DeclarativeBase):
  pass


def create_engine_and_session_factory(database_url: str) -> tuple[object, sessionmaker[Session]]:
  engine = create_engine(
      database_url,
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

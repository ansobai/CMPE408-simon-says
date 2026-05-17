from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
  database_url: str = (
      "postgresql+psycopg://postgres:postgres@localhost:5432/simon_says"
  )
  clerk_secret_key: str = ""
  clerk_authorized_parties: list[str] = []
  cors_origins: list[str] = ["*"]
  leaderboard_default_limit: int = 25
  leaderboard_max_limit: int = 100

  model_config = SettingsConfigDict(
      env_file=".env",
      env_file_encoding="utf-8",
      extra="ignore",
  )


@lru_cache
def get_settings() -> Settings:
  return Settings()

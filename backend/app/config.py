from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
  database_url: str = (
      "postgresql+psycopg://postgres:postgres@localhost:5432/simon_says"
  )
  jwt_secret: str = "change-me"
  jwt_algorithm: str = "HS256"
  access_token_expire_minutes: int = 60 * 24 * 7
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

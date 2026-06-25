from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from datetime import datetime
from typing import Optional


@dataclass
class PostContent:
    caption: str
    media_path: Optional[str] = None
    hashtags: list[str] = field(default_factory=list)
    scheduled_at: Optional[datetime] = None


@dataclass
class PostResult:
    success: bool
    platform: str
    post_id: Optional[str] = None
    url: Optional[str] = None
    error: Optional[str] = None
    posted_at: Optional[datetime] = None


class SNSPoster(ABC):
    def __init__(self, credentials: dict):
        self.credentials = credentials
        self._authenticated = False

    @abstractmethod
    def authenticate(self) -> bool:
        """認証を行い、成功したら True を返す"""

    @abstractmethod
    def post(self, content: PostContent) -> PostResult:
        """コンテンツを投稿する"""

    @abstractmethod
    def get_account_info(self) -> dict:
        """アカウント情報を返す"""

    @property
    def is_ready(self) -> bool:
        return self._authenticated

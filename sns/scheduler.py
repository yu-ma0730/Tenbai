"""
投稿スケジューラ。
APScheduler を使って予約投稿を管理する。
"""

import uuid
from datetime import datetime
from typing import Optional

from apscheduler.schedulers.background import BackgroundScheduler

from .base import PostContent, PostResult
from .instagram import InstagramPoster
from .tiktok import TikTokPoster

# プラットフォーム名 → クラスのマッピング
PLATFORM_MAP = {
    "instagram": InstagramPoster,
    "tiktok": TikTokPoster,
}


class PostScheduler:
    def __init__(self):
        self._scheduler = BackgroundScheduler(timezone="Asia/Tokyo")
        self._posts: dict[str, dict] = {}  # 本番では DB に保存

    def start(self):
        if not self._scheduler.running:
            self._scheduler.start()

    def shutdown(self):
        if self._scheduler.running:
            self._scheduler.shutdown(wait=False)

    def add_post(
        self,
        platform: str,
        content: PostContent,
        credentials: dict,
        scheduled_at: Optional[datetime] = None,
    ) -> dict:
        """投稿を登録する。scheduled_at が None なら即時投稿。"""
        if platform not in PLATFORM_MAP:
            raise ValueError(f"未対応のプラットフォーム: {platform}")

        post_id = str(uuid.uuid4())
        record = {
            "id": post_id,
            "platform": platform,
            "caption": content.caption,
            "media_path": content.media_path,
            "hashtags": content.hashtags,
            "scheduled_at": scheduled_at.isoformat() if scheduled_at else None,
            "status": "pending",
            "result": None,
            "created_at": datetime.now().isoformat(),
        }
        self._posts[post_id] = record

        if scheduled_at:
            self._scheduler.add_job(
                self._execute_post,
                trigger="date",
                run_date=scheduled_at,
                args=[post_id, platform, content, credentials],
                id=post_id,
            )
            record["status"] = "scheduled"
        else:
            result = self._execute_post(post_id, platform, content, credentials)
            record["status"] = "done" if result.success else "failed"
            record["result"] = {
                "success": result.success,
                "post_id": result.post_id,
                "url": result.url,
                "error": result.error,
            }

        return record

    def cancel_post(self, post_id: str) -> bool:
        """予約投稿をキャンセルする"""
        record = self._posts.get(post_id)
        if not record or record["status"] != "scheduled":
            return False
        try:
            self._scheduler.remove_job(post_id)
            record["status"] = "cancelled"
            return True
        except Exception:
            return False

    def get_post(self, post_id: str) -> Optional[dict]:
        return self._posts.get(post_id)

    def get_all_posts(self) -> list[dict]:
        return list(self._posts.values())

    def _execute_post(
        self,
        post_id: str,
        platform: str,
        content: PostContent,
        credentials: dict,
    ) -> PostResult:
        poster = PLATFORM_MAP[platform](credentials)
        poster.authenticate()
        result = poster.post(content)

        if post_id in self._posts:
            record = self._posts[post_id]
            record["status"] = "done" if result.success else "failed"
            record["result"] = {
                "success": result.success,
                "post_id": result.post_id,
                "url": result.url,
                "error": result.error,
            }
        return result


# アプリ全体で共有するシングルトン
scheduler = PostScheduler()

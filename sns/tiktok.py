"""
TikTok for Developers (Content Posting API v2) を使った投稿モジュール。
動画ファイルの投稿が主。

必要な認証情報:
  TIKTOK_CLIENT_KEY     - アプリのクライアントキー
  TIKTOK_CLIENT_SECRET  - アプリのクライアントシークレット
  TIKTOK_ACCESS_TOKEN   - ユーザーのアクセストークン（OAuth 2.0）
"""

import requests
from .base import SNSPoster, PostContent, PostResult

BASE_URL = "https://open.tiktokapis.com/v2"


class TikTokPoster(SNSPoster):
    PLATFORM = "tiktok"

    def authenticate(self) -> bool:
        token = self.credentials.get("access_token")
        if not token:
            return False

        # TODO: /user/info/ でトークン確認
        # resp = requests.get(
        #     f"{BASE_URL}/user/info/",
        #     headers={"Authorization": f"Bearer {token}"},
        # )
        # self._authenticated = resp.ok

        self._authenticated = False  # 実装後に削除
        return self._authenticated

    def post(self, content: PostContent) -> PostResult:
        """
        TikTok への動画投稿フロー:
          1. 動画をアップロード (POST /video/upload/)
          2. 投稿を作成        (POST /video/publish/)
        """
        if not self._authenticated:
            return PostResult(success=False, platform=self.PLATFORM, error="未認証")

        if not content.media_path:
            return PostResult(success=False, platform=self.PLATFORM, error="動画ファイルが必要です")

        # TODO: Step 1 - 動画アップロード
        # video_id = self._upload_video(content.media_path)

        # TODO: Step 2 - 投稿作成
        # post_id = self._create_post(video_id, content)

        return PostResult(success=False, platform=self.PLATFORM, error="未実装")

    def get_account_info(self) -> dict:
        # TODO: GET /user/info/?fields=open_id,union_id,display_name,follower_count
        return {}

    def _upload_video(self, media_path: str) -> str:
        """動画をアップロードし video_id を返す"""
        token = self.credentials["access_token"]
        with open(media_path, "rb") as f:
            resp = requests.post(
                f"{BASE_URL}/video/upload/",
                headers={"Authorization": f"Bearer {token}"},
                files={"video": f},
            )
        resp.raise_for_status()
        return resp.json()["data"]["video"]["id"]

    def _create_post(self, video_id: str, content: PostContent) -> str:
        """投稿を作成し post_id を返す"""
        token = self.credentials["access_token"]
        caption = content.caption
        if content.hashtags:
            caption += " " + " ".join(f"#{h}" for h in content.hashtags)

        resp = requests.post(
            f"{BASE_URL}/video/publish/",
            headers={"Authorization": f"Bearer {token}"},
            json={
                "video_id": video_id,
                "caption": caption,
                "privacy_level": "PUBLIC_TO_EVERYONE",
            },
        )
        resp.raise_for_status()
        return resp.json()["data"]["post_id"]

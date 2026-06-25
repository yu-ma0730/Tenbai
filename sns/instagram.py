"""
Instagram Graph API を使った投稿モジュール。
ビジネス/クリエイターアカウント + Facebookページが必要。

必要な認証情報:
  INSTAGRAM_ACCESS_TOKEN  - ロングタームアクセストークン
  INSTAGRAM_ACCOUNT_ID    - Instagram ビジネスアカウントID
"""

import requests
from datetime import datetime
from .base import SNSPoster, PostContent, PostResult

GRAPH_API_VERSION = "v19.0"
BASE_URL = f"https://graph.facebook.com/{GRAPH_API_VERSION}"


class InstagramPoster(SNSPoster):
    PLATFORM = "instagram"

    def authenticate(self) -> bool:
        token = self.credentials.get("access_token")
        account_id = self.credentials.get("account_id")
        if not token or not account_id:
            return False

        # TODO: トークンの有効性を /me エンドポイントで確認する
        # resp = requests.get(f"{BASE_URL}/me", params={"access_token": token})
        # self._authenticated = resp.ok

        self._authenticated = False  # 実装後に削除
        return self._authenticated

    def post(self, content: PostContent) -> PostResult:
        """
        Instagram への投稿フロー:
          1. メディアコンテナを作成 (POST /{account_id}/media)
          2. コンテナを公開      (POST /{account_id}/media_publish)
        """
        if not self._authenticated:
            return PostResult(success=False, platform=self.PLATFORM, error="未認証")

        # TODO: Step 1 - メディアコンテナ作成
        # container_id = self._create_media_container(content)

        # TODO: Step 2 - 公開
        # post_id = self._publish_container(container_id)

        # TODO: 実装後にここを削除してリターン
        return PostResult(success=False, platform=self.PLATFORM, error="未実装")

    def get_account_info(self) -> dict:
        # TODO: GET /{account_id}?fields=username,followers_count
        return {}

    def _create_media_container(self, content: PostContent) -> str:
        """メディアコンテナを作成し container_id を返す"""
        account_id = self.credentials["account_id"]
        token = self.credentials["access_token"]
        caption = content.caption
        if content.hashtags:
            caption += "\n" + " ".join(f"#{h}" for h in content.hashtags)

        params = {
            "caption": caption,
            "access_token": token,
        }
        if content.media_path:
            params["image_url"] = content.media_path  # 公開URLが必要

        resp = requests.post(f"{BASE_URL}/{account_id}/media", data=params)
        resp.raise_for_status()
        return resp.json()["id"]

    def _publish_container(self, container_id: str) -> str:
        """コンテナを公開し投稿IDを返す"""
        account_id = self.credentials["account_id"]
        token = self.credentials["access_token"]

        resp = requests.post(
            f"{BASE_URL}/{account_id}/media_publish",
            data={"creation_id": container_id, "access_token": token},
        )
        resp.raise_for_status()
        return resp.json()["id"]

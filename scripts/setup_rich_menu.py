"""LINEリッチメニューを作成し、画像をアップロードして全ユーザーのデフォルトに設定する。

事前準備:
    1. python scripts/generate_rich_menu_image.py で static/richmenu/rich_menu.png を生成
    2. .env に LINE_ACCESS_TOKEN を設定

使い方:
    python scripts/setup_rich_menu.py
"""
import os
import sys

import requests
from dotenv import load_dotenv

load_dotenv()

LINE_API = "https://api.line.me/v2/bot"
LINE_DATA_API = "https://api-data.line.me/v2/bot"
IMAGE_PATH = os.path.join(os.path.dirname(os.path.dirname(__file__)), "static", "richmenu", "rich_menu.png")

RICH_MENU_NAME = "占いBot標準メニュー"

RICH_MENU_BODY = {
    "size": {"width": 2500, "height": 843},
    "selected": True,
    "name": RICH_MENU_NAME,
    "chatBarText": "メニュー",
    "areas": [
        {
            "bounds": {"x": 0, "y": 0, "width": 834, "height": 843},
            "action": {"type": "message", "label": "今日の運勢", "text": "占い"},
        },
        {
            "bounds": {"x": 834, "y": 0, "width": 833, "height": 843},
            "action": {"type": "message", "label": "他の人を占う", "text": "他の人を占う"},
        },
        {
            "bounds": {"x": 1667, "y": 0, "width": 833, "height": 843},
            "action": {"type": "message", "label": "登録情報をリセット", "text": "リセット"},
        },
    ],
}


def _headers(token: str, content_type: str | None = None) -> dict:
    headers = {"Authorization": f"Bearer {token}"}
    if content_type:
        headers["Content-Type"] = content_type
    return headers


def delete_existing_menus(token: str) -> None:
    res = requests.get(f"{LINE_API}/richmenu/list", headers=_headers(token), timeout=10)
    res.raise_for_status()
    for menu in res.json().get("richmenus", []):
        if menu.get("name") == RICH_MENU_NAME:
            requests.delete(f"{LINE_API}/richmenu/{menu['richMenuId']}", headers=_headers(token), timeout=10)
            print(f"既存メニューを削除しました: {menu['richMenuId']}")


def create_rich_menu(token: str) -> str:
    res = requests.post(
        f"{LINE_API}/richmenu",
        headers=_headers(token, "application/json"),
        json=RICH_MENU_BODY,
        timeout=10,
    )
    res.raise_for_status()
    rich_menu_id = res.json()["richMenuId"]
    print(f"リッチメニューを作成しました: {rich_menu_id}")
    return rich_menu_id


def upload_image(token: str, rich_menu_id: str) -> None:
    with open(IMAGE_PATH, "rb") as f:
        res = requests.post(
            f"{LINE_DATA_API}/richmenu/{rich_menu_id}/content",
            headers=_headers(token, "image/png"),
            data=f.read(),
            timeout=30,
        )
    res.raise_for_status()
    print("画像をアップロードしました")


def set_default(token: str, rich_menu_id: str) -> None:
    res = requests.post(f"{LINE_API}/user/all/richmenu/{rich_menu_id}", headers=_headers(token), timeout=10)
    res.raise_for_status()
    print("全ユーザーのデフォルトメニューに設定しました")


def main() -> None:
    token = os.environ.get("LINE_ACCESS_TOKEN", "")
    if not token:
        print("LINE_ACCESS_TOKEN が設定されていません（.env を確認してください）", file=sys.stderr)
        sys.exit(1)
    if not os.path.exists(IMAGE_PATH):
        print(f"画像が見つかりません: {IMAGE_PATH}\n先に scripts/generate_rich_menu_image.py を実行してください", file=sys.stderr)
        sys.exit(1)

    delete_existing_menus(token)
    rich_menu_id = create_rich_menu(token)
    upload_image(token, rich_menu_id)
    set_default(token, rich_menu_id)
    print("完了しました🎉")


if __name__ == "__main__":
    main()

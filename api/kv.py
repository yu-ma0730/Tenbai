import os

import requests


def is_configured() -> bool:
    return bool(os.environ.get("KV_REST_API_URL")) and bool(os.environ.get("KV_REST_API_TOKEN"))


def pipeline(commands: list) -> list | None:
    """Upstash RedisのREST APIにパイプラインでコマンドを送る。未設定ならNoneを返す。"""
    if not is_configured():
        return None
    url = os.environ["KV_REST_API_URL"].rstrip("/")
    token = os.environ["KV_REST_API_TOKEN"]
    res = requests.post(
        f"{url}/pipeline",
        headers={"Authorization": f"Bearer {token}"},
        json=commands,
        timeout=5,
    )
    res.raise_for_status()
    return [item.get("result") for item in res.json()]


def cmd(*parts) -> object | None:
    result = pipeline([list(parts)])
    return result[0] if result is not None else None

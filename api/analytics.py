import hashlib
import os
from datetime import date

import requests


def _kv_configured() -> bool:
    return bool(os.environ.get("KV_REST_API_URL")) and bool(os.environ.get("KV_REST_API_TOKEN"))


def _pipeline(commands: list) -> list | None:
    """Upstash RedisのREST APIにパイプラインでコマンドを送る"""
    if not _kv_configured():
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


def _cmd(*parts) -> object | None:
    result = _pipeline([list(parts)])
    return result[0] if result else None


def make_visitor_id(ip: str, user_agent: str) -> str:
    """Cookie不要で日次のおおよそのユニーク訪問者を数えるためのハッシュ"""
    raw = f"{ip}:{user_agent}:{date.today().isoformat()}"
    return hashlib.sha256(raw.encode("utf-8")).hexdigest()[:16]


def track_event(site: str, path: str, referrer: str, visitor_id: str) -> bool:
    today = date.today().isoformat()
    result = _pipeline([
        ["INCR", f"pv:{site}:{today}"],
        ["PFADD", f"uv:{site}:{today}", visitor_id],
        ["ZINCRBY", f"pages:{site}:{today}", 1, path or "/"],
        ["ZINCRBY", f"referrers:{site}:{today}", 1, referrer or "(direct)"],
        ["SADD", "analytics:sites", site],
    ])
    return result is not None


def get_stats(site: str, day: str) -> dict | None:
    results = _pipeline([
        ["GET", f"pv:{site}:{day}"],
        ["PFCOUNT", f"uv:{site}:{day}"],
        ["ZREVRANGE", f"pages:{site}:{day}", "0", "9", "WITHSCORES"],
        ["ZREVRANGE", f"referrers:{site}:{day}", "0", "9", "WITHSCORES"],
    ])
    if results is None:
        return None
    pv, uv, pages_raw, referrers_raw = results
    return {
        "pv": int(pv or 0),
        "uv": int(uv or 0),
        "pages": _score_pairs(pages_raw),
        "referrers": _score_pairs(referrers_raw),
    }


def list_sites() -> list:
    return _cmd("SMEMBERS", "analytics:sites") or []


def _score_pairs(flat: list | None) -> list:
    flat = flat or []
    return [
        {"name": flat[i], "count": int(float(flat[i + 1]))}
        for i in range(0, len(flat) - 1, 2)
    ]

import hashlib
from datetime import date

from api import kv


def make_visitor_id(ip: str, user_agent: str) -> str:
    """Cookie不要で日次のおおよそのユニーク訪問者を数えるためのハッシュ"""
    raw = f"{ip}:{user_agent}:{date.today().isoformat()}"
    return hashlib.sha256(raw.encode("utf-8")).hexdigest()[:16]


def track_event(site: str, path: str, referrer: str, visitor_id: str) -> bool:
    today = date.today().isoformat()
    result = kv.pipeline([
        ["INCR", f"pv:{site}:{today}"],
        ["PFADD", f"uv:{site}:{today}", visitor_id],
        ["ZINCRBY", f"pages:{site}:{today}", 1, path or "/"],
        ["ZINCRBY", f"referrers:{site}:{today}", 1, referrer or "(direct)"],
        ["SADD", "analytics:sites", site],
    ])
    return result is not None


def get_stats(site: str, day: str) -> dict | None:
    results = kv.pipeline([
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
    return kv.cmd("SMEMBERS", "analytics:sites") or []


def _score_pairs(flat: list | None) -> list:
    flat = flat or []
    return [
        {"name": flat[i], "count": int(float(flat[i + 1]))}
        for i in range(0, len(flat) - 1, 2)
    ]

import hashlib
import hmac
import base64
import json
import os
import requests

LINE_API = "https://api.line.me/v2/bot/message"

# ユーザーの入力状態を一時保存（本番ではRedis/DBに置き換える）
_user_state: dict = {}


def verify_signature(body: bytes, signature: str) -> bool:
    channel_secret = os.environ.get("LINE_CHANNEL_SECRET", "")
    hash_ = hmac.new(channel_secret.encode("utf-8"), body, hashlib.sha256).digest()
    return base64.b64encode(hash_).decode("utf-8") == signature


def reply(reply_token: str, messages: list):
    token = os.environ.get("LINE_ACCESS_TOKEN", "")
    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {token}",
    }
    payload = {"replyToken": reply_token, "messages": messages}
    requests.post(f"{LINE_API}/reply", headers=headers, json=payload, timeout=10)


def push(user_id: str, messages: list):
    token = os.environ.get("LINE_ACCESS_TOKEN", "")
    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {token}",
    }
    payload = {"to": user_id, "messages": messages}
    requests.post(f"{LINE_API}/push", headers=headers, json=payload, timeout=10)


def get_user_state(user_id: str) -> dict:
    return _user_state.get(user_id, {})


def set_user_state(user_id: str, state: dict):
    _user_state[user_id] = state


def clear_user_state(user_id: str):
    _user_state.pop(user_id, None)


def welcome_message() -> list:
    return [
        {
            "type": "text",
            "text": "はじめまして！\n星座と血液型であなたの運勢を占います✨\n\nまず、生まれた月を教えてください。\n例：「3月」「12月」",
        }
    ]


def ask_blood_type_message(zodiac: str) -> list:
    return [
        {
            "type": "text",
            "text": f"{zodiac}さんですね！\n次に血液型を教えてください。",
        },
        {
            "type": "template",
            "altText": "血液型を選んでください",
            "template": {
                "type": "buttons",
                "text": "血液型はどれですか？",
                "actions": [
                    {"type": "message", "label": "A型", "text": "A型"},
                    {"type": "message", "label": "B型", "text": "B型"},
                    {"type": "message", "label": "O型", "text": "O型"},
                    {"type": "message", "label": "AB型", "text": "AB型"},
                ],
            },
        },
    ]


def parse_month(text: str) -> int | None:
    """「3月」「3」「03」などから月を抽出"""
    import re
    m = re.search(r"(\d{1,2})", text)
    if m:
        month = int(m.group(1))
        if 1 <= month <= 12:
            return month
    return None


def parse_blood_type(text: str) -> str | None:
    text = text.upper().replace("型", "").strip()
    if text in ("A", "B", "O", "AB"):
        return text
    return None


def handle_event(event: dict, cta_url: str) -> None:
    from api.fortune import get_zodiac_from_month, generate_fortune, build_flex_message

    event_type = event.get("type")
    reply_token = event.get("replyToken")
    source = event.get("source", {})
    user_id = source.get("userId", "")

    if event_type == "follow":
        set_user_state(user_id, {"step": "ask_month"})
        reply(reply_token, welcome_message())
        return

    if event_type != "message" or event.get("message", {}).get("type") != "text":
        return

    text = event["message"]["text"].strip()
    state = get_user_state(user_id)
    step = state.get("step", "ask_month")

    if step == "ask_month":
        month = parse_month(text)
        if not month:
            reply(reply_token, [{"type": "text", "text": "月を数字で教えてください。\n例：「3月」「12月」"}])
            return
        zodiac = get_zodiac_from_month(month)
        set_user_state(user_id, {"step": "ask_blood", "zodiac": zodiac})
        reply(reply_token, ask_blood_type_message(zodiac))

    elif step == "ask_blood":
        blood_type = parse_blood_type(text)
        if not blood_type:
            reply(reply_token, [{"type": "text", "text": "A型 / B型 / O型 / AB型 のどれかを教えてください。"}])
            return
        zodiac = state.get("zodiac", "牡羊座")
        reply(reply_token, [{"type": "text", "text": "占い中です...少々お待ちください🔮"}])
        clear_user_state(user_id)

        fortune = generate_fortune(zodiac, blood_type)
        flex = build_flex_message(zodiac, blood_type, fortune, cta_url)
        push(user_id, [flex, {
            "type": "text",
            "text": "また占いたいときは「占い」と送ってください✨",
        }])

    else:
        if "占い" in text or "うらない" in text:
            set_user_state(user_id, {"step": "ask_month"})
            reply(reply_token, [{"type": "text", "text": "生まれた月を教えてください。\n例：「3月」「12月」"}])
        else:
            reply(reply_token, [{"type": "text", "text": "「占い」と送ると今日の運勢を占えます🔮"}])

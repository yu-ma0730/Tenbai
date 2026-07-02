import hashlib
import hmac
import base64
import json
import os
import requests

LINE_API = "https://api.line.me/v2/bot/message"

# ユーザーの入力状態を一時保存（本番ではRedis/DBに置き換える）
_user_state: dict = {}

# ユーザーの占いプロフィール（星座・血液型）を永続保存（本番ではRedis/DBに置き換える）
_user_profile: dict = {}


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


def get_user_profile(user_id: str) -> dict | None:
    return _user_profile.get(user_id)


def save_user_profile(user_id: str, profile: dict):
    _user_profile[user_id] = profile


def clear_user_profile(user_id: str):
    _user_profile.pop(user_id, None)


def welcome_message() -> list:
    return [
        {
            "type": "text",
            "text": "はじめまして！\n星座と血液型であなたの運勢を占います✨\n\n生まれた月と日を教えてください。\n例：「7月23日」「12月25日」",
        }
    ]


def welcome_back_message() -> list:
    return [
        {
            "type": "text",
            "text": (
                "おかえりなさい！\n"
                "生年月日と血液型は登録済みなので、「占い」と送るだけで今日の運勢を占えます🔮\n\n"
                "他の人を占いたいときは「他の人を占う」、\n"
                "登録情報を変更したいときは「リセット」と送ってください。"
            ),
        }
    ]


def ask_fortune_prompt_message() -> list:
    return [{"type": "text", "text": "「占い」と送ると今日の運勢を占えます🔮\nメニューから「他の人を占う」「リセット」も選べます。"}]


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


def parse_birthday(text: str):
    """「7月23日」「7/23」「7-23」などから月と日を抽出"""
    import re
    m = re.search(r"(\d{1,2})[月/\.\-](\d{1,2})[日]?", text)
    if m:
        month = int(m.group(1))
        day = int(m.group(2))
        if 1 <= month <= 12 and 1 <= day <= 31:
            return month, day
    return None, None


def parse_blood_type(text: str) -> str | None:
    import re
    text_upper = text.upper()
    if re.search(r'AB', text_upper):
        return "AB"
    for bt in ("A", "B", "O"):
        if re.search(rf'(?<![A-Z]){bt}(?![A-Z])', text_upper):
            return bt
    return None


# リッチメニュー／テキスト入力の両方から拾うキーワード
RESET_KEYWORDS = ("リセット", "設定リセット", "登録情報をリセット", "設定を変更")
OTHER_KEYWORDS = ("他の人を占う", "他の人", "友達を占う")
FORTUNE_KEYWORDS = ("占い", "うらない")


def _send_fortune(user_id: str, zodiac: str, blood_type: str, cta_url: str) -> None:
    from api.fortune import generate_fortune, build_flex_message

    fortune = generate_fortune(zodiac, blood_type)
    flex = build_flex_message(zodiac, blood_type, fortune, cta_url)
    push(user_id, [flex, {
        "type": "text",
        "text": "また占いたいときは「占い」と送ってください✨",
    }])


def handle_event(event: dict, cta_url: str) -> None:
    from api.fortune import get_zodiac

    event_type = event.get("type")
    reply_token = event.get("replyToken")
    source = event.get("source", {})
    user_id = source.get("userId", "")

    if event_type == "follow":
        clear_user_state(user_id)
        profile = get_user_profile(user_id)
        if profile:
            reply(reply_token, welcome_back_message())
        else:
            set_user_state(user_id, {"step": "ask_month", "target": "self"})
            reply(reply_token, welcome_message())
        return

    if event_type != "message" or event.get("message", {}).get("type") != "text":
        return

    text = event["message"]["text"].strip()
    state = get_user_state(user_id)
    step = state.get("step")
    target = state.get("target", "self")

    if step == "ask_month":
        month, day = parse_birthday(text)
        if not month or not day:
            prompt = "占いたい人の" if target == "other" else ""
            reply(reply_token, [{"type": "text", "text": f"{prompt}生まれた月と日を教えてください。\n例：「7月23日」「12月25日」"}])
            return
        zodiac = get_zodiac(month, day)
        set_user_state(user_id, {"step": "ask_blood", "target": target, "zodiac": zodiac})
        reply(reply_token, ask_blood_type_message(zodiac))
        return

    if step == "ask_blood":
        blood_type = parse_blood_type(text)
        if not blood_type:
            reply(reply_token, [{"type": "text", "text": "A型 / B型 / O型 / AB型 のどれかを教えてください。"}])
            return
        zodiac = state.get("zodiac", "牡羊座")
        clear_user_state(user_id)

        if target == "other":
            reply(reply_token, [{"type": "text", "text": "占い中です...少々お待ちください🔮\n（この結果は保存されません）"}])
        else:
            save_user_profile(user_id, {"zodiac": zodiac, "blood_type": blood_type})
            reply(reply_token, [{"type": "text", "text": "占い中です...少々お待ちください🔮\n（生年月日と血液型は次回から省略できます）"}])

        _send_fortune(user_id, zodiac, blood_type, cta_url)
        return

    # 会話の途中でない場合はキーワードで判定（リッチメニューのボタンもここに入る）
    if any(k in text for k in RESET_KEYWORDS):
        had_profile = get_user_profile(user_id) is not None
        clear_user_profile(user_id)
        prefix = "登録情報をリセットしました。\n" if had_profile else ""
        set_user_state(user_id, {"step": "ask_month", "target": "self"})
        reply(reply_token, [{"type": "text", "text": f"{prefix}生まれた月と日を教えてください。\n例：「7月23日」「12月25日」"}])
        return

    if any(k in text for k in OTHER_KEYWORDS):
        set_user_state(user_id, {"step": "ask_month", "target": "other"})
        reply(reply_token, [{"type": "text", "text": "占いたい人の生まれた月と日を教えてください。\n（この結果は保存されません）\n例：「7月23日」「12月25日」"}])
        return

    if any(k in text for k in FORTUNE_KEYWORDS):
        profile = get_user_profile(user_id)
        if profile:
            reply(reply_token, [{"type": "text", "text": "占い中です...少々お待ちください🔮"}])
            _send_fortune(user_id, profile["zodiac"], profile["blood_type"], cta_url)
        else:
            set_user_state(user_id, {"step": "ask_month", "target": "self"})
            reply(reply_token, [{"type": "text", "text": "生まれた月と日を教えてください。\n例：「7月23日」「12月25日」"}])
        return

    reply(reply_token, ask_fortune_prompt_message())

import anthropic
from datetime import date

ZODIAC_SIGNS = [
    (1, 20, "山羊座"), (2, 19, "水瓶座"), (3, 20, "魚座"),
    (4, 20, "牡羊座"), (5, 21, "牡牛座"), (6, 21, "双子座"),
    (7, 23, "蟹座"),  (8, 23, "獅子座"), (9, 23, "乙女座"),
    (10, 23, "天秤座"), (11, 22, "蠍座"), (12, 22, "射手座"),
]

ZODIAC_EN = {
    "山羊座": "Capricorn", "水瓶座": "Aquarius", "魚座": "Pisces",
    "牡羊座": "Aries", "牡牛座": "Taurus", "双子座": "Gemini",
    "蟹座": "Cancer", "獅子座": "Leo", "乙女座": "Virgo",
    "天秤座": "Libra", "蠍座": "Scorpio", "射手座": "Sagittarius",
}

BLOOD_TYPE_TRAITS = {
    "A": "几帳面で責任感が強い",
    "B": "自由奔放でクリエイティブ",
    "O": "大らかでリーダーシップがある",
    "AB": "合理的で二面性を持つ",
}


def get_zodiac(month: int, day: int) -> str:
    for cutoff_month, cutoff_day, sign in ZODIAC_SIGNS:
        if month == cutoff_month and day <= cutoff_day:
            return sign
        if month == cutoff_month - 1 or (cutoff_month == 1 and month == 12):
            return sign
    return "山羊座"


def get_zodiac_from_month(month: int) -> str:
    """月のみで星座を判定（日付不明の場合は月中旬基準）"""
    month_to_sign = {
        1: "山羊座", 2: "水瓶座", 3: "魚座", 4: "牡羊座",
        5: "牡牛座", 6: "双子座", 7: "蟹座", 8: "獅子座",
        9: "乙女座", 10: "天秤座", 11: "蠍座", 12: "射手座",
    }
    return month_to_sign.get(month, "山羊座")


def generate_fortune(zodiac: str, blood_type: str) -> dict:
    """Claude APIで星座・血液型に基づいた運勢を生成する"""
    client = anthropic.Anthropic()
    today = date.today()
    today_str = today.strftime("%Y年%m月%d日")
    trait = BLOOD_TYPE_TRAITS.get(blood_type, "")

    prompt = f"""あなたは占い師です。以下の条件で今日の運勢を作成してください。

条件:
- 星座: {zodiac}
- 血液型: {blood_type}型（{trait}）
- 日付: {today_str}

出力形式（JSON）:
{{
  "overall": "総合運の一言コメント（20文字以内）",
  "overall_score": 総合運スコア（1-5の整数）,
  "love_score": 恋愛運スコア（1-5の整数）,
  "work_score": 仕事運スコア（1-5の整数）,
  "money_score": 金運スコア（1-5の整数）,
  "message": "今日の運勢メッセージ（100文字程度、{zodiac}と{blood_type}型の特性を活かした具体的なアドバイス）",
  "lucky_color": "ラッキーカラー（1色）",
  "lucky_item": "ラッキーアイテム（1つ）",
  "advice": "今日の行動アドバイス（50文字程度、前向きで具体的に）"
}}

JSONのみを返してください。"""

    message = client.messages.create(
        model="claude-haiku-4-5-20251001",
        max_tokens=512,
        messages=[{"role": "user", "content": prompt}],
    )

    import json
    text = message.content[0].text.strip()
    if text.startswith("```"):
        text = text.split("```")[1]
        if text.startswith("json"):
            text = text[4:]
    return json.loads(text.strip())


def score_to_stars(score: int) -> str:
    return "★" * score + "☆" * (5 - score)


def build_flex_message(zodiac: str, blood_type: str, fortune: dict, cta_url: str) -> dict:
    """LINE Flex Message を構築する"""
    today = date.today().strftime("%Y年%m月%d日")
    stars_overall = score_to_stars(fortune["overall_score"])
    stars_love = score_to_stars(fortune["love_score"])
    stars_work = score_to_stars(fortune["work_score"])
    stars_money = score_to_stars(fortune["money_score"])

    return {
        "type": "flex",
        "altText": f"【{zodiac} × {blood_type}型】今日の運勢",
        "contents": {
            "type": "bubble",
            "size": "mega",
            "header": {
                "type": "box",
                "layout": "vertical",
                "backgroundColor": "#1a1a2e",
                "paddingAll": "20px",
                "contents": [
                    {
                        "type": "text",
                        "text": "今日の運勢",
                        "color": "#8892b0",
                        "size": "sm",
                    },
                    {
                        "type": "text",
                        "text": f"{zodiac} × {blood_type}型",
                        "color": "#e94560",
                        "size": "xl",
                        "weight": "bold",
                        "margin": "sm",
                    },
                    {
                        "type": "text",
                        "text": today,
                        "color": "#8892b0",
                        "size": "xs",
                        "margin": "sm",
                    },
                ],
            },
            "body": {
                "type": "box",
                "layout": "vertical",
                "spacing": "md",
                "paddingAll": "20px",
                "contents": [
                    {
                        "type": "text",
                        "text": f"「{fortune['overall']}」",
                        "wrap": True,
                        "weight": "bold",
                        "size": "lg",
                        "color": "#1a1a2e",
                        "align": "center",
                    },
                    {
                        "type": "separator",
                        "margin": "md",
                    },
                    {
                        "type": "box",
                        "layout": "vertical",
                        "spacing": "sm",
                        "margin": "md",
                        "contents": [
                            _score_row("総合運", stars_overall),
                            _score_row("恋愛運", stars_love),
                            _score_row("仕事運", stars_work),
                            _score_row("金運　", stars_money),
                        ],
                    },
                    {
                        "type": "separator",
                        "margin": "md",
                    },
                    {
                        "type": "text",
                        "text": fortune["message"],
                        "wrap": True,
                        "size": "sm",
                        "color": "#444",
                        "margin": "md",
                    },
                    {
                        "type": "box",
                        "layout": "horizontal",
                        "spacing": "sm",
                        "margin": "md",
                        "contents": [
                            _label_value("ラッキーカラー", fortune["lucky_color"]),
                            _label_value("ラッキーアイテム", fortune["lucky_item"]),
                        ],
                    },
                    {
                        "type": "box",
                        "layout": "vertical",
                        "backgroundColor": "#f0f4ff",
                        "cornerRadius": "8px",
                        "paddingAll": "12px",
                        "margin": "md",
                        "contents": [
                            {
                                "type": "text",
                                "text": "今日のアドバイス",
                                "size": "xs",
                                "color": "#0f3460",
                                "weight": "bold",
                            },
                            {
                                "type": "text",
                                "text": fortune["advice"],
                                "wrap": True,
                                "size": "sm",
                                "color": "#333",
                                "margin": "sm",
                            },
                        ],
                    },
                ],
            },
            "footer": {
                "type": "box",
                "layout": "vertical",
                "spacing": "sm",
                "paddingAll": "16px",
                "contents": [
                    {
                        "type": "text",
                        "text": "あなたの運気をさらに上げる方法があります",
                        "wrap": True,
                        "size": "xs",
                        "color": "#888",
                        "align": "center",
                    },
                    {
                        "type": "button",
                        "style": "primary",
                        "color": "#e94560",
                        "margin": "sm",
                        "action": {
                            "type": "uri",
                            "label": "詳しく見る",
                            "uri": cta_url,
                        },
                    },
                ],
            },
        },
    }


def _score_row(label: str, stars: str) -> dict:
    return {
        "type": "box",
        "layout": "horizontal",
        "contents": [
            {"type": "text", "text": label, "size": "sm", "color": "#666", "flex": 2},
            {"type": "text", "text": stars, "size": "sm", "color": "#e94560", "flex": 3},
        ],
    }


def _label_value(label: str, value: str) -> dict:
    return {
        "type": "box",
        "layout": "vertical",
        "flex": 1,
        "backgroundColor": "#fafafa",
        "cornerRadius": "6px",
        "paddingAll": "8px",
        "contents": [
            {"type": "text", "text": label, "size": "xxs", "color": "#888"},
            {"type": "text", "text": value, "size": "sm", "color": "#1a1a2e", "weight": "bold", "margin": "xs"},
        ],
    }

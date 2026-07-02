"""リッチメニュー用の画像を生成する（開発時に一度だけ実行）。

使い方:
    pip install pillow
    python scripts/generate_rich_menu_image.py

static/richmenu/rich_menu.png に 2500x843px の画像を書き出す。
"""
import os
from PIL import Image, ImageDraw, ImageFont

WIDTH, HEIGHT = 2500, 843
COLUMNS = [
    {"label": "今日の運勢", "sub": "占い", "bg": (26, 26, 46), "fg": (255, 255, 255)},
    {"label": "他の人を占う", "sub": "保存されません", "bg": (233, 69, 96, 255)[:3], "fg": (255, 255, 255)},
    {"label": "登録情報を", "sub": "リセット", "bg": (15, 52, 96), "fg": (255, 255, 255)},
]

FONT_CANDIDATES = [
    "/usr/share/fonts/opentype/ipafont-gothic/ipag.ttf",
    "/usr/share/fonts/truetype/fonts-japanese-gothic.ttf",
]


def _load_font(size: int) -> ImageFont.FreeTypeFont:
    for path in FONT_CANDIDATES:
        if os.path.exists(path):
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def generate() -> str:
    img = Image.new("RGB", (WIDTH, HEIGHT), (255, 255, 255))
    draw = ImageDraw.Draw(img)
    col_width = WIDTH // len(COLUMNS)
    label_font = _load_font(90)
    sub_font = _load_font(50)

    for i, col in enumerate(COLUMNS):
        x0 = i * col_width
        x1 = WIDTH if i == len(COLUMNS) - 1 else (i + 1) * col_width
        draw.rectangle([x0, 0, x1, HEIGHT], fill=col["bg"])

        cx = (x0 + x1) // 2
        label_bbox = draw.textbbox((0, 0), col["label"], font=label_font)
        sub_bbox = draw.textbbox((0, 0), col["sub"], font=sub_font)
        label_w = label_bbox[2] - label_bbox[0]
        sub_w = sub_bbox[2] - sub_bbox[0]

        draw.text((cx - label_w / 2, HEIGHT / 2 - 90), col["label"], font=label_font, fill=col["fg"])
        draw.text((cx - sub_w / 2, HEIGHT / 2 + 30), col["sub"], font=sub_font, fill=col["fg"])

        if i > 0:
            draw.line([x0, 0, x0, HEIGHT], fill=(255, 255, 255), width=4)

    out_dir = os.path.join(os.path.dirname(os.path.dirname(__file__)), "static", "richmenu")
    os.makedirs(out_dir, exist_ok=True)
    out_path = os.path.join(out_dir, "rich_menu.png")
    img.save(out_path)
    return out_path


if __name__ == "__main__":
    path = generate()
    print(f"生成しました: {path}")

from flask import Flask, render_template, request, jsonify
import json
import os
import re
import random
import math
import urllib.parse
from datetime import datetime

app = Flask(__name__)

# 登録済み商品データ（本番ではDBに保存）
registered_products = []


def search_amazon_product(url):
    """Amazonの商品URLから商品情報を抽出（モック）"""
    asin_match = re.search(r'/dp/([A-Z0-9]{10})', url)
    asin = asin_match.group(1) if asin_match else "UNKNOWN"
    return {
        "asin": asin,
        "url": url,
        "source": "Amazon",
    }


def get_trend_data(sources):
    """各トレンドソースからトレンド商品を取得（モックデータ）"""
    mock_trends = {
        "X": [
            {"rank": 1, "keyword": "ワイヤレスイヤホン", "volume": 12500, "change": "+15%", "category": "家電"},
            {"rank": 2, "keyword": "美顔器", "volume": 9800, "change": "+32%", "category": "美容"},
            {"rank": 3, "keyword": "折りたたみスマホスタンド", "volume": 7600, "change": "+8%", "category": "スマホアクセサリ"},
            {"rank": 4, "keyword": "プロテインシェイカー", "volume": 6200, "change": "+21%", "category": "スポーツ"},
            {"rank": 5, "keyword": "LEDデスクライト", "volume": 5400, "change": "+11%", "category": "インテリア"},
        ],
        "Google": [
            {"rank": 1, "keyword": "空気清浄機", "volume": 45000, "change": "+28%", "category": "家電"},
            {"rank": 2, "keyword": "電動歯ブラシ", "volume": 38000, "change": "+19%", "category": "日用品"},
            {"rank": 3, "keyword": "スマートウォッチ", "volume": 32000, "change": "+41%", "category": "家電"},
            {"rank": 4, "keyword": "コードレス掃除機", "volume": 29000, "change": "+14%", "category": "家電"},
            {"rank": 5, "keyword": "水筒 保温", "volume": 24000, "change": "+7%", "category": "キッチン"},
        ],
        "TikTok": [
            {"rank": 1, "keyword": "ネイルアート用品", "volume": 88000, "change": "+67%", "category": "美容"},
            {"rank": 2, "keyword": "ミニ加湿器", "volume": 72000, "change": "+53%", "category": "家電"},
            {"rank": 3, "keyword": "猫用おもちゃ", "volume": 65000, "change": "+38%", "category": "ペット"},
            {"rank": 4, "keyword": "マグネット収納ラック", "volume": 58000, "change": "+45%", "category": "インテリア"},
            {"rank": 5, "keyword": "グロウアイシャドウ", "volume": 49000, "change": "+72%", "category": "美容"},
        ],
    }
    result = {}
    for source in sources:
        if source in mock_trends:
            result[source] = mock_trends[source]
    return result


def get_suppliers(keyword, category):
    """仕入れ先情報を取得（モックデータ）"""
    suppliers = [
        {
            "name": "アリババ",
            "type": "中国卸",
            "price": 380,
            "moq": 50,
            "lead_time": "2〜3週間",
            "url": f"https://www.alibaba.com/trade/search?SearchText={urllib.parse.quote(keyword)}",
            "rating": 4.2,
        },
        {
            "name": "NETSEA（ネッシー）",
            "type": "国内卸",
            "price": 1200,
            "moq": 10,
            "lead_time": "3〜5日",
            "url": f"https://www.netsea.jp/search?keyword={urllib.parse.quote(keyword)}",
            "rating": 4.5,
        },
        {
            "name": "スーパーデリバリー",
            "type": "国内卸",
            "price": 1450,
            "moq": 5,
            "lead_time": "2〜4日",
            "url": f"https://www.superdelivery.com/p/r/ppg_d/1/?free={urllib.parse.quote(keyword)}",
            "rating": 4.7,
        },
        {
            "name": "1688.com",
            "type": "中国卸",
            "price": 290,
            "moq": 100,
            "lead_time": "3〜4週間",
            "url": f"https://s.1688.com/selloffer/offerlist.htm?keywords={urllib.parse.quote(keyword)}",
            "rating": 3.9,
        },
    ]
    return suppliers


def get_price_comparison(keyword):
    """Amazon vs 弊社の価格比較データ（モックデータ）"""
    amazon_price = 2980
    our_price = 3480
    cost_price = 890
    amazon_fee_rate = 0.15
    our_fee_rate = 0.05

    amazon_profit = amazon_price * (1 - amazon_fee_rate) - cost_price
    our_profit = our_price * (1 - our_fee_rate) - cost_price
    amazon_margin = (amazon_profit / amazon_price) * 100
    our_margin = (our_profit / our_price) * 100

    return {
        "keyword": keyword,
        "amazon": {
            "price": amazon_price,
            "fee_rate": amazon_fee_rate * 100,
            "profit": int(amazon_profit),
            "margin": round(amazon_margin, 1),
            "review_count": 1243,
            "rating": 4.1,
        },
        "ours": {
            "price": our_price,
            "fee_rate": our_fee_rate * 100,
            "profit": int(our_profit),
            "margin": round(our_margin, 1),
        },
        "cost_price": cost_price,
        "recommendation": "弊社販売有利" if our_profit > amazon_profit else "Amazon出品有利",
    }


@app.route("/")
def index():
    return render_template("index.html")


@app.route("/api/trends", methods=["POST"])
def get_trends():
    data = request.get_json()
    sources = data.get("sources", ["X", "Google", "TikTok"])
    trends = get_trend_data(sources)
    return jsonify({"success": True, "trends": trends, "updated_at": datetime.now().strftime("%Y/%m/%d %H:%M")})


@app.route("/api/register", methods=["POST"])
def register_product():
    data = request.get_json()
    url = data.get("url", "")
    keyword = data.get("keyword", "")

    if not url and not keyword:
        return jsonify({"success": False, "error": "URLまたはキーワードを入力してください"})

    product_info = search_amazon_product(url) if url else {}
    suppliers = get_suppliers(keyword or "商品", "家電")
    price_comparison = get_price_comparison(keyword or "商品")

    product = {
        "id": len(registered_products) + 1,
        "keyword": keyword,
        "url": url,
        "registered_at": datetime.now().strftime("%Y/%m/%d %H:%M"),
        "amazon_info": product_info,
        "suppliers": suppliers,
        "price_comparison": price_comparison,
    }
    registered_products.append(product)

    return jsonify({"success": True, "product": product})


@app.route("/api/products", methods=["GET"])
def get_products():
    return jsonify({"success": True, "products": registered_products})


@app.route("/api/analyze", methods=["POST"])
def analyze_product():
    data = request.get_json()
    keyword = data.get("keyword", "")
    suppliers = get_suppliers(keyword, "")
    price_comparison = get_price_comparison(keyword)
    return jsonify({
        "success": True,
        "keyword": keyword,
        "suppliers": suppliers,
        "price_comparison": price_comparison,
    })


@app.route("/fx")
def fx_signals():
    return render_template("fx.html")


# FX基準価格（サーバー側で管理してリアルなドリフトを再現）
_fx_prices = {
    "USDJPY": 157.50,
    "EURUSD": 1.0820,
    "EURJPY": 170.40,
    "XAUUSD": 3285.0,
}

_PIP = {"USDJPY": 0.01, "EURUSD": 0.0001, "EURJPY": 0.01, "XAUUSD": 0.1}
_DEC = {"USDJPY": 3, "EURUSD": 5, "EURJPY": 3, "XAUUSD": 2}
_SL_PIPS = {"USDJPY": 8, "EURUSD": 8, "EURJPY": 10, "XAUUSD": 20}


def _generate_candles(pair, bars=60):
    price = _fx_prices[pair]
    pip = _PIP[pair]
    vol = pip * 5
    candles = []
    for _ in range(bars):
        open_ = price
        move = (random.random() - 0.49) * vol * 8
        close = open_ + move
        high = max(open_, close) + random.random() * vol * 2
        low  = min(open_, close) - random.random() * vol * 2
        candles.append({"open": open_, "high": high, "low": low, "close": close})
        price = close
    _fx_prices[pair] = price
    return candles


def _ema(closes, period):
    k = 2 / (period + 1)
    val = closes[0]
    for c in closes[1:]:
        val = c * k + val * (1 - k)
    return val


def _rsi(closes, period=14):
    if len(closes) < period + 1:
        return 50.0
    gains, losses = 0.0, 0.0
    for i in range(1, period + 1):
        diff = closes[i] - closes[i - 1]
        if diff > 0:
            gains += diff
        else:
            losses -= diff
    avg_gain = gains / period
    avg_loss = losses / period
    for i in range(period + 1, len(closes)):
        diff = closes[i] - closes[i - 1]
        g = diff if diff > 0 else 0
        l = -diff if diff < 0 else 0
        avg_gain = (avg_gain * (period - 1) + g) / period
        avg_loss = (avg_loss * (period - 1) + l) / period
    if avg_loss == 0:
        return 100.0
    rs = avg_gain / avg_loss
    return round(100 - (100 / (1 + rs)), 1)


def _calc_signal(pair):
    candles = _generate_candles(pair, 60)
    closes = [c["close"] for c in candles]
    prev_closes = closes[:-1]

    ema9  = _ema(closes, 9)
    ema21 = _ema(closes, 21)
    ema9p = _ema(prev_closes, 9)
    ema21p = _ema(prev_closes, 21)
    rsi_val = _rsi(closes, 14)

    pip = _PIP[pair]
    sl_dist = _SL_PIPS[pair] * pip
    tp1_dist = sl_dist * 1.5
    tp2_dist = sl_dist * 2.0

    entry = closes[-1]
    bull_cross = ema9p <= ema21p and ema9 > ema21
    bear_cross = ema9p >= ema21p and ema9 < ema21
    rand = random.random()

    signal = "NEUTRAL"
    if (bull_cross and 40 < rsi_val < 65) or (ema9 > ema21 and 45 < rsi_val < 60 and rand < 0.35):
        signal = "BUY"
    elif (bear_cross and 35 < rsi_val < 60) or (ema9 < ema21 and 40 < rsi_val < 55 and rand < 0.35):
        signal = "SELL"

    pct_change = (closes[-1] - closes[-6]) / closes[-6] * 100

    return {
        "pair": pair,
        "signal": signal,
        "entry": round(entry, _DEC[pair]),
        "sl": round(entry - sl_dist if signal == "BUY" else entry + sl_dist, _DEC[pair]),
        "tp1": round(entry + tp1_dist if signal == "BUY" else entry - tp1_dist, _DEC[pair]),
        "tp2": round(entry + tp2_dist if signal == "BUY" else entry - tp2_dist, _DEC[pair]),
        "ema9": round(ema9, _DEC[pair]),
        "ema21": round(ema21, _DEC[pair]),
        "rsi": rsi_val,
        "pctChange": round(pct_change, 4),
    }


@app.route("/api/fx/signals", methods=["POST"])
def fx_signals_api():
    data = request.get_json()
    pairs = data.get("pairs", ["USDJPY", "EURUSD", "EURJPY", "XAUUSD"])
    tf = data.get("tf", 5)
    signals = [_calc_signal(p) for p in pairs if p in _fx_prices]
    return jsonify({
        "success": True,
        "signals": signals,
        "tf": tf,
        "updated_at": datetime.now().strftime("%Y/%m/%d %H:%M:%S"),
    })


if __name__ == "__main__":
    app.run(debug=True, port=5000)

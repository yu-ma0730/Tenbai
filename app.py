from flask import Flask, render_template, request, jsonify
import json
import os
import re
import urllib.parse
from datetime import datetime
from fx_signal import analyze_pair, PAIRS, mt5_data_store

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
def fx_signal_page():
    return render_template("fx_signal.html")


@app.route("/api/fx/scan", methods=["GET"])
def fx_scan():
    pair = request.args.get("pair", "USDJPY")
    if pair not in PAIRS:
        return jsonify({"success": False, "error": "Invalid pair"}), 400
    data = analyze_pair(pair)
    return jsonify({"success": True, **data})


@app.route("/api/mt5/push", methods=["POST"])
def mt5_push():
    """MT5ブリッジからOHLCデータを受信してストアに保存"""
    data = request.get_json()
    if not data:
        return jsonify({"success": False, "error": "No data"}), 400

    pair = data.get("pair")
    if pair not in PAIRS:
        return jsonify({"success": False, "error": f"Unknown pair: {pair}"}), 400

    mt5_data_store[pair] = {
        "candles_15m": data.get("candles_15m", []),
        "candles_1h":  data.get("candles_1h",  []),
        "pushed_at":   data.get("pushed_at", datetime.now().strftime("%Y/%m/%d %H:%M:%S")),
    }
    return jsonify({"success": True, "pair": pair, "candles_15m": len(mt5_data_store[pair]["candles_15m"])})


@app.route("/api/mt5/status", methods=["GET"])
def mt5_status():
    """MT5ブリッジの接続状態を返す"""
    status = {}
    for pair in PAIRS:
        d = mt5_data_store.get(pair)
        status[pair] = {
            "connected": d is not None,
            "candles_15m": len(d["candles_15m"]) if d else 0,
            "candles_1h":  len(d["candles_1h"])  if d else 0,
            "last_push":   d["pushed_at"] if d else None,
        }
    return jsonify({"success": True, "status": status})


@app.route("/api/fx/scan_all", methods=["GET"])
def fx_scan_all():
    results = {}
    for pair in PAIRS:
        data = analyze_pair(pair)
        # サマリーのみ返す
        results[pair] = {
            "pair_name": data["pair_name"],
            "trend": data["trend"],
            "trend_strength": data["trend_strength"],
            "top_signal": data["signals"][0] if data["signals"] else None,
            "updated_at": data["updated_at"],
        }
    return jsonify({"success": True, "pairs": results})


if __name__ == "__main__":
    app.run(debug=True, port=5000)

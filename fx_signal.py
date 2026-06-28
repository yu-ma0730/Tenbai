"""FX Candlestick Signal Engine - パターン検出 + サイン生成"""
import random
import math
from datetime import datetime, timedelta


PAIRS = {
    "USDJPY": {"name": "ドル円", "pip": 0.01, "digits": 3},
    "EURUSD": {"name": "ユーロドル", "pip": 0.0001, "digits": 5},
    "EURJPY": {"name": "ユーロ円", "pip": 0.01, "digits": 3},
    "XAUUSD": {"name": "ゴールド", "pip": 0.01, "digits": 2},
}

BASE_PRICES = {
    "USDJPY": 149.50,
    "EURUSD": 1.0850,
    "EURJPY": 162.20,
    "XAUUSD": 2340.00,
}

VOLATILITY = {
    "USDJPY": 0.0008,
    "EURUSD": 0.0006,
    "EURJPY": 0.0010,
    "XAUUSD": 0.0015,
}


def generate_ohlc(base, vol, prev_close=None):
    """1本のOHLCローソク足を生成"""
    if prev_close:
        base = prev_close
    gap = base * vol * random.gauss(0, 1)
    open_ = base + gap * 0.1
    body = base * vol * random.gauss(0, 1.5)
    close = open_ + body
    upper = max(open_, close) + abs(base * vol * random.gauss(0, 0.5))
    lower = min(open_, close) - abs(base * vol * random.gauss(0, 0.5))
    return {
        "open": round(open_, 5),
        "high": round(upper, 5),
        "low": round(lower, 5),
        "close": round(close, 5),
    }


def generate_candles(pair, tf_minutes, count):
    """指定したタイムフレームのローソク足データを生成"""
    base = BASE_PRICES[pair]
    vol = VOLATILITY[pair]
    now = datetime.now()
    # 現在時刻を足の開始に丸める
    minutes_offset = now.minute % tf_minutes
    candle_time = now - timedelta(minutes=minutes_offset, seconds=now.second)

    candles = []
    price = base
    # トレンドを付ける（上昇・下降・レンジ）
    trend = random.choice([-1, 0, 0, 1])
    trend_strength = vol * 0.3

    for i in range(count - 1, -1, -1):
        t = candle_time - timedelta(minutes=tf_minutes * i)
        # トレンドバイアスを加味
        price += trend * trend_strength * base
        c = generate_ohlc(price, vol)
        c["time"] = t.strftime("%Y-%m-%d %H:%M")
        c["timestamp"] = int(t.timestamp())
        candles.append(c)
        price = c["close"]

    return candles


def body_size(c):
    return abs(c["close"] - c["open"])


def upper_shadow(c):
    return c["high"] - max(c["open"], c["close"])


def lower_shadow(c):
    return min(c["open"], c["close"]) - c["low"]


def candle_range(c):
    return c["high"] - c["low"]


def is_bullish(c):
    return c["close"] > c["open"]


def is_bearish(c):
    return c["close"] < c["open"]


# ---------- パターン検出関数 ----------

def detect_doji(c):
    r = candle_range(c)
    if r == 0:
        return False
    return body_size(c) / r < 0.1


def detect_hammer(c):
    """ハンマー（下ひげ長い、実体小さい、上ひげほぼなし）"""
    r = candle_range(c)
    if r == 0:
        return False
    ls = lower_shadow(c)
    us = upper_shadow(c)
    bs = body_size(c)
    return ls >= 2 * bs and us <= bs * 0.5 and bs / r > 0.05


def detect_hanging_man(c):
    """首吊り線 = ハンマーと同形、上昇後に出現"""
    return detect_hammer(c)


def detect_shooting_star(c):
    """シューティングスター（上ひげ長い、実体小さい、下ひげほぼなし）"""
    r = candle_range(c)
    if r == 0:
        return False
    ls = lower_shadow(c)
    us = upper_shadow(c)
    bs = body_size(c)
    return us >= 2 * bs and ls <= bs * 0.5 and bs / r > 0.05


def detect_inverted_hammer(c):
    """逆ハンマー = シューティングスターと同形"""
    return detect_shooting_star(c)


def detect_bullish_engulfing(prev, curr):
    """陽線包み足"""
    return (
        is_bearish(prev)
        and is_bullish(curr)
        and curr["open"] <= prev["close"]
        and curr["close"] >= prev["open"]
    )


def detect_bearish_engulfing(prev, curr):
    """陰線包み足"""
    return (
        is_bullish(prev)
        and is_bearish(curr)
        and curr["open"] >= prev["close"]
        and curr["close"] <= prev["open"]
    )


def detect_morning_star(c0, c1, c2):
    """明けの明星（3本）"""
    return (
        is_bearish(c0)
        and body_size(c0) > candle_range(c0) * 0.4
        and body_size(c1) < candle_range(c1) * 0.3
        and is_bullish(c2)
        and body_size(c2) > candle_range(c2) * 0.4
        and c2["close"] > (c0["open"] + c0["close"]) / 2
    )


def detect_evening_star(c0, c1, c2):
    """宵の明星（3本）"""
    return (
        is_bullish(c0)
        and body_size(c0) > candle_range(c0) * 0.4
        and body_size(c1) < candle_range(c1) * 0.3
        and is_bearish(c2)
        and body_size(c2) > candle_range(c2) * 0.4
        and c2["close"] < (c0["open"] + c0["close"]) / 2
    )


def detect_three_white_soldiers(c0, c1, c2):
    """三兵（赤三兵）"""
    return (
        is_bullish(c0) and is_bullish(c1) and is_bullish(c2)
        and c1["open"] > c0["open"] and c1["close"] > c0["close"]
        and c2["open"] > c1["open"] and c2["close"] > c1["close"]
        and body_size(c0) > candle_range(c0) * 0.5
        and body_size(c1) > candle_range(c1) * 0.5
        and body_size(c2) > candle_range(c2) * 0.5
    )


def detect_three_black_crows(c0, c1, c2):
    """三羽烏"""
    return (
        is_bearish(c0) and is_bearish(c1) and is_bearish(c2)
        and c1["open"] < c0["open"] and c1["close"] < c0["close"]
        and c2["open"] < c1["open"] and c2["close"] < c1["close"]
        and body_size(c0) > candle_range(c0) * 0.5
        and body_size(c1) > candle_range(c1) * 0.5
        and body_size(c2) > candle_range(c2) * 0.5
    )


def detect_piercing_line(prev, curr):
    """切り込み線"""
    mid = (prev["open"] + prev["close"]) / 2
    return (
        is_bearish(prev)
        and is_bullish(curr)
        and curr["open"] < prev["low"]
        and curr["close"] > mid
        and curr["close"] < prev["open"]
    )


def detect_dark_cloud_cover(prev, curr):
    """かぶせ線"""
    mid = (prev["open"] + prev["close"]) / 2
    return (
        is_bullish(prev)
        and is_bearish(curr)
        and curr["open"] > prev["high"]
        and curr["close"] < mid
        and curr["close"] > prev["open"]
    )


# ---------- EMA計算 ----------

def ema(closes, period):
    k = 2 / (period + 1)
    result = [closes[0]]
    for p in closes[1:]:
        result.append(p * k + result[-1] * (1 - k))
    return result


def get_trend(candles_1h):
    """1時間足でトレンド方向を判定"""
    closes = [c["close"] for c in candles_1h]
    if len(closes) < 50:
        return "RANGE", 0

    ema20 = ema(closes, 20)
    ema50 = ema(closes, 50)

    e20 = ema20[-1]
    e50 = ema50[-1]
    last_close = closes[-1]

    if e20 > e50 and last_close > e20:
        slope = (ema20[-1] - ema20[-5]) / ema20[-5]
        strength = min(100, int(abs(slope) * 100000))
        return "UP", strength
    elif e20 < e50 and last_close < e20:
        slope = (ema20[-1] - ema20[-5]) / ema20[-5]
        strength = min(100, int(abs(slope) * 100000))
        return "DOWN", strength
    else:
        return "RANGE", 0


# ---------- メインシグナル生成 ----------

def scan_patterns(candles_15m, trend):
    """15分足のローソク足パターンをスキャンしてシグナルを返す"""
    signals = []
    n = len(candles_15m)

    for i in range(2, n):
        c0 = candles_15m[i - 2]
        c1 = candles_15m[i - 1]
        c2 = candles_15m[i]
        detected = []

        # 単体パターン（最新足）
        if detect_doji(c2):
            detected.append({"pattern": "ドージ", "direction": "NEUTRAL", "strength": 40})

        if detect_hammer(c2) and is_bullish(c2):
            detected.append({"pattern": "ハンマー", "direction": "BUY", "strength": 65})

        if detect_hanging_man(c2) and is_bearish(c2):
            detected.append({"pattern": "首吊り線", "direction": "SELL", "strength": 60})

        if detect_shooting_star(c2) and is_bearish(c2):
            detected.append({"pattern": "シューティングスター", "direction": "SELL", "strength": 70})

        if detect_inverted_hammer(c2) and is_bullish(c2):
            detected.append({"pattern": "逆ハンマー", "direction": "BUY", "strength": 55})

        # 2本パターン
        if detect_bullish_engulfing(c1, c2):
            detected.append({"pattern": "陽線包み足", "direction": "BUY", "strength": 75})

        if detect_bearish_engulfing(c1, c2):
            detected.append({"pattern": "陰線包み足", "direction": "SELL", "strength": 75})

        if detect_piercing_line(c1, c2):
            detected.append({"pattern": "切り込み線", "direction": "BUY", "strength": 65})

        if detect_dark_cloud_cover(c1, c2):
            detected.append({"pattern": "かぶせ線", "direction": "SELL", "strength": 65})

        # 3本パターン
        if detect_morning_star(c0, c1, c2):
            detected.append({"pattern": "明けの明星", "direction": "BUY", "strength": 85})

        if detect_evening_star(c0, c1, c2):
            detected.append({"pattern": "宵の明星", "direction": "SELL", "strength": 85})

        if detect_three_white_soldiers(c0, c1, c2):
            detected.append({"pattern": "赤三兵", "direction": "BUY", "strength": 80})

        if detect_three_black_crows(c0, c1, c2):
            detected.append({"pattern": "三羽烏", "direction": "SELL", "strength": 80})

        for d in detected:
            # トレンドフィルター
            direction = d["direction"]
            strength = d["strength"]

            if direction == "BUY" and trend == "UP":
                strength = min(95, strength + 15)
                trend_match = True
            elif direction == "SELL" and trend == "DOWN":
                strength = min(95, strength + 15)
                trend_match = True
            elif direction == "NEUTRAL":
                trend_match = None
            elif trend == "RANGE":
                trend_match = None
            else:
                strength = max(30, strength - 20)
                trend_match = False

            signals.append({
                "time": c2["time"],
                "pattern": d["pattern"],
                "direction": direction,
                "strength": strength,
                "trend_match": trend_match,
                "candle_index": i,
            })

    # 最後のシグナルのみ返す（最新優先）
    signals.sort(key=lambda x: x["candle_index"], reverse=True)
    return signals[:5]


def generate_entry(pair, signal, candle):
    """エントリー価格・SL・TPを計算"""
    pip = PAIRS[pair]["pip"]
    price = candle["close"]
    atr = candle_range(candle)

    if signal["direction"] == "BUY":
        entry = price
        sl = candle["low"] - atr * 0.5
        tp1 = entry + atr * 1.5
        tp2 = entry + atr * 3.0
    elif signal["direction"] == "SELL":
        entry = price
        sl = candle["high"] + atr * 0.5
        tp1 = entry - atr * 1.5
        tp2 = entry - atr * 3.0
    else:
        return None

    digits = PAIRS[pair]["digits"]
    return {
        "entry": round(entry, digits),
        "sl": round(sl, digits),
        "tp1": round(tp1, digits),
        "tp2": round(tp2, digits),
        "rr1": round(abs(tp1 - entry) / abs(sl - entry), 2) if abs(sl - entry) > 0 else 0,
        "rr2": round(abs(tp2 - entry) / abs(sl - entry), 2) if abs(sl - entry) > 0 else 0,
    }


def analyze_pair(pair):
    """ペアを分析してシグナルを返す"""
    candles_1h = generate_candles(pair, 60, 100)
    candles_15m = generate_candles(pair, 15, 80)

    trend, trend_strength = get_trend(candles_1h)
    signals = scan_patterns(candles_15m, trend)

    result_signals = []
    for sig in signals:
        idx = sig["candle_index"]
        if idx < len(candles_15m):
            entry_info = generate_entry(pair, sig, candles_15m[idx])
            if entry_info:
                sig["entry_info"] = entry_info
        result_signals.append(sig)

    # チャート用に最新40本の15M足を返す
    chart_candles = candles_15m[-40:]
    # 1H EMAデータ
    closes_1h = [c["close"] for c in candles_1h]
    ema20_1h = ema(closes_1h, 20)
    ema50_1h = ema(closes_1h, 50)

    return {
        "pair": pair,
        "pair_name": PAIRS[pair]["name"],
        "trend": trend,
        "trend_strength": trend_strength,
        "signals": result_signals,
        "candles_15m": chart_candles,
        "candles_1h": candles_1h[-40:],
        "ema20_1h": ema20_1h[-40:],
        "ema50_1h": ema50_1h[-40:],
        "updated_at": datetime.now().strftime("%Y/%m/%d %H:%M:%S"),
    }

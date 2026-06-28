"""
MT5 Bridge - Windowsマシンで実行するスクリプト
MetaTrader5 から OHLC データを取得して Flask サーバーへ送信する

使い方:
  1. Windows に MetaTrader5 をインストール
  2. pip install MetaTrader5 requests
  3. python mt5_bridge.py --server http://your-server:5000 --interval 15

必要な Python パッケージ:
  pip install MetaTrader5 requests
"""
import sys
import time
import json
import argparse
import logging
from datetime import datetime

try:
    import MetaTrader5 as mt5
except ImportError:
    print("ERROR: MetaTrader5 パッケージをインストールしてください")
    print("  pip install MetaTrader5")
    sys.exit(1)

try:
    import requests
except ImportError:
    print("ERROR: requests パッケージをインストールしてください")
    print("  pip install requests")
    sys.exit(1)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
log = logging.getLogger(__name__)

# 対応ペアとMT5シンボル名のマッピング
SYMBOL_MAP = {
    "USDJPY": "USDJPY",
    "EURUSD": "EURUSD",
    "EURJPY": "EURJPY",
    "XAUUSD": "XAUUSD",  # Gold: ブローカーによって GOLD, XAUUSDm など異なる場合あり
}

# MT5 タイムフレーム定数
TF_MAP = {
    "1m":  mt5.TIMEFRAME_M1,
    "5m":  mt5.TIMEFRAME_M5,
    "15m": mt5.TIMEFRAME_M15,
    "30m": mt5.TIMEFRAME_M30,
    "1h":  mt5.TIMEFRAME_H1,
    "4h":  mt5.TIMEFRAME_H4,
    "1d":  mt5.TIMEFRAME_D1,
}


def connect_mt5(login=None, password=None, server=None, path=None):
    """MT5ターミナルに接続"""
    kwargs = {}
    if path:
        kwargs["path"] = path
    if login and password and server:
        kwargs["login"] = int(login)
        kwargs["password"] = password
        kwargs["server"] = server

    if not mt5.initialize(**kwargs):
        log.error(f"MT5 初期化失敗: {mt5.last_error()}")
        return False

    info = mt5.terminal_info()
    log.info(f"MT5 接続成功: {info.name} build {info.build}")
    return True


def get_rates(symbol, tf_str, count):
    """MT5からOHLCデータを取得"""
    tf = TF_MAP.get(tf_str)
    if tf is None:
        log.error(f"不明なタイムフレーム: {tf_str}")
        return None

    rates = mt5.copy_rates_from_pos(symbol, tf, 0, count)
    if rates is None:
        log.warning(f"{symbol}/{tf_str}: データ取得失敗 {mt5.last_error()}")
        return None

    candles = []
    for r in rates:
        candles.append({
            "time": datetime.utcfromtimestamp(r["time"]).strftime("%Y-%m-%d %H:%M"),
            "timestamp": int(r["time"]),
            "open":  round(float(r["open"]),  5),
            "high":  round(float(r["high"]),  5),
            "low":   round(float(r["low"]),   5),
            "close": round(float(r["close"]), 5),
            "volume": int(r["tick_volume"]),
        })
    return candles


def push_to_server(server_url, pair, candles_15m, candles_1h):
    """Flask サーバーへデータを送信"""
    payload = {
        "pair": pair,
        "candles_15m": candles_15m,
        "candles_1h": candles_1h,
        "pushed_at": datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S"),
    }
    try:
        res = requests.post(
            f"{server_url}/api/mt5/push",
            json=payload,
            timeout=10,
        )
        if res.status_code == 200:
            log.info(f"  {pair}: 送信成功 (15M:{len(candles_15m)}本, 1H:{len(candles_1h)}本)")
            return True
        else:
            log.warning(f"  {pair}: サーバーエラー {res.status_code}")
            return False
    except requests.exceptions.ConnectionError:
        log.error(f"  {pair}: サーバーに接続できません ({server_url})")
        return False
    except Exception as e:
        log.error(f"  {pair}: 送信エラー {e}")
        return False


def run(server_url, interval_sec, custom_symbols):
    symbols = custom_symbols if custom_symbols else SYMBOL_MAP

    log.info(f"ブリッジ開始: サーバー={server_url}, 更新間隔={interval_sec}秒")
    log.info(f"対象ペア: {list(symbols.keys())}")

    while True:
        log.info("--- データ取得・送信 ---")
        for pair, mt5_symbol in symbols.items():
            # シンボルが使用可能か確認
            sym_info = mt5.symbol_info(mt5_symbol)
            if sym_info is None:
                log.warning(f"  {pair}: シンボル '{mt5_symbol}' が見つかりません。スキップします")
                continue

            if not sym_info.visible:
                mt5.symbol_select(mt5_symbol, True)

            c15m = get_rates(mt5_symbol, "15m", 100)
            c1h  = get_rates(mt5_symbol, "1h",  100)

            if c15m and c1h:
                push_to_server(server_url, pair, c15m, c1h)
            else:
                log.warning(f"  {pair}: データなし")

        log.info(f"次の更新まで {interval_sec} 秒待機...")
        time.sleep(interval_sec)


def main():
    parser = argparse.ArgumentParser(description="MT5 → Flask ブリッジ")
    parser.add_argument("--server",   default="http://localhost:5000", help="Flask サーバーURL")
    parser.add_argument("--interval", type=int, default=15, help="更新間隔（秒）")
    parser.add_argument("--login",    default=None, help="MT5 ログインID（省略可）")
    parser.add_argument("--password", default=None, help="MT5 パスワード（省略可）")
    parser.add_argument("--mt5server",default=None, help="MT5 サーバー名（省略可）")
    parser.add_argument("--path",     default=None, help="MT5 terminal64.exe のパス（省略可）")
    parser.add_argument("--symbols",  default=None, nargs="+",
                        help="カスタムシンボル名 例: --symbols USDJPY EURUSD XAUUSDm")
    args = parser.parse_args()

    custom_symbols = None
    if args.symbols:
        pairs = ["USDJPY", "EURUSD", "EURJPY", "XAUUSD"]
        if len(args.symbols) != len(pairs):
            print(f"ERROR: --symbols は {len(pairs)} 個指定してください: {pairs}")
            sys.exit(1)
        custom_symbols = dict(zip(pairs, args.symbols))

    if not connect_mt5(args.login, args.password, args.mt5server, args.path):
        sys.exit(1)

    try:
        run(args.server, args.interval, custom_symbols)
    except KeyboardInterrupt:
        log.info("ブリッジを停止します")
    finally:
        mt5.shutdown()


if __name__ == "__main__":
    main()

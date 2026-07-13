"""
FX Analysis API
マルチタイムフレーム FX 分析 API
"""

from flask import Blueprint, request, jsonify
import pandas as pd
import numpy as np
from datetime import datetime, timedelta
from fx_analyzer import FXMultiframeAnalyzer, HigherLowAnalyzer, PatternRecognition


# Blueprint定義
fx_bp = Blueprint('fx', __name__, url_prefix='/api/fx')


def generate_mock_ohlc_data(timeframe: str, bars: int = 100) -> pd.DataFrame:
    """
    モックOHLCデータ生成（テスト用）

    Args:
        timeframe: タイムフレーム ('1H', '4H', 'D', 'W')
        bars: バー数

    Returns:
        OHLCDataFrame
    """
    np.random.seed(42)

    # 時間軸
    if timeframe == '1H':
        start = datetime.now() - timedelta(hours=bars)
        freq = 'H'
    elif timeframe == '4H':
        start = datetime.now() - timedelta(hours=bars * 4)
        freq = '4H'
    elif timeframe == 'D':
        start = datetime.now() - timedelta(days=bars)
        freq = 'D'
    elif timeframe == 'W':
        start = datetime.now() - timedelta(weeks=bars)
        freq = 'W'
    else:
        start = datetime.now() - timedelta(hours=bars)
        freq = 'H'

    dates = pd.date_range(start=start, periods=bars, freq=freq)

    # トレンドで価格を生成
    trend = np.random.randn(bars).cumsum() * 0.5
    base_price = 100 + trend
    opens = base_price + np.random.randn(bars) * 0.3
    closes = base_price + np.random.randn(bars) * 0.3
    highs = np.maximum(opens, closes) + abs(np.random.randn(bars)) * 0.5
    lows = np.minimum(opens, closes) - abs(np.random.randn(bars)) * 0.5

    df = pd.DataFrame({
        'time': dates,
        'open': opens,
        'high': highs,
        'low': lows,
        'close': closes,
        'volume': np.random.randint(1000000, 5000000, bars)
    })

    df.set_index('time', inplace=True)
    return df


@fx_bp.route('/analyze', methods=['POST'])
def analyze_fx():
    """
    マルチタイムフレーム FX 分析エンドポイント

    Request JSON:
    {
        "symbol": "EUR/USD",
        "timeframes": ["1H", "4H", "D", "W"],
        "fast_ma": 9,
        "slow_ma": 21,
        "rsi_length": 14
    }

    Returns:
    {
        "success": bool,
        "symbol": str,
        "analyses": {
            "4H": {
                "timeframe": str,
                "trend_type": str,
                "ma_fast": float,
                "ma_slow": float,
                "rsi": float,
                "price": float,
                "support": float,
                "resistance": float,
                "signal_strength": float
            },
            ...
        },
        "signals": [
            {
                "type": "BUY"|"SELL",
                "timeframe": str,
                "reason": str,
                "confidence": float,
                "entry_price": float,
                "stop_loss": float,
                "take_profit": float,
                "risk_reward": float
            }
        ],
        "patterns": {
            "4H": {
                "engulfing": {"bullish": 0, "bearish": 1},
                "hammer": {"hammer": 0, "inverted_hammer": 1}
            }
        }
    }
    """
    try:
        data = request.get_json()
        symbol = data.get('symbol', 'EUR/USD')
        timeframes = data.get('timeframes', ['1H', '4H', 'D', 'W'])
        fast_ma = data.get('fast_ma', 9)
        slow_ma = data.get('slow_ma', 21)
        rsi_length = data.get('rsi_length', 14)

        # アナライザー初期化
        analyzer = FXMultiframeAnalyzer(
            fast_ma=fast_ma,
            slow_ma=slow_ma,
            rsi_length=rsi_length
        )

        # モックデータ取得
        ohlc_data = {}
        for tf in timeframes:
            ohlc_data[tf] = generate_mock_ohlc_data(tf, bars=100)

        # マルチタイムフレーム分析
        analyses = analyzer.analyze(ohlc_data)

        # 分析結果をdictに変換
        analyses_dict = {}
        for tf, analysis in analyses.items():
            analyses_dict[tf] = {
                'timeframe': analysis.timeframe,
                'trend_type': analysis.trend_type.name,
                'ma_fast': round(analysis.ma_fast, 5),
                'ma_slow': round(analysis.ma_slow, 5),
                'rsi': round(analysis.rsi, 2),
                'price': round(analysis.price, 5),
                'support': round(analysis.support, 5),
                'resistance': round(analysis.resistance, 5),
                'signal_strength': round(analysis.signal_strength, 2)
            }

        # シグナル生成
        signals = analyzer.generate_signals(analyses)
        signals_list = []
        for signal in signals:
            risk_reward = analyzer.calculate_risk_reward(
                signal.entry_price,
                signal.stop_loss,
                signal.take_profit
            )
            signals_list.append({
                'type': signal.type,
                'timeframe': signal.timeframe,
                'reason': signal.reason,
                'confidence': round(signal.confidence, 2),
                'entry_price': round(signal.entry_price, 5),
                'stop_loss': round(signal.stop_loss, 5),
                'take_profit': round(signal.take_profit, 5),
                'risk_reward': round(risk_reward['ratio'], 2)
            })

        # パターン認識
        patterns = {}
        for tf in timeframes:
            if tf in ohlc_data:
                df = ohlc_data[tf]
                patterns[tf] = {
                    'engulfing': PatternRecognition.detect_engulfing(df),
                    'hammer': PatternRecognition.detect_hammer_inverted_hammer(df),
                }

        return jsonify({
            'success': True,
            'symbol': symbol,
            'analyzed_at': datetime.now().isoformat(),
            'analyses': analyses_dict,
            'signals': signals_list,
            'patterns': patterns,
            'message': f'Analyzed {symbol} across {len(timeframes)} timeframes'
        })

    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 400


@fx_bp.route('/signals', methods=['POST'])
def get_signals():
    """
    トレードシグナルのみ取得

    Request JSON:
    {
        "symbol": "EUR/USD",
        "timeframes": ["4H", "D"]
    }
    """
    try:
        data = request.get_json()
        symbol = data.get('symbol', 'EUR/USD')
        timeframes = data.get('timeframes', ['4H', 'D'])

        analyzer = FXMultiframeAnalyzer()

        # モックデータ
        ohlc_data = {}
        for tf in timeframes:
            ohlc_data[tf] = generate_mock_ohlc_data(tf, bars=100)

        # 分析
        analyses = analyzer.analyze(ohlc_data)

        # シグナル
        signals = analyzer.generate_signals(analyses)
        signals_list = []

        for signal in signals:
            risk_reward = analyzer.calculate_risk_reward(
                signal.entry_price,
                signal.stop_loss,
                signal.take_profit
            )
            signals_list.append({
                'type': signal.type,
                'timeframe': signal.timeframe,
                'reason': signal.reason,
                'confidence': round(signal.confidence, 2),
                'entry_price': round(signal.entry_price, 5),
                'stop_loss': round(signal.stop_loss, 5),
                'take_profit': round(signal.take_profit, 5),
                'risk_reward': round(risk_reward['ratio'], 2),
                'time': signal.time.isoformat()
            })

        return jsonify({
            'success': True,
            'symbol': symbol,
            'signal_count': len(signals_list),
            'signals': signals_list
        })

    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 400


@fx_bp.route('/higher-lows', methods=['POST'])
def detect_higher_lows():
    """
    高値安値パターンの検出

    Request JSON:
    {
        "symbol": "EUR/USD",
        "timeframe": "4H"
    }
    """
    try:
        data = request.get_json()
        symbol = data.get('symbol', 'EUR/USD')
        timeframe = data.get('timeframe', '4H')

        # モックデータ
        df = generate_mock_ohlc_data(timeframe, bars=50)

        # パターン検出
        higher_lows = HigherLowAnalyzer.identify_higher_lows(df, window=5)
        lower_highs = HigherLowAnalyzer.identify_lower_highs(df, window=5)

        return jsonify({
            'success': True,
            'symbol': symbol,
            'timeframe': timeframe,
            'higher_lows_indices': higher_lows,
            'lower_highs_indices': lower_highs,
            'higher_lows_count': len(higher_lows),
            'lower_highs_count': len(lower_highs)
        })

    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 400


@fx_bp.route('/risk-reward', methods=['POST'])
def calculate_risk_reward():
    """
    リスク・リワード比率の計算

    Request JSON:
    {
        "entry_price": 1.0950,
        "stop_loss": 1.0920,
        "take_profit": 1.1000
    }
    """
    try:
        data = request.get_json()
        entry = data.get('entry_price', 1.0)
        stop_loss = data.get('stop_loss', 0.95)
        take_profit = data.get('take_profit', 1.1)

        analyzer = FXMultiframeAnalyzer()
        risk_reward = analyzer.calculate_risk_reward(entry, stop_loss, take_profit)

        return jsonify({
            'success': True,
            'entry_price': entry,
            'stop_loss': stop_loss,
            'take_profit': take_profit,
            'risk': round(risk_reward['risk'], 5),
            'reward': round(risk_reward['reward'], 5),
            'ratio': round(risk_reward['ratio'], 2),
            'risk_percent': round(risk_reward['risk_percent'], 2)
        })

    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 400


@fx_bp.route('/health', methods=['GET'])
def health_check():
    """ヘルスチェック"""
    return jsonify({
        'status': 'healthy',
        'service': 'FX Multi-Timeframe Analyzer',
        'version': '1.0.0',
        'timestamp': datetime.now().isoformat()
    })

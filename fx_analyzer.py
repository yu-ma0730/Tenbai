"""
FX Multi-Timeframe Analysis Engine
マルチタイムフレーム FX 分析エンジン
"""

import pandas as pd
import numpy as np
from typing import Dict, List, Tuple, Optional
from dataclasses import dataclass
from enum import Enum
from datetime import datetime, timedelta


class TrendType(Enum):
    """トレンドタイプ"""
    UPTREND = 1
    DOWNTREND = -1
    RANGE = 0


@dataclass
class TrendAnalysis:
    """トレンド分析結果"""
    timeframe: str
    trend_type: TrendType
    ma_fast: float
    ma_slow: float
    rsi: float
    price: float
    support: float
    resistance: float
    signal_strength: float  # 0-100スケール


@dataclass
class SignalPoint:
    """トレードシグナル"""
    time: datetime
    type: str  # 'BUY', 'SELL'
    timeframe: str
    reason: str
    confidence: float  # 0-100
    entry_price: float
    stop_loss: float
    take_profit: float


class FXMultiframeAnalyzer:
    """FXマルチタイムフレーム分析クラス"""

    def __init__(self, fast_ma: int = 9, slow_ma: int = 21,
                 rsi_length: int = 14, macd_fast: int = 12,
                 macd_slow: int = 26, macd_signal: int = 9):
        """
        初期化

        Args:
            fast_ma: 短期移動平均期間
            slow_ma: 長期移動平均期間
            rsi_length: RSI計算期間
            macd_fast: MACD短期期間
            macd_slow: MACD長期期間
            macd_signal: MACDシグナル期間
        """
        self.fast_ma = fast_ma
        self.slow_ma = slow_ma
        self.rsi_length = rsi_length
        self.macd_fast = macd_fast
        self.macd_slow = macd_slow
        self.macd_signal = macd_signal

    def analyze(self, ohlc_data: Dict[str, pd.DataFrame]) -> Dict[str, TrendAnalysis]:
        """
        マルチタイムフレーム分析

        Args:
            ohlc_data: タイムフレーム別OHLCデータ
                      {'4H': DataFrame, 'D': DataFrame, 'W': DataFrame}

        Returns:
            各タイムフレームの分析結果
        """
        results = {}
        for timeframe, df in ohlc_data.items():
            results[timeframe] = self._analyze_single_timeframe(timeframe, df)
        return results

    def _analyze_single_timeframe(self, timeframe: str, df: pd.DataFrame) -> TrendAnalysis:
        """単一タイムフレームの分析"""
        df = df.copy()

        # 移動平均
        df['MA_fast'] = df['close'].rolling(window=self.fast_ma).mean()
        df['MA_slow'] = df['close'].rolling(window=self.slow_ma).mean()

        # RSI
        df['RSI'] = self._calculate_rsi(df['close'], self.rsi_length)

        # 最新値
        latest = df.iloc[-1]
        ma_fast = latest['MA_fast']
        ma_slow = latest['MA_slow']
        rsi = latest['RSI']
        price = latest['close']

        # トレンド判定
        trend_type = self._determine_trend(ma_fast, ma_slow, latest['high'], latest['low'])

        # サポート・レジスタンス
        support, resistance = self._calculate_support_resistance(df, period=20)

        # シグナル強度（信頼度）
        signal_strength = self._calculate_signal_strength(df, trend_type, rsi)

        return TrendAnalysis(
            timeframe=timeframe,
            trend_type=trend_type,
            ma_fast=float(ma_fast) if pd.notna(ma_fast) else 0.0,
            ma_slow=float(ma_slow) if pd.notna(ma_slow) else 0.0,
            rsi=float(rsi) if pd.notna(rsi) else 50.0,
            price=float(price),
            support=float(support),
            resistance=float(resistance),
            signal_strength=signal_strength
        )

    @staticmethod
    def _calculate_rsi(prices: pd.Series, period: int = 14) -> pd.Series:
        """RSI計算"""
        delta = prices.diff()
        gain = (delta.where(delta > 0, 0)).rolling(window=period).mean()
        loss = (-delta.where(delta < 0, 0)).rolling(window=period).mean()
        rs = gain / loss
        rsi = 100 - (100 / (1 + rs))
        return rsi

    @staticmethod
    def _determine_trend(ma_fast: float, ma_slow: float,
                         high: float, low: float) -> TrendType:
        """トレンド判定"""
        if pd.isna(ma_fast) or pd.isna(ma_slow):
            return TrendType.RANGE

        if ma_fast > ma_slow and high > ma_slow:
            return TrendType.UPTREND
        elif ma_fast < ma_slow and low < ma_slow:
            return TrendType.DOWNTREND
        else:
            return TrendType.RANGE

    @staticmethod
    def _calculate_support_resistance(df: pd.DataFrame, period: int = 20) -> Tuple[float, float]:
        """サポート・レジスタンスレベルの計算"""
        recent = df.tail(period)
        support = recent['low'].min()
        resistance = recent['high'].max()
        return support, resistance

    @staticmethod
    def _calculate_signal_strength(df: pd.DataFrame, trend_type: TrendType,
                                   rsi: float) -> float:
        """シグナル強度の計算（0-100）"""
        strength = 50.0  # 基本値

        # トレンド方向による加点
        if trend_type == TrendType.UPTREND:
            # RSIが30以上70以下なら強い
            if 30 < rsi < 70:
                strength += 20
            # RSIが50以上なら加点
            if rsi >= 50:
                strength += 10
        elif trend_type == TrendType.DOWNTREND:
            if 30 < rsi < 70:
                strength += 20
            if rsi <= 50:
                strength += 10
        else:
            strength -= 10

        # 最新バーの値幅による加点
        latest = df.iloc[-1]
        atr = FXMultiframeAnalyzer._calculate_atr(df, period=14)
        if not pd.isna(atr) and atr > 0:
            bar_range = latest['high'] - latest['low']
            if bar_range > atr * 0.8:
                strength += 5

        return min(100.0, max(0.0, strength))

    @staticmethod
    def _calculate_atr(df: pd.DataFrame, period: int = 14) -> float:
        """ATR（Average True Range）計算"""
        df = df.copy()
        df['tr1'] = df['high'] - df['low']
        df['tr2'] = abs(df['high'] - df['close'].shift())
        df['tr3'] = abs(df['low'] - df['close'].shift())
        df['tr'] = df[['tr1', 'tr2', 'tr3']].max(axis=1)
        atr = df['tr'].rolling(window=period).mean()
        return atr.iloc[-1]

    def generate_signals(self, analyses: Dict[str, TrendAnalysis]) -> List[SignalPoint]:
        """
        複数タイムフレームからシグナルを生成

        Args:
            analyses: 各タイムフレームの分析結果

        Returns:
            トレードシグナルリスト
        """
        signals = []

        # タイムフレームの優先度
        timeframes = ['W', 'D', '4H', '1H', '15m']
        available = {tf: analyses[tf] for tf in timeframes if tf in analyses}

        if not available:
            return signals

        # マルチタイムフレーム確認
        all_bullish = all(a.trend_type == TrendType.UPTREND for a in available.values())
        all_bearish = all(a.trend_type == TrendType.DOWNTREND for a in available.values())

        # 日足と4時間足で確認（主要シグナル）
        if 'D' in available and '4H' in available:
            daily = available['D']
            tf4h = available['4H']

            # 買いシグナル
            if daily.trend_type == TrendType.UPTREND and tf4h.trend_type == TrendType.UPTREND:
                confidence = 80.0 if all_bullish else 65.0
                reason = "Daily and 4H Uptrend"
                if all_bullish:
                    reason += " (All TFs aligned)"

                signal = SignalPoint(
                    time=datetime.now(),
                    type='BUY',
                    timeframe='4H',
                    reason=reason,
                    confidence=confidence,
                    entry_price=tf4h.price,
                    stop_loss=tf4h.support,
                    take_profit=tf4h.resistance
                )
                signals.append(signal)

            # 売りシグナル
            elif daily.trend_type == TrendType.DOWNTREND and tf4h.trend_type == TrendType.DOWNTREND:
                confidence = 80.0 if all_bearish else 65.0
                reason = "Daily and 4H Downtrend"
                if all_bearish:
                    reason += " (All TFs aligned)"

                signal = SignalPoint(
                    time=datetime.now(),
                    type='SELL',
                    timeframe='4H',
                    reason=reason,
                    confidence=confidence,
                    entry_price=tf4h.price,
                    stop_loss=tf4h.resistance,
                    take_profit=tf4h.support
                )
                signals.append(signal)

        return signals

    def calculate_risk_reward(self, entry: float, stop_loss: float,
                             take_profit: float) -> Dict[str, float]:
        """
        リスク・リワード比率の計算

        Args:
            entry: エントリー価格
            stop_loss: ストップロス価格
            take_profit: テイクプロフィット価格

        Returns:
            リスク・リワード情報
        """
        risk = abs(entry - stop_loss)
        reward = abs(take_profit - entry)

        if risk == 0:
            return {
                'risk': 0.0,
                'reward': 0.0,
                'ratio': 0.0,
                'risk_percent': 0.0
            }

        ratio = reward / risk if risk > 0 else 0.0
        risk_percent = (risk / entry) * 100 if entry > 0 else 0.0

        return {
            'risk': risk,
            'reward': reward,
            'ratio': ratio,
            'risk_percent': risk_percent
        }


class HigherLowAnalyzer:
    """高値と安値のパターン分析"""

    @staticmethod
    def identify_higher_lows(df: pd.DataFrame, window: int = 5) -> List[int]:
        """高値安値パターンを識別"""
        lows = df['low'].values
        indices = []

        for i in range(window, len(lows) - window):
            if lows[i] > lows[i - window] and lows[i] > lows[i - window // 2]:
                indices.append(i)

        return indices

    @staticmethod
    def identify_lower_highs(df: pd.DataFrame, window: int = 5) -> List[int]:
        """低値高値パターンを識別"""
        highs = df['high'].values
        indices = []

        for i in range(window, len(highs) - window):
            if highs[i] < highs[i - window] and highs[i] < highs[i - window // 2]:
                indices.append(i)

        return indices


class PatternRecognition:
    """ローソク足パターン認識"""

    @staticmethod
    def detect_engulfing(df: pd.DataFrame) -> Dict[str, int]:
        """エングルフィングパターン検出"""
        if len(df) < 2:
            return {'bullish': 0, 'bearish': 0}

        current = df.iloc[-1]
        previous = df.iloc[-2]

        bullish = (
            previous['close'] < previous['open'] and
            current['close'] > current['open'] and
            current['open'] <= previous['close'] and
            current['close'] >= previous['open']
        )

        bearish = (
            previous['close'] > previous['open'] and
            current['close'] < current['open'] and
            current['open'] >= previous['close'] and
            current['close'] <= previous['open']
        )

        return {
            'bullish': 1 if bullish else 0,
            'bearish': 1 if bearish else 0
        }

    @staticmethod
    def detect_hammer_inverted_hammer(df: pd.DataFrame) -> Dict[str, int]:
        """ハンマーと逆ハンマーの検出"""
        if len(df) < 1:
            return {'hammer': 0, 'inverted_hammer': 0}

        current = df.iloc[-1]
        body_size = abs(current['close'] - current['open'])
        lower_wick = current['open'] - current['low'] if current['open'] < current['close'] else current['close'] - current['low']
        upper_wick = current['high'] - current['close'] if current['open'] < current['close'] else current['high'] - current['open']

        total_range = current['high'] - current['low']
        if total_range == 0:
            return {'hammer': 0, 'inverted_hammer': 0}

        # ハンマー：下ヒゲが長い
        is_hammer = lower_wick > body_size * 2 and upper_wick < body_size * 0.5
        # 逆ハンマー：上ヒゲが長い
        is_inverted = upper_wick > body_size * 2 and lower_wick < body_size * 0.5

        return {
            'hammer': 1 if is_hammer else 0,
            'inverted_hammer': 1 if is_inverted else 0
        }

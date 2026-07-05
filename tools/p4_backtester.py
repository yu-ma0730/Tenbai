#!/usr/bin/env python3
"""
P4 Method Backtester
Backtest P4 trading method on historical OHLCV data
"""

import pandas as pd
import numpy as np
from datetime import datetime, timedelta
import json
from typing import Dict, List, Tuple, Optional
import ta  # Technical Analysis library


class P4Backtester:
    def __init__(self, symbol: str, timeframe: str = '15m'):
        """
        Initialize P4 Backtester

        Args:
            symbol: Trading pair (e.g., 'EURUSD')
            timeframe: Candle timeframe (e.g., '15m', '1h')
        """
        self.symbol = symbol
        self.timeframe = timeframe
        self.df = None
        self.trades = []
        self.stats = {}

    def load_data(self, filepath: str) -> None:
        """
        Load OHLCV data from CSV file
        Expected columns: datetime, open, high, low, close, volume
        """
        self.df = pd.read_csv(filepath)
        self.df['datetime'] = pd.to_datetime(self.df['datetime'])
        self.df.set_index('datetime', inplace=True)
        self.df.sort_index(inplace=True)
        print(f"Loaded {len(self.df)} candles for {self.symbol}")

    def calculate_indicators(self) -> None:
        """Calculate EMA and Bollinger Bands"""
        if self.df is None:
            raise ValueError("Load data first with load_data()")

        # Calculate EMAs
        self.df['EMA10'] = ta.trend.ema_indicator(self.df['close'], window=10)
        self.df['EMA20'] = ta.trend.ema_indicator(self.df['close'], window=20)
        self.df['EMA40'] = ta.trend.ema_indicator(self.df['close'], window=40)
        self.df['EMA80'] = ta.trend.ema_indicator(self.df['close'], window=80)

        # Calculate Bollinger Bands
        bb = ta.volatility.BollingerBands(self.df['close'], window=20, window_dev=2)
        self.df['BB_Upper'] = bb.bollinger_hband()
        self.df['BB_Middle'] = bb.bollinger_mavg()
        self.df['BB_Lower'] = bb.bollinger_lband()

        print("Indicators calculated")

    def check_perfect_order(self, row) -> int:
        """
        Check perfect order status
        Returns: 1 for LONG, -1 for SHORT, 0 for no order
        """
        ema10 = row['EMA10']
        ema20 = row['EMA20']
        ema40 = row['EMA40']
        ema80 = row['EMA80']

        # LONG: EMA10 > EMA20 > EMA40 > EMA80
        if ema10 > ema20 and ema20 > ema40 and ema40 > ema80:
            return 1

        # SHORT: EMA80 > EMA40 > EMA20 > EMA10
        if ema80 > ema40 and ema40 > ema20 and ema20 > ema10:
            return -1

        return 0

    def find_support_resistance(self, df_segment: pd.DataFrame, is_long: bool) -> Optional[float]:
        """
        Find support (for long) or resistance (for short) line
        Returns the price level where line should be drawn
        """
        if len(df_segment) < 10:
            return None

        lows = df_segment['low'].values
        highs = df_segment['high'].values

        if is_long:
            # Find the lowest low in recent bars (pullback)
            support = np.min(lows[-10:])
            return support
        else:
            # Find the highest high in recent bars (pullback)
            resistance = np.max(highs[-10:])
            return resistance

    def backtest(self) -> Dict:
        """
        Run backtest with P4 method rules
        """
        if self.df is None:
            raise ValueError("Load data first with load_data()")

        self.df['PerfectOrder'] = self.df.apply(self.check_perfect_order, axis=1)
        self.df['Signal'] = 0
        self.df['EntryPrice'] = np.nan

        in_trade = False
        trade_direction = 0  # 1 for long, -1 for short
        entry_price = 0
        entry_index = 0
        support_level = 0
        bb_breakout = False

        self.trades = []

        for i in range(80, len(self.df) - 1):
            current_row = self.df.iloc[i]
            next_row = self.df.iloc[i + 1]
            current_order = current_row['PerfectOrder']

            # Skip if no perfect order
            if current_order == 0:
                if in_trade and trade_direction == current_order:
                    # Exit trade if perfect order reverses
                    in_trade = False
                continue

            # Generate entry signal
            if not in_trade and current_order != 0:
                # Look back for support/resistance
                lookback_df = self.df.iloc[max(0, i-50):i]

                if current_order == 1:  # LONG signal
                    support = self.find_support_resistance(lookback_df, is_long=True)
                    if support and current_row['close'] > support:
                        # Check if breaking out of BB lower band
                        if current_row['close'] > current_row['BB_Lower']:
                            entry_price = current_row['close']
                            entry_index = i
                            trade_direction = 1
                            in_trade = True
                            support_level = support
                            bb_breakout = False
                            self.df.at[self.df.index[i], 'Signal'] = 1
                            self.df.at[self.df.index[i], 'EntryPrice'] = entry_price

                elif current_order == -1:  # SHORT signal
                    resistance = self.find_support_resistance(lookback_df, is_long=False)
                    if resistance and current_row['close'] < resistance:
                        # Check if breaking out of BB upper band
                        if current_row['close'] < current_row['BB_Upper']:
                            entry_price = current_row['close']
                            entry_index = i
                            trade_direction = -1
                            in_trade = True
                            support_level = resistance
                            bb_breakout = False
                            self.df.at[self.df.index[i], 'Signal'] = -1
                            self.df.at[self.df.index[i], 'EntryPrice'] = entry_price

            # Manage active trade
            if in_trade:
                current_price = current_row['close']
                risk = abs(entry_price - support_level)

                if trade_direction == 1:  # LONG trade
                    stop_loss = support_level
                    take_profit = entry_price + (risk * 1.0)  # 1:1 RR

                    # Check for exit conditions
                    if current_price <= stop_loss:
                        # Stop loss hit
                        profit = current_price - entry_price
                        self._record_trade(1, entry_price, current_price, risk, profit)
                        in_trade = False
                    elif current_price >= take_profit:
                        # Take profit hit
                        profit = take_profit - entry_price
                        self._record_trade(1, entry_price, take_profit, risk, profit)
                        in_trade = False
                    elif current_order == -1:
                        # Perfect order reversed
                        profit = current_price - entry_price
                        self._record_trade(1, entry_price, current_price, risk, profit)
                        in_trade = False

                elif trade_direction == -1:  # SHORT trade
                    stop_loss = support_level
                    take_profit = entry_price - (risk * 1.0)  # 1:1 RR

                    # Check for exit conditions
                    if current_price >= stop_loss:
                        # Stop loss hit
                        profit = entry_price - current_price
                        self._record_trade(-1, entry_price, current_price, risk, profit)
                        in_trade = False
                    elif current_price <= take_profit:
                        # Take profit hit
                        profit = entry_price - take_profit
                        self._record_trade(-1, entry_price, take_profit, risk, profit)
                        in_trade = False
                    elif current_order == 1:
                        # Perfect order reversed
                        profit = entry_price - current_price
                        self._record_trade(-1, entry_price, current_price, risk, profit)
                        in_trade = False

        return self.calculate_stats()

    def _record_trade(self, direction: int, entry: float, exit_price: float,
                      risk: float, profit: float) -> None:
        """Record a completed trade"""
        self.trades.append({
            'direction': 'LONG' if direction == 1 else 'SHORT',
            'entry_price': round(entry, 5),
            'exit_price': round(exit_price, 5),
            'risk': round(risk, 5),
            'profit': round(profit, 5),
            'rr_ratio': round(abs(profit / risk) if risk > 0 else 0, 2),
            'win': profit > 0
        })

    def calculate_stats(self) -> Dict:
        """Calculate backtest statistics"""
        if not self.trades:
            return {
                'total_trades': 0,
                'winning_trades': 0,
                'losing_trades': 0,
                'win_rate': 0,
                'total_profit': 0,
                'avg_profit': 0,
                'max_profit': 0,
                'max_loss': 0
            }

        total_trades = len(self.trades)
        winning_trades = sum(1 for t in self.trades if t['win'])
        losing_trades = total_trades - winning_trades
        total_profit = sum(t['profit'] for t in self.trades)
        profits = [t['profit'] for t in self.trades]

        self.stats = {
            'total_trades': total_trades,
            'winning_trades': winning_trades,
            'losing_trades': losing_trades,
            'win_rate': round((winning_trades / total_trades * 100) if total_trades > 0 else 0, 2),
            'total_profit': round(total_profit, 2),
            'avg_profit': round(total_profit / total_trades if total_trades > 0 else 0, 2),
            'max_profit': round(max(profits) if profits else 0, 2),
            'max_loss': round(min(profits) if profits else 0, 2),
            'profit_factor': round(
                sum(t['profit'] for t in self.trades if t['profit'] > 0) /
                abs(sum(t['profit'] for t in self.trades if t['profit'] < 0))
                if any(t['profit'] < 0 for t in self.trades) else 0, 2
            )
        }

        return self.stats

    def print_report(self) -> None:
        """Print backtest report"""
        print("\n" + "="*60)
        print(f"P4 METHOD BACKTEST REPORT - {self.symbol} ({self.timeframe})")
        print("="*60)
        print(f"Total Trades: {self.stats['total_trades']}")
        print(f"Winning Trades: {self.stats['winning_trades']}")
        print(f"Losing Trades: {self.stats['losing_trades']}")
        print(f"Win Rate: {self.stats['win_rate']}%")
        print(f"Total Profit: {self.stats['total_profit']}")
        print(f"Average Profit: {self.stats['avg_profit']}")
        print(f"Max Profit: {self.stats['max_profit']}")
        print(f"Max Loss: {self.stats['max_loss']}")
        print(f"Profit Factor: {self.stats['profit_factor']}")
        print("="*60)

    def export_trades(self, filepath: str) -> None:
        """Export trade results to JSON"""
        with open(filepath, 'w') as f:
            json.dump({
                'symbol': self.symbol,
                'timeframe': self.timeframe,
                'backtest_date': datetime.now().isoformat(),
                'stats': self.stats,
                'trades': self.trades
            }, f, indent=2)
        print(f"Trades exported to {filepath}")

    def export_signals(self, filepath: str) -> None:
        """Export signals and chart data"""
        export_df = self.df[['open', 'high', 'low', 'close', 'volume',
                              'EMA10', 'EMA20', 'EMA40', 'EMA80',
                              'BB_Upper', 'BB_Middle', 'BB_Lower',
                              'PerfectOrder', 'Signal', 'EntryPrice']].copy()
        export_df.to_csv(filepath)
        print(f"Chart data exported to {filepath}")


if __name__ == "__main__":
    # Example usage
    backtester = P4Backtester("EURUSD", "15m")

    # You would load your CSV data here
    # backtester.load_data("data/eurusd_15m.csv")
    # backtester.calculate_indicators()
    # stats = backtester.backtest()
    # backtester.print_report()
    # backtester.export_trades("results/trades.json")
    # backtester.export_signals("results/signals.csv")

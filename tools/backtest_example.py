#!/usr/bin/env python3
"""
P4 Method Backtest Example
Example script showing how to use the P4Backtester
"""

import sys
import os
sys.path.insert(0, os.path.dirname(__file__))

from p4_backtester import P4Backtester
import pandas as pd
import numpy as np
from datetime import datetime, timedelta

def generate_sample_data(symbol: str = "EURUSD", num_candles: int = 1000):
    """
    Generate sample OHLCV data for demonstration
    Creates realistic FX data with trends and oscillations
    """
    print(f"Generating {num_candles} sample candles for {symbol}...")

    # Starting price
    start_price = 1.0850

    # Generate timestamps (15-min candles)
    start_date = datetime(2024, 1, 1)
    timestamps = [start_date + timedelta(minutes=15*i) for i in range(num_candles)]

    # Generate OHLCV data with trend and noise
    prices = [start_price]
    trend = 0.0001  # Small uptrend
    volatility = 0.0005

    for i in range(num_candles - 1):
        # Random walk with drift
        change = np.random.normal(trend, volatility)
        new_price = prices[-1] + change

        prices.append(max(new_price, prices[-1] * 0.95))  # Prevent negative prices

    # Create OHLCV data
    data = []
    for i, price in enumerate(prices):
        # Generate realistic OHLC within the price
        open_price = price
        high = price + abs(np.random.normal(0, volatility * 2))
        low = price - abs(np.random.normal(0, volatility * 2))
        close = open_price + np.random.normal(0, volatility * 2)

        volume = np.random.randint(1000, 5000)

        data.append({
            'datetime': timestamps[i],
            'open': round(open_price, 5),
            'high': round(max(high, close, open_price), 5),
            'low': round(min(low, close, open_price), 5),
            'close': round(close, 5),
            'volume': volume
        })

    return pd.DataFrame(data)

def run_backtest_example():
    """Run backtest example"""
    print("="*70)
    print("P4 METHOD BACKTEST EXAMPLE")
    print("="*70)
    print()

    # Generate sample data
    df = generate_sample_data("EURUSD", 1000)

    # Save sample data
    os.makedirs("data", exist_ok=True)
    csv_file = "data/eurusd_15m_sample.csv"
    df.to_csv(csv_file, index=False)
    print(f"Sample data saved to: {csv_file}")
    print()

    # Run backtest
    backtester = P4Backtester("EURUSD", "15m")
    backtester.load_data(csv_file)
    backtester.calculate_indicators()

    print("Running backtest...")
    stats = backtester.backtest()
    print()

    # Print report
    backtester.print_report()
    print()

    # Export results
    os.makedirs("results", exist_ok=True)
    backtester.export_trades("results/trades_example.json")
    backtester.export_signals("results/signals_example.csv")

    # Print trade details
    print("\nTrade Details (first 10):")
    print("-"*70)
    print(f"{'#':<3} {'Direction':<8} {'Entry':<10} {'Exit':<10} {'Profit':<10} {'Win':<5}")
    print("-"*70)

    for i, trade in enumerate(backtester.trades[:10]):
        print(f"{i+1:<3} {trade['direction']:<8} {trade['entry_price']:<10} "
              f"{trade['exit_price']:<10} {trade['profit']:<10.5f} "
              f"{'✓' if trade['win'] else '✗':<5}")

    if len(backtester.trades) > 10:
        print(f"... and {len(backtester.trades) - 10} more trades")

    print()
    print("Analysis:")
    print(f"- Win Rate: {stats['win_rate']:.1f}% ({stats['winning_trades']}/{stats['total_trades']})")
    print(f"- Average Trade: {stats['avg_profit']:.5f}")
    print(f"- Profit Factor: {stats['profit_factor']:.2f}")
    print()
    print(f"Files saved:")
    print(f"  - Trades: results/trades_example.json")
    print(f"  - Signals: results/signals_example.csv")

def generate_live_trading_report():
    """Generate report comparing backtested results vs expected performance"""
    print("\n" + "="*70)
    print("PERFORMANCE EXPECTATIONS")
    print("="*70)
    print()
    print("Based on P4 Method backtest results:")
    print()
    print("Good Performance Indicators (Profitable Strategy):")
    print("  ✓ Win Rate: > 50%")
    print("  ✓ Profit Factor: > 1.5")
    print("  ✓ Average Trade: Positive")
    print()
    print("Excellent Performance Indicators (Professional Strategy):")
    print("  ✓ Win Rate: > 60%")
    print("  ✓ Profit Factor: > 2.0")
    print("  ✓ Max Consecutive Losses: < 5")
    print()
    print("Optimization Tips:")
    print("  1. Test multiple timeframes (15m, 1h, 4h)")
    print("  2. Test different currency pairs")
    print("  3. Adjust BB period (18-22 range)")
    print("  4. Consider economic calendar events")
    print("  5. Use proper position sizing (Risk 1-2% per trade)")
    print()

if __name__ == "__main__":
    try:
        run_backtest_example()
        generate_live_trading_report()
        print("\n✓ Backtest completed successfully!")
        print("\nNext steps:")
        print("1. Review results in results/trades_example.json")
        print("2. Check signals in results/signals_example.csv")
        print("3. Modify p4_backtester.py parameters to optimize")
        print("4. Test with real market data")
        print("5. Paper trade on demo account before live trading")

    except Exception as e:
        print(f"Error: {e}")
        import traceback
        traceback.print_exc()

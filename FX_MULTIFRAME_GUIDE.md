# FX マルチフレーム分析ツール ガイド

## 概要

このツールは、FX（外国為替）トレーディングのためのマルチタイムフレーム分析を提供します。複数のタイムフレーム（週足、日足、4時間足など）を同時に分析して、より信頼性の高いトレードシグナルを生成します。

## 組成要素

### 1. TradingView Pine Script (`fx_multiframe_analyzer.pine`)

TradingView プラットフォームで直接使用できるカスタムインジケータです。

**主な機能:**
- 複数タイムフレーム（4H, 1D, 1W）のトレンド分析
- 移動平均線（SMA, EMA, WMA対応）
- RSI（Relative Strength Index）表示
- MACD インジケータ
- サポート＆レジスタンスレベル自動計算
- マルチタイムフレーム状態をテーブル表示
- 自動アラート機能

**使用方法:**
1. TradingView の Chart にアクセス
2. Pine Editor を開く
3. 新しいスクリプトを作成
4. `fx_multiframe_analyzer.pine` のコードをコピー＆ペースト
5. 「Add to Chart」ボタンをクリック

**パラメータ設定:**
```
Moving Averages:
  - Fast MA Length: 9（デフォルト）
  - Slow MA Length: 21（デフォルト）
  - MA Type: SMA / EMA / WMA

RSI:
  - RSI Length: 14
  - RSI Overbought: 70
  - RSI Oversold: 30

MACD:
  - MACD Fast Length: 12
  - MACD Slow Length: 26
  - MACD Signal Length: 9

Display:
  - Show 4H Trend: ON/OFF
  - Show 1D Trend: ON/OFF
  - Show 1W Trend: ON/OFF
  - Show Alerts: ON/OFF
```

### 2. Python分析エンジン (`fx_analyzer.py`)

バックエンド分析ライブラリ。リアルタイムデータ処理と複雑な分析を実施します。

**主なクラス:**

#### FXMultiframeAnalyzer
```python
analyzer = FXMultiframeAnalyzer(
    fast_ma=9,
    slow_ma=21,
    rsi_length=14
)

# マルチタイムフレーム分析
analyses = analyzer.analyze(ohlc_data)

# シグナル生成
signals = analyzer.generate_signals(analyses)

# リスク・リワード計算
risk_reward = analyzer.calculate_risk_reward(
    entry=1.0950,
    stop_loss=1.0920,
    take_profit=1.1000
)
```

#### HigherLowAnalyzer
高値安値パターンの検出（上昇トレンド確認）

#### PatternRecognition
ローソク足パターン認識
- エングルフィング（囲み）パターン
- ハンマーと逆ハンマー

### 3. Flask API エンドポイント (`fx_api.py`)

Web APIとして提供される各種分析機能。

**エンドポイント:**

#### POST `/api/fx/analyze`
複合的なマルチタイムフレーム分析

**リクエスト:**
```json
{
  "symbol": "EUR/USD",
  "timeframes": ["1H", "4H", "D", "W"],
  "fast_ma": 9,
  "slow_ma": 21,
  "rsi_length": 14
}
```

**レスポンス:**
```json
{
  "success": true,
  "symbol": "EUR/USD",
  "analyzed_at": "2024-01-15T10:30:00",
  "analyses": {
    "4H": {
      "timeframe": "4H",
      "trend_type": "UPTREND",
      "ma_fast": 1.0950,
      "ma_slow": 1.0920,
      "rsi": 65.5,
      "price": 1.0955,
      "support": 1.0900,
      "resistance": 1.1050,
      "signal_strength": 75.3
    }
  },
  "signals": [
    {
      "type": "BUY",
      "timeframe": "4H",
      "reason": "Daily and 4H Uptrend (All TFs aligned)",
      "confidence": 80.0,
      "entry_price": 1.0955,
      "stop_loss": 1.0900,
      "take_profit": 1.1050,
      "risk_reward": 3.0
    }
  ],
  "patterns": {
    "4H": {
      "engulfing": {"bullish": 1, "bearish": 0},
      "hammer": {"hammer": 0, "inverted_hammer": 0}
    }
  }
}
```

#### POST `/api/fx/signals`
トレードシグナルのみ取得（軽量版）

**リクエスト:**
```json
{
  "symbol": "EUR/USD",
  "timeframes": ["4H", "D"]
}
```

#### POST `/api/fx/risk-reward`
リスク・リワード比率の計算

**リクエスト:**
```json
{
  "entry_price": 1.0950,
  "stop_loss": 1.0920,
  "take_profit": 1.1000
}
```

**レスポンス:**
```json
{
  "success": true,
  "entry_price": 1.0950,
  "stop_loss": 1.0920,
  "take_profit": 1.1000,
  "risk": 0.003,
  "reward": 0.005,
  "ratio": 1.67,
  "risk_percent": 0.29
}
```

#### POST `/api/fx/higher-lows`
高値安値パターン検出

#### GET `/api/fx/health`
ヘルスチェック

## 実装例

### TradingViewでの使用（Pine Script）

1. インジケータをチャートに追加
2. 4時間足で表示（推奨）
3. テーブルで複数タイムフレームのトレンドを確認：
   - 🔼 UP: アップトレンド
   - 🔽 DOWN: ダウントレンド
   - → RANGE: レンジ相場
4. Align欄で全タイムフレームの一致を確認
   - 🔼 BULL: 全てアップトレンド（強気シグナル）
   - 🔽 BEAR: 全てダウントレンド（弱気シグナル）
   - ⚠ MIX: 混合（弱いシグナル）

### Pythonバックエンドでの使用

```python
import pandas as pd
from fx_analyzer import FXMultiframeAnalyzer

# データ準備
data = {
    '4H': pd.read_csv('EURUSD_4H.csv'),
    'D': pd.read_csv('EURUSD_D.csv'),
    'W': pd.read_csv('EURUSD_W.csv')
}

# 分析実行
analyzer = FXMultiframeAnalyzer()
analyses = analyzer.analyze(data)

# トレードシグナル生成
signals = analyzer.generate_signals(analyses)

for signal in signals:
    print(f"{signal.type}: {signal.reason}")
    print(f"  Entry: {signal.entry_price}")
    print(f"  SL: {signal.stop_loss}, TP: {signal.take_profit}")
    print(f"  Confidence: {signal.confidence}%")
```

## トレード戦略ガイド

### マルチタイムフレーム確認の重要性

**推奨される確認順序:**

1. **週足 (W)**: 大きなトレンド方向を確認
   - 上昇？下降？レンジ？

2. **日足 (D)**: 中期トレンドを確認
   - 週足と同じ方向？

3. **4時間足 (4H)**: 直近のトレンド
   - 日足と同じ方向？

4. **エントリータイムフレーム (1H/15m)**: 
   - 詳細な根拠とシグナルを確認

### シグナル種別

#### 強気シグナル（BUY）
- 条件: 日足と4時間足の両方がアップトレンド
- 更に強い場合: 週足もアップトレンド（信頼度80%+）
- 目安: RSI 30-70の間が最適

#### 弱気シグナル（SELL）
- 条件: 日足と4時間足の両方がダウントレンド
- 更に強い場合: 週足もダウントレンド（信頼度80%+）
- 目安: RSI 30-70の間が最適

### リスク管理

**ストップロス設定:**
- サポートレベルの直下（買い）
- レジスタンスレベルの直上（売り）

**テイクプロフィット設定:**
- 直近のレジスタンス（買い）
- 直近のサポート（売り）

**リスク・リワード比率:**
- 最低1:1の比率
- 推奨2:1以上の比率
- 理想的には3:1以上

## テクニカル指標の解説

### 移動平均線 (MA)
- **9周期 (Fast MA)**: 短期トレンドを示す
- **21周期 (Slow MA)**: 中期トレンドを示す
- **クロスオーバー**: トレンド転換の可能性

### RSI (Relative Strength Index)
- 0-30: 売られすぎ（買い圧力）
- 70-100: 買われすぎ（売り圧力）
- 30-70: 通常相場

### MACD
- ヒストグラムがプラス/マイナス: トレンド方向
- ゼロクロス: トレンド転換シグナル

## インストール手順

### Flask アプリへの統合

```python
# app.py に追加
from fx_api import fx_bp

app.register_blueprint(fx_bp)
```

### 必要なライブラリ
```bash
pip install pandas numpy flask
```

## よくある質問

**Q: どのタイムフレームで取引すべき?**
A: 週足と日足でトレンド方向を確認し、4時間足でエントリーを検討するのが一般的です。

**Q: RSIが30-70の範囲外の場合は?**
A: トレンドが非常に強い状態です。オーバーシュート後の反発を待つか、より大きな移動を期待できます。

**Q: 複数の通貨ペアを同時に監視できる?**
A: はい。APIを通じて複数の通貨ペアを分析できます。

**Q: バックテストは可能?**
A: 本ツールはリアルタイム分析向けですが、历史データを使用してバックテストを実施することは可能です。

## 注意事項

- **デモ/バックテスト用**: 本ツールはマルチタイムフレーム分析の参考を提供するものです
- **過去のパフォーマンス保証なし**: 過去のシグナルが将来のパフォーマンスを保証しません
- **リスク管理**: 必ずストップロスを設定してください
- **完全自動売買**: 最終判断は手動で行うことを推奨します

## サポート

問題が発生した場合:
1. ログを確認
2. パラメータを調整
3. データの正確性を確認

---

**Version**: 1.0.0  
**Last Updated**: 2024年1月

# P4 Method バックテストツール - 使用ガイド

## 概要

このツールは、P4トレーディング手法をPythonで実装した過去データ検証ツールです。

## 必要な準備

### 1. Pythonパッケージのインストール

```bash
pip install -r ../requirements.txt
```

または個別にインストール：

```bash
pip install pandas numpy ta
```

### 2. データファイルの準備

バックテストには、以下の形式のCSVファイルが必要です：

```csv
datetime,open,high,low,close,volume
2024-01-01 00:15:00,1.0850,1.0860,1.0840,1.0855,1500
2024-01-01 00:30:00,1.0855,1.0870,1.0850,1.0865,1600
```

**列の説明：**
- `datetime`: 日時（YYYY-MM-DD HH:MM:SS形式）
- `open`: 始値
- `high`: 高値
- `low`: 安値
- `close`: 終値
- `volume`: 出来高

## 使用方法

### 方法1: 実行例スクリプトを使用（推奨）

サンプルデータを生成して即座にバックテストを実行：

```bash
python3 backtest_example.py
```

このコマンドは以下を実行します：
1. サンプルデータを生成
2. P4手法でバックテスト実行（新しいショート確認シグナル付き）
3. 統計情報を表示
4. 結果をJSONとCSVで保存

**確認シグナル設定**
- EMA乖離チェック有効（0.3%閾値）
- 高値更新否定検出有効
- 短期足の力不足パターン検出有効

### 方法2: 独自のデータでバックテスト（新規確認シグナル対応）

```python
from p4_backtester import P4Backtester

# インスタンス作成（新しいパラメータ付き）
backtester = P4Backtester(
    "EURUSD", 
    "15m",
    ema_divergence_threshold=0.003,  # 0.3%
    check_high_rejection=True,        # 高値更新否定チェック
    check_short_weakness=True         # 短期足力不足チェック
)

# CSVデータを読み込み
backtester.load_data("data/your_data.csv")

# テクニカル指標を計算（EMA乖離、高値拒否、短期弱さ含む）
backtester.calculate_indicators()

# バックテストを実行
stats = backtester.backtest()

# 結果を表示
backtester.print_report()

# 結果をエクスポート
backtester.export_trades("results/trades.json")
backtester.export_signals("results/signals.csv")
```

## 出力ファイル

### トレード結果（JSON形式）

`results/trades_example.json`

```json
{
  "symbol": "EURUSD",
  "timeframe": "15m",
  "backtest_date": "2024-01-15T10:30:45.123456",
  "stats": {
    "total_trades": 45,
    "winning_trades": 28,
    "losing_trades": 17,
    "win_rate": 62.22,
    "total_profit": 425.50,
    "avg_profit": 9.46,
    "max_profit": 85.25,
    "max_loss": -42.10,
    "profit_factor": 2.15
  },
  "trades": [
    {
      "direction": "LONG",
      "entry_price": 1.08500,
      "exit_price": 1.08650,
      "risk": 0.00500,
      "profit": 0.00150,
      "rr_ratio": 0.30,
      "win": true
    }
  ]
}
```

### シグナルデータ（CSV形式）

`results/signals_example.csv`

すべてのシグナル情報を含む詳細なCSVファイルで、Excelで分析可能。

## 新規追加: ショート確認シグナル

バックテスター（v1.1以降）には3つの新しいショート確認シグナルが実装されました：

### 1. EMA乖離率チェック（EMA Divergence）

```
乖離率 = |価格 - EMA10| / EMA10

警告閾値: 0.3% (0.003)
```

- 乖離が大きい → 相場が移動平均線から大きく離れている
- 相場アルゴリズムは乖離を自動的に埋めやすい
- 0.3%を超えた場合はリスク高い（シグナルをスキップ推奨）

**チャート表示**: オレンジの矢印

### 2. 高値更新否定（High Rejection Pattern）

```
高値が徐々に切り下がっている状態を検出
↓
利確売り圧力が増加している証拠
↓
ショートの初動シグナル
```

検出ロジック：
- 最近の3つの高値が下降トレンド形成
- 直近の高値更新失敗
- 下落の初期段階

**チャート表示**: 紫の矢印

### 3. 短期足の力不足（Short-term Weakness）

```
5分足での以下を検出：
- インサイドバー（前回の範囲内に収まる）が増加
- アウトサイドバー（前回の範囲を包含）が消失
- 高値の更新ができない
```

強気指標（大丈夫）：
- ✓ 反発後に戻している
- ✓ アウトサイドバーでしっかり戻している

弱気指標（危険）：
- ✗ インサイドバーばかり
- ✗ 高値の更新ができない

## パラメータの理解

### EMA周期

```
EMA10 = 10期間  → 短期トレンド（反応が早い）
EMA20 = 20期間  → 短期・中期の境界
EMA40 = 40期間  → 中期トレンド
EMA80 = 80期間  → 長期トレンド（遅行性）
```

### ボリンジャーバンド

```
BB_Period = 20（通常のSMA期間）
BB_Deviation = 2.0（標準偏差2倍）
```

## 結果の解釈

### 統計指標の意味

| 指標 | 良好な値 | 優秀な値 | 説明 |
|------|---------|---------|------|
| **Win Rate** | > 50% | > 60% | 勝率（%） |
| **Total Profit** | > 0 | > 100 | 総利益 |
| **Profit Factor** | > 1.0 | > 2.0 | 利益/損失の比率 |
| **Max Loss** | > -50 | > -30 | 最大損失（pips） |
| **Avg Profit** | > 0 | > 5 | 平均利益（pips） |

### 例：結果が60%の勝率の場合

```
Total Trades: 100
Winning Trades: 60 ✓
Losing Trades: 40 ✗
Average Profit: 8.5 pips
```

これは健全な成績です。期待値がプラスです。

## パラメータの最適化

バックテストを複数回実行して、異なるパラメータをテストしてください：

### 推奨されるテスト順序

1. **デフォルト設定でテスト**
   ```python
   backtester = P4Backtester("EURUSD", "15m")
   ```

2. **BB周期を変更してテスト**
   ```
   試す値: 18, 19, 20, 21, 22
   ```

3. **EMA周期の組み合わせをテスト**
   ```
   試す組み合わせ:
   (8, 17, 34, 68)
   (12, 24, 48, 96)
   ```

4. **複数の通貨ペアでテスト**
   ```
   通貨ペア: EURUSD, GBPUSD, USDJPY, AUDUSD
   ```

5. **複数の時間足でテスト**
   ```
   時間足: 5m, 15m, 1h, 4h
   ```

## トラブルシューティング

### エラー: "Load data first"

**原因**: `load_data()` を実行していません
**解決**: バックテスト前に `backtester.load_data("path/to/data.csv")` を実行

### エラー: "ModuleNotFoundError: No module named 'ta'"

**原因**: 必要なライブラリがインストールされていません
**解決**:
```bash
pip install ta
```

### バックテスト結果がゼロの場合

**原因**: データが不十分または形式が不正
**解決**:
1. CSVファイルの形式を確認
2. 最低200本以上のデータが必要
3. `datetime`, `open`, `high`, `low`, `close`, `volume` 列があるか確認

### 勝率が極端に高い/低い場合

**原因**: パラメータが市場に不適切
**解決**:
1. BB周期を±2調整
2. EMA周期の組み合わせを試す
3. 異なる通貨ペアでテスト
4. 異なる時間足でテスト

## 実際のトレードに向けて

### バックテスト→リアルトレードまでの流れ

```
1. バックテスト（過去データ）
   ↓
2. フォワードテスト（デモアカウント）
   ↓
3. ペーパートレード（手動記録）
   ↓
4. ライブトレード（小ロット）
```

### リアルトレード時の注意

- ✗ バックテスト結果に100%依存しない
- ✓ 複数の市場環境でテストする
- ✗ 高すぎる期待値を持たない
- ✓ リスク管理を最優先にする
- ✗ 1トレードで大きなロットを使わない
- ✓ 段階的にロットを増やす

## サンプルコード集

### 基本的な実行

```python
from p4_backtester import P4Backtester

backtester = P4Backtester("EURUSD", "15m")
backtester.load_data("data/eurusd_15m.csv")
backtester.calculate_indicators()
stats = backtester.backtest()
backtester.print_report()
```

### 複数の通貨ペアをテスト

```python
from p4_backtester import P4Backtester

pairs = ["EURUSD", "GBPUSD", "USDJPY"]
for pair in pairs:
    print(f"\n{'='*50}")
    print(f"Testing {pair}")
    print('='*50)

    backtester = P4Backtester(pair, "15m")
    backtester.load_data(f"data/{pair.lower()}_15m.csv")
    backtester.calculate_indicators()
    stats = backtester.backtest()
    backtester.print_report()
    backtester.export_trades(f"results/{pair}_trades.json")
```

### 複数の時間足をテスト

```python
from p4_backtester import P4Backtester

timeframes = ["15m", "1h", "4h"]
for tf in timeframes:
    print(f"\n{'='*50}")
    print(f"Testing EURUSD {tf}")
    print('='*50)

    backtester = P4Backtester("EURUSD", tf)
    backtester.load_data(f"data/eurusd_{tf}.csv")
    backtester.calculate_indicators()
    stats = backtester.backtest()
    backtester.print_report()
```

## さらなる情報

詳細なセットアップガイドは `../docs/P4_SETUP_GUIDE.md` を参照してください。

MT5用のインジケータとEAについては `../P4_README.md` を参照してください。

---

**Version**: 1.0  
**Update**: 2024

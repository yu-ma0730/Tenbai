# P4 Signal Tool Setup Guide

## Overview

このツールセットは、P4トレーディング手法をMT5で実装するためのフルスイート：

1. **P4_Signal_Indicator.mq5** - チャート上にEMA、ボリンジャーバンド、シグナル矢印を表示
2. **P4_Signal_EA.mq5** - 自動売買ロボット（リアルタイム取引とアラート）
3. **p4_backtester.py** - 過去データでの戦略テスト

## MT5 Indicator Setup

### インストール手順

1. `P4_Signal_Indicator.mq5`をMT5のIndicatorsフォルダにコピー：
   ```
   C:\Users\YourUserName\AppData\Roaming\MetaQuotes\Terminal\[terminal_id]\MQL5\Indicators\
   ```
   (Macの場合: `~/Library/Application Support/MetaTrader 5/MQL5/Indicators/`)

2. MT5を再起動するか、Terminal→Experts→Compileを使用してコンパイル

3. チャートにインジケータを挿入：
   - チャートを右クリック → Insert Indicator → P4_Signal_Indicator

### Indicator設定パラメータ

- **EMA10_Period**: 10（デフォルト）
- **EMA20_Period**: 20（デフォルト）
- **EMA40_Period**: 40（デフォルト）
- **EMA80_Period**: 80（デフォルト）
- **BB_Period**: 20（ボリンジャーバンド期間）
- **BB_Deviation**: 2.0（標準偏差）
- **EMA_Divergence_Threshold**: 0.003（0.3% = 危険域）
- **ShowSignalArrows**: true（シグナル矢印を表示）
- **ShowDivergenceWarning**: true（EMA乖離警告を表示・オレンジ矢印）
- **ShowHighRejectionWarning**: true（高値更新否定警告を表示・紫矢印）

### チャート表示

インジケータは以下を表示します：

**移動平均線**
- **EMA10**: 青線（最も反応が早い）
- **EMA20**: 緑線
- **EMA40**: オレンジ線
- **EMA80**: 赤線（最も遅行性）

**ボリンジャーバンド**
- **BB上側**: グレー破線
- **BB中央**: グレー点線（SMA）
- **BB下側**: グレー破線

**シグナル矢印**
- **ロングシグナル**: 青の上向き矢印（信頼度が高いエントリーポイント）
- **ショートシグナル**: 赤の下向き矢印（信頼度が高いエントリーポイント）
- **EMA乖離警告**: オレンジの矢印（価格がEMAから0.3%以上離れている）
- **高値更新否定警告**: 紫の矢印（高値が更新できず下落シグナル）

## MT5 Expert Advisor Setup

### インストール手順

1. `P4_Signal_EA.mq5`をMT5のExpertsフォルダにコピー：
   ```
   C:\Users\YourUserName\AppData\Roaming\MetaQuotes\Terminal\[terminal_id]\MQL5\Experts\
   ```

2. MT5を再起動またはコンパイル

3. EAをチャートにアタッチ：
   - チャートを右クリック → Attach Expert Advisor → P4_Signal_EA
   - パラメータを設定
   - チェックボックス「Allow Live Trading」を有効化（リアルトレード用）

### EA設定パラメータ

**基本設定**
- **RiskPercent**: 2.0（口座残高の何%をリスクするか）
- **InitialRiskRewardRatio**: 1.0（初期リスク・リワード比率1:1）
- **EMA10_Period～EMA80_Period**: インジケータと同じ設定
- **BB_Period**: 20
- **BB_Deviation**: 2.0
- **EnableTrading**: false（デモ取引の場合はfalse、本番の場合はtrue）

**ショート確認シグナル設定**
- **EMA_Divergence_Threshold**: 0.003（0.3% = 危険域）
- **CheckEMADivergence**: true（EMA乖離チェック有効）
- **CheckHighRejection**: true（高値更新否定チェック有効）
- **CheckShortTermWeakness**: true（短期足の力不足チェック有効）

**利確・損切設定**
- **UsePartialTakeProfit**: true（段階的な利確を有効化）
- **PartialTPRatio**: 1.5（1.5倍のRRで次のレベルを設定）
- **UseBTCUSDMode**: false（BTC/USDの場合はtrue。RR 1:1.5→1:2に変更）
- **UseEMA80TP**: true（EMA80をTP目標として使用）
- **UseNShapeExtension**: true（N字形成で利幅拡張を有効化）
- **SendAlerts**: true（アラート通知を有効化）

## P4 Method Rules（実装済み）

### エントリー条件

#### ロング（買い）
1. **パーフェクトオーダー確認**：
   ```
   EMA10 > EMA20 > EMA40 > EMA80
   ```

2. **エントリータイミング**：
   - 価格がボリンジャーバンド下側を上抜ける

#### ショート（売り）
1. **パーフェクトオーダー確認**：
   ```
   EMA80 > EMA40 > EMA20 > EMA10
   ```

2. **エントリータイミング**：
   - 価格がボリンジャーバンド上側を下抜ける

3. **追加ショート確認シグナル（いずれか1つ以上）**：

   **① EMA乖離率チェック（0.3%超警告）**
   - 1時間足で価格とEMA10の距離が0.3%を超えた場合は危険域
   - 相場アルゴリズム上、移動平均線の乖離は埋めやすい
   - 乖離が大きい時はシグナルをスキップ推奨

   **② 高値圏での高値更新否定**
   - 1時間足で直近の高値圏を確認
   - 逆V字に反発している箇所が高値圏
   - 高値がドンドン切り下がっている → 利確売り圧力増加
   - 高値更新失敗 → ショートの初動シグナル

   **③ 短期足の力不足（5分足パターン）**
   - アウトサイドバー（前回のローソク足を包含）が消失
   - インサイドバー（前回のローソク足に収まる）が増加
   - 高値が更新できない
   - これらが揃うと上昇の限界を示唆

### 損切・利確管理

#### 基本設定
- **損切位置**: エントリーラインの直近最安値（ロング）/最高値（ショート）
- **初期利確**: リスク・リワード 1:1

#### ボリンジャーバンド突き抜け後

**RR 1:0 → 1:1への遷移**
- 初期TP到達後、SLを建値に移動

**RR 1:1 → 1:1.5への遷移**
- BBを上抜け（ロング）/下抜け（ショート）
- SLをRR 1:1のレベルに移動
- TPをRR 1:1.5のレベルに設定

**RR 1:1.5 → 1:2への遷移**
- さらにトレンドが続く場合
- SLをRR 1:1のレベルに維持
- TPをRR 1:2のレベルに設定

### パーフェクトオーダー崩れ

パーフェクトオーダーが反転した場合は、TP/SLに到達していなくても**強制決済**します。

## バックテスト（Python）

### セットアップ

必要なライブラリのインストール：

```bash
pip install pandas numpy ta-lib
```

または

```bash
pip install pandas numpy ta
```

### 使用方法

```python
from tools.p4_backtester import P4Backtester

# Backtresterのインスタンス作成
backtester = P4Backtester("EURUSD", "15m")

# CSVデータの読み込み（datetime, open, high, low, close, volume列が必要）
backtester.load_data("data/eurusd_15m.csv")

# テクニカル指標の計算
backtester.calculate_indicators()

# バックテストの実行
stats = backtester.backtest()

# レポートの表示
backtester.print_report()

# 結果のエクスポート
backtester.export_trades("results/trades.json")
backtester.export_signals("results/signals.csv")
```

### 出力内容

バックテスト結果には以下が含まれます：

- **Total Trades**: 総トレード数
- **Win Rate**: 勝率
- **Total Profit**: 総利益
- **Max Profit/Loss**: 最大利益/損失
- **Profit Factor**: プロフィットファクター（利益合計÷損失合計）

## 【NEW】P4手法の利幅拡張機能

### ① 段階的な利確（TP段階）

**通常モード（FX通貨ペア）**
- **TP1**: RR 1:1（初期利確）
- **TP2**: RR 1:1.5（BB突き抜け後）

**BTCUSDモード**
- **TP1**: RR 1:1.5
- **TP2**: RR 1:2

段階的に利確することで、リスク管理しながら利幅を最大化できます。

### ② EMA80タッチでの利確

`UseEMA80TP = true` の場合、EMA80にタッチしたタイミングで自動的に利確します。
ただし、N字形成が検出された場合はさらに利益を伸ばします。

### ③ N字パターンの自動検出

連続するウィック（ヒゲ）が3本以上検出されると、N字形成と判断します。
このとき以下の動作をします：

- EMA80に到達してもすぐに利確せず
- さらに利益を伸ばす
- 強い上昇/下降の継続を狙う

## リアルトレードの注意点

### 重要な手動調整項目

1. **損切位置の調整**
   - 現在は固定値（±50 pips）を使用
   - エントリーライン（ヒゲの切り下がり/上がり部分）の直近最安値/最高値を手動で設定推奨
   - より正確なリスク管理が可能

2. **リスク管理**
   - ロットサイズは自動計算ですが、RiskPercentパラメータで調整
   - 初期設定は2%をお勧め

3. **シグナル確認**
   - EAのアラートとログを監視
   - パーフェクトオーダーの状態を視認で確認

### テスト手順

1. **デモアカウントでテスト**
   - EnableTrading = false でシグナルのみ確認

2. **バックテストで検証**
   - 過去6ヶ月のデータで p4_backtester.py を実行

3. **フォワードテスト**
   - デモアカウントで1ヶ月運用

4. **本番運用**
   - 小ロットサイズで開始
   - 段階的に増量

## トラブルシューティング

### EAが動作しない場合

1. ログを確認（Tools → Journal）
2. テンプレートアタッチ時に「Allow live trading」にチェック
3. 通貨ペアが設定と一致しているか確認

### シグナルが表示されない場合

1. インジケータハンドル作成エラーをチェック
2. 十分なバー数が必要（最低100本）
3. EMA期間が短すぎないか確認

### バックテスト結果が不正確な場合

1. CSVデータ形式を確認（datetime, open, high, low, close, volume）
2. データの完全性を確認（欠落カンドルがないか）
3. テクニカル指標が正しく計算されているか確認

## ファイル構成

```
Tenbai/
├── mql5/
│   ├── Indicators/
│   │   └── P4_Signal_Indicator.mq5
│   └── Experts/
│       └── P4_Signal_EA.mq5
├── tools/
│   └── p4_backtester.py
└── docs/
    └── P4_SETUP_GUIDE.md
```

## 今後の改善予定

- [ ] エントリーライン自動描画機能の追加
- [ ] N字形成検出と利幅拡張の自動化
- [ ] マルチタイムフレーム分析の実装
- [ ] リスク・リワード管理の高度化
- [ ] ストラテジーテスター統合
- [ ] アラート機能のカスタマイズ

## サポートとフィードバック

問題が発生した場合や機能リクエストがある場合は、ログを確認して詳細を記録してください。

# MT5 FX マルチフレーム分析ツール セットアップガイド

## 📱 概要

MetaTrader 5（MT5）用のFXマルチフレーム分析ツール。インジケータとEA（自動売買システム）の2つのコンポーネントから構成されます。

### 含まれるコンポーネント

1. **fx_multiframe_analyzer.mq5** - インジケータ
   - 複数タイムフレーム（4H、1D、1W）の分析を表示
   - トレンド判定、RSI、MACD表示
   - マルチタイムフレーム一致度の表示

2. **fx_signal_generator.mq5** - EA（自動売買システム）
   - マルチフレーム分析に基づいた自動トレード
   - リスク・リワード比率に基づくロット計算
   - トレーリングストップ機能
   - 自動注文管理

---

## 🚀 インストール手順

### ステップ1: ファイルを正しいディレクトリにコピー

#### Windows:
```
C:\Users\[Username]\AppData\Roaming\MetaQuotes\Terminal\[Terminal ID]\MQL5\Indicators\
  ↓
  fx_multiframe_analyzer.mq5

C:\Users\[Username]\AppData\Roaming\MetaQuotes\Terminal\[Terminal ID]\MQL5\Experts\
  ↓
  fx_signal_generator.mq5
```

#### Mac:
```
~/Library/Application Support/MetaQuotes/Terminal/[Terminal ID]/MQL5/Indicators/
  ↓
  fx_multiframe_analyzer.mq5

~/Library/Application Support/MetaQuotes/Terminal/[Terminal ID]/MQL5/Experts/
  ↓
  fx_signal_generator.mq5
```

#### Linux:
```
~/.config/MetaQuotes/Terminal/[Terminal ID]/MQL5/Indicators/
  ↓
  fx_multiframe_analyzer.mq5

~/.config/MetaQuotes/Terminal/[Terminal ID]/MQL5/Experts/
  ↓
  fx_signal_generator.mq5
```

### ステップ2: ファイルの確認

1. MT5を起動
2. 「File」→「Open Data Folder」をクリック
3. 上記ディレクトリにファイルがコピーされているか確認
4. MT5を再起動

### ステップ3: インジケータをチャートに追加

1. チャートを開く（推奨: 4時間足）
2. 「Insert」→「Indicators」→「Custom」
3. 「fx_multiframe_analyzer」を選択
4. パラメータを調整して「OK」

### ステップ4: EAをチャートに追加（自動売買する場合）

1. チャートを開く（推奨: 4時間足）
2. 「Insert」→「Expert Advisors」→「fx_signal_generator」
3. パラメータを調整
4. 「Allow Live Trading」を有効にする（重要！）
5. 「OK」をクリック

---

## ⚙️ パラメータ設定

### インジケータ設定 (fx_multiframe_analyzer.mq5)

| パラメータ | デフォルト | 説明 |
|-----------|----------|------|
| FastMALength | 9 | 短期移動平均期間 |
| SlowMALength | 21 | 長期移動平均期間 |
| MAType | MODE_SMA | 移動平均の種類（SMA/EMA/SMMA/LWMA） |
| RSILength | 14 | RSI期間 |
| RSIOverBought | 70 | RSI買われすぎ水準 |
| RSIOverSold | 30 | RSI売られすぎ水準 |
| MACDFast | 12 | MACD短期期間 |
| MACDSlow | 26 | MACD長期期間 |
| MACDSignal | 9 | MACDシグナル期間 |
| Show4HTrend | true | 4時間足トレンド表示 |
| Show1DTrend | true | 日足トレンド表示 |
| Show1WTrend | true | 週足トレンド表示 |
| ShowAlerts | true | アラート表示 |
| TextColor | clrWhite | テキスト色 |
| TextSize | 12 | テキストサイズ |

### EA設定 (fx_signal_generator.mq5)

| パラメータ | デフォルト | 説明 |
|-----------|----------|------|
| RiskPercent | 2.0 | 1トレードのリスク% |
| RiskRewardRatio | 2.0 | R:R比率（1:2推奨） |
| FastMALength | 9 | 短期MA |
| SlowMALength | 21 | 長期MA |
| MAType | MODE_SMA | MA種類 |
| RSILength | 14 | RSI期間 |
| MaxSlippage | 30 | 最大スリッページ（pips） |
| UseTrailingStop | true | トレーリングストップ使用 |
| TrailingStopDistance | 50 | トレーリングストップ幅 |
| ShowComments | true | ログ表示 |

---

## 📊 インジケータの見方

### トレンド表示

チャート左上に以下の情報が表示されます：

```
FX Multi-Timeframe Analyzer

4H: 🔼 UPTREND          ← 4時間足がアップトレンド
    RSI: 55.23         ← 4時間足RSI値
    Price: 1.0950      ← 現在の価格

1D: 🔼 UPTREND         ← 日足がアップトレンド
    RSI: 65.12         ← 日足RSI値

1W: 🔼 UPTREND         ← 週足がアップトレンド
    RSI: 72.45         ← 週足RSI値

Alignment: ✓ ALL BULLISH  ← 全タイムフレーム一致（最強気シグナル）
```

### トレンドシンボル説明

| シンボル | 意味 |
|---------|------|
| 🔼 | アップトレンド（緑色） |
| 🔽 | ダウントレンド（赤色） |
| → | レンジ相場（黄色） |

### Alignment の種類

| Alignment | 意味 | 色 |
|-----------|------|-----|
| ✓ ALL BULLISH | 全タイムフレーム強気 | 緑 |
| ✓ ALL BEARISH | 全タイムフレーム弱気 | 赤 |
| ⚠ MIXED | 混合状態 | 黄 |

---

## 🤖 EA（自動売買）の仕組み

### シグナル生成ロジック

#### 買いシグナル条件：
```
1. 日足が上昇トレンド（FastMA > SlowMA）
2. 4時間足が上昇トレンド（FastMA > SlowMA）
3. RSI < 70（買われすぎでない）
4. 追加確認: 週足も上昇トレンドなら信頼度UP
```

#### 売りシグナル条件：
```
1. 日足が下降トレンド（FastMA < SlowMA）
2. 4時間足が下降トレンド（FastMA < SlowMA）
3. RSI > 30（売られすぎでない）
4. 追加確認: 週足も下降トレンドなら信頼度UP
```

### ロット計算式

```
ロットサイズ = (口座残高 × リスク%) / (pips差 × ティックサイズ)
```

例：
- 口座残高: $10,000
- リスク: 2%
- 入場: 1.0950, SL: 1.0920 (30pips)
- ロット計算: (10,000 × 0.02) / (30 × 0.0001) = 0.66ロット

### トレーリングストップ

利益が出ている場合、自動的にストップロスを引き上げます：
- 初期SL: 入場 - 50pips
- 利益が 50pips以上の場合: 50pips分上げる
- 以後、50pips利益毎に SL も上げられる

---

## 🔧 使用例

### シナリオ1: EUR/USD で買いシグナルが発生

**状況：**
```
現在のレート: 1.0950
4時間足: FastMA=1.0920, SlowMA=1.0890 → UP
日足: FastMA=1.0900, SlowMA=1.0850 → UP
週足: FastMA=1.0800, SlowMA=1.0700 → UP
RSI 4H: 55 → 正常範囲
```

**EA の動作：**
1. ✓ マルチフレーム確認（全て買い）
2. ✓ リスク計算: 口座$10,000 × 2% / 30pips = 0.66ロット
3. ✓ 買い注文を送信
   - エントリー: 1.0950
   - ストップロス: 1.0890
   - テイクプロフィット: 1.1010 (R:R = 1:2)

**その後：**
- 価格が 1.1000 に上昇
- トレーリングストップが SL を 1.0940 に上げる
- 価格が反転して 1.0940 で決済
- 利益: 90pips × 0.66ロット = $594

---

## ⚠️ 重要な注意

### 使用前の必須確認

1. **バックテスト実施**
   - Strategy Tester で充分なバックテストを実施
   - 最低3ヶ月のデータで検証

2. **デモトレード**
   - リアルマネー使用前に必ずデモアカウントでテスト
   - 最低1ヶ月のデモ期間を推奨

3. **パラメータ最適化**
   - あなたの取引スタイルに合わせて調整
   - 推奨デフォルト値から大きく変更しない

### トレード時の注意

1. **重要な経済指標発表時は停止**
   - 高ボラティリティで予期しない損失の可能性

2. **必ずストップロスを設定**
   - サーバー障害に対する保険

3. **リスク設定は慎重に**
   - 最初は 0.5-1% のリスクから開始
   - 利益が出たら徐々に増やす

4. **常に監視**
   - 自動売買でも定期的にチェック

---

## 🆘 トラブルシューティング

### Q: インジケータが表示されない

**A:** 
1. ファイルが正しいディレクトリにあるか確認
2. MT5 を再起動
3. 「Indicators」フォルダを確認

### Q: EA が注文を送信しない

**A:**
1. 「Allow Live Trading」が有効か確認
2. ブローカーが自動売買を許可しているか確認
3. 通貨ペアが自動売買対応か確認
4. 十分な証拠金があるか確認

### Q: 過去チャートでシグナルが重複している

**A:**
これは正常です。チャートをスクロールするとシグナルが表示されます。新規バーでのみトレードします。

### Q: ログに「バッファコピーエラー」が出る

**A:**
1. インジケータが正しく計算されるまで少し待つ
2. 最低20-50本のバーが必要
3. MT5 を再起動

### Q: トレーリングストップが機能しない

**A:**
- UseTrailingStop が true に設定されているか確認
- TrailingStopDistance の値を確認
- EA が正常に動作しているか確認

---

## 📈 パフォーマンスの最適化

### バックテストの実施

1. 「View」→「Strategy Tester」
2. 「Expert Advisor」に「fx_signal_generator」を選択
3. 通貨ペア、時間足、期間を設定
4. 「Start」をクリック
5. 結果を分析

### 推奨バックテスト条件

- **期間**: 最低 1-2 年のデータ
- **時間足**: 4時間足（推奨）
- **スプレッド**: リアルな値に設定
- **最適化**: 1ヶ月毎にパラメータ調整

---

## 📚 よくある質問（FAQ）

**Q: 複数の通貨ペアで同時に動作させられますか？**
A: はい。複数チャートに EA をアタッチしてください。各チャートで独立して動作します。

**Q: ナイトタイムは停止できますか？**
A: EA にタイムフィルターを追加することで可能です（カスタマイズが必要）。

**Q: デイトレードに対応していますか？**
A: はい。時間足を短くして（1H や 15m）適用できます。パラメータを調整してください。

**Q: スプレッドが大きい場合はどうしたらいいですか？**
A: RiskRewardRatio を上げるか、RiskPercent を下げてください。

---

## 🔐 セキュリティと安全性

### パスワード保護

EA をパスワード保護する：
1. MetaEditor で EA を開く
2. 「File」→「Properties」
3. 「Additional」タブで「Protected」を有効
4. パスワードを設定

### バージョン管理

- 定期的にバージョンをバックアップ
- パラメータの変更は記録しておく

---

## 📞 サポートとアップデート

### 問題が発生した場合

1. **MT5 の ログを確認**
   - 「View」→「Toolbox」→「Experts」タブ

2. **通常のサポート**
   - MetaTrader Community フォーラム
   - ブローカーのサポート部門

---

## 版履歴

| 版 | 日付 | 内容 |
|----|------|------|
| 1.0 | 2024年1月 | 初版リリース |

---

**最終更新**: 2024年1月  
**対応バージョン**: MetaTrader 5 Build 3500+  
**テスト環境**: Windows 10/11, Mac, Linux

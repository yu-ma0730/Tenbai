# FX マルチフレーム分析ツール

## 📱 概要

このプロジェクトは、FX（外国為替）トレーディング向けの**マルチタイムフレーム分析ツール**です。  
TradingViewのPine Scriptと、PythonベースのバックエンドAPIの2つのコンポーネントから構成されています。

**主な特徴:**
- ✅ 複数タイムフレーム（週足、日足、4時間足）の同時分析
- ✅ 自動トレードシグナル生成
- ✅ リスク・リワード比率の計算
- ✅ ローソク足パターン認識
- ✅ TradingViewネイティブ統合

---

## 🛠️ 構成ファイル

### 1. **fx_multiframe_analyzer.pine** - TradingView Pine Script
TradingViewチャートで直接使用できるカスタムインジケータ

**機能:**
- マルチタイムフレームトレンド表示（4H, 1D, 1W）
- 移動平均線（SMA/EMA/WMA切り替え可）
- RSI、MACD表示
- サポート・レジスタンスレベル自動計算
- ステータステーブル表示
- 自動アラート

### 2. **fx_analyzer.py** - Python分析エンジン
マルチタイムフレーム分析を行うメインライブラリ

**主要クラス:**
- `FXMultiframeAnalyzer`: メイン分析クラス
- `HigherLowAnalyzer`: 高値安値パターン検出
- `PatternRecognition`: ローソク足パターン認識

### 3. **fx_api.py** - Flask API
Webインターフェースからのリクエスト処理

**エンドポイント:**
- `POST /api/fx/analyze` - フル分析
- `POST /api/fx/signals` - シグナルのみ
- `POST /api/fx/risk-reward` - R:R計算
- `POST /api/fx/higher-lows` - パターン検出
- `GET /api/fx/health` - ヘルスチェック

### 4. **templates/fx_analyzer.html** - Webインターフェース
ブラウザから利用できるUIダッシュボード

### 5. **FX_MULTIFRAME_GUIDE.md** - 詳細ガイド
トレード戦略と使用方法の詳細マニュアル

---

## 🚀 セットアップと使用方法

### TradingViewでの使用（Pine Script）

#### ステップ1: Pine Editorを開く
1. TradingView チャートに移動
2. 左側メニューの「Pine Editor」をクリック
3. 「+ New indicator」をクリック

#### ステップ2: スクリプトをコピー
1. このリポジトリの `fx_multiframe_analyzer.pine` ファイルの全コードをコピー
2. Pine Editorのエディタエリアにペースト
3. 「Save」をクリック

#### ステップ3: チャートに追加
1. 「Add to Chart」ボタンをクリック
2. チャート上にインジケータが表示されます
3. 設定パネルでパラメータを調整

#### ステップ4: マルチタイムフレーム確認
- 右上のテーブルで複数タイムフレームの状態を確認
- 🔼🔽→のマークでトレンド方向を確認
- 「Align」でマルチタイムフレームの一致度をチェック

### Pythonバックエンドの実行

#### 必要な環境
- Python 3.8+
- Flask
- pandas
- numpy

#### インストール
```bash
# 依存パッケージのインストール
pip install flask pandas numpy

# app.pyがすでにfx_apiをインポートしているので、そのまま実行可能
python app.py
```

#### Webインターフェースへのアクセス
```
http://localhost:5000/fx-analyzer
```

### APIの直接呼び出し

#### 1. マルチタイムフレーム分析
```bash
curl -X POST http://localhost:5000/api/fx/analyze \
  -H "Content-Type: application/json" \
  -d '{
    "symbol": "EUR/USD",
    "timeframes": ["1H", "4H", "D", "W"],
    "fast_ma": 9,
    "slow_ma": 21,
    "rsi_length": 14
  }'
```

#### 2. リスク・リワード計算
```bash
curl -X POST http://localhost:5000/api/fx/risk-reward \
  -H "Content-Type: application/json" \
  -d '{
    "entry_price": 1.0950,
    "stop_loss": 1.0920,
    "take_profit": 1.1000
  }'
```

#### 3. ヘルスチェック
```bash
curl http://localhost:5000/api/fx/health
```

---

## 📊 基本的なトレード戦略

### マルチタイムフレーム確認フロー

```
週足チェック
    ↓
日足チェック
    ↓
4時間足チェック
    ↓
エントリーシグナル確認
```

### 推奨される取引戦略

#### **強気シグナル（BUY）**
- 条件: 日足と4時間足がアップトレンド
- さらに強い: 週足もアップトレンド（信頼度 80%+）
- エントリー: サポートレベル付近
- ストップロス: 直近の安値より下
- テイクプロフィット: 直近のレジスタンス

#### **弱気シグナル（SELL）**
- 条件: 日足と4時間足がダウントレンド
- さらに強い: 週足もダウントレンド（信頼度 80%+）
- エントリー: レジスタンスレベル付近
- ストップロス: 直近の高値より上
- テイクプロフィット: 直近のサポート

### リスク管理

**必須ルール:**
1. ✅ 必ずストップロスを設定
2. ✅ リスク・リワード比率は最低1:1（推奨2:1以上）
3. ✅ 1トレードあたりのリスクは口座資金の1-2%
4. ✅ マルチタイムフレーム確認後のみエントリー

---

## 📈 技術指標の解説

### 移動平均線 (MA)
- **Fast MA (9日)**: 短期トレンド
- **Slow MA (21日)**: 中期トレンド
- **用途**: トレンド判定、サポート・レジスタンス

### RSI (Relative Strength Index)
- **0-30**: 売られすぎ（買い機会）
- **70-100**: 買われすぎ（売り機会）
- **30-70**: ニュートラル

### MACD
- **ヒストグラム > 0**: 上昇圧力
- **ヒストグラム < 0**: 下降圧力
- **ゼロクロス**: トレンド転換

---

## 🎯 使用例

### シナリオ1: EUR/USD日次トレード

1. **週足確認**
   - MA Fast (9) > MA Slow (21) → アップトレンド ✅

2. **日足確認**
   - MA Fast (9) > MA Slow (21) → アップトレンド ✅
   - RSI = 55 → ニュートラル ✅

3. **4時間足確認**
   - ゴールデンクロス検出（Fast MJ Slow MA上抜け）
   - サポート: 1.0900, レジスタンス: 1.1050
   - RSI = 45 → 上昇余地あり ✅

4. **トレード実行**
   - **エントリー**: 1.0930（サポートから10pips上）
   - **ストップロス**: 1.0900（20pips）
   - **テイクプロフィット**: 1.1050（120pips）
   - **R:R = 1:6** → 優れたシグナル ✅

### シナリオ2: GBP/USD4時間足トレード

1. **マルチタイムフレーム確認**
   - 週足: ダウントレンド (-1)
   - 日足: ダウントレンド (-1)
   - 4時間足: ダウントレンド (-1)
   - **Align: BEARISH** ⭐ 最高の売りシグナル

2. **エントリー判定**
   - 信頼度: 80%+
   - デッドクロス検出（FastMA < SlowMA）
   - RSI = 65（買われすぎ兆候）

3. **トレード実行**
   - **エントリー**: 1.3050（レジスタンス）
   - **ストップロス**: 1.3080（30pips）
   - **テイクプロフィット**: 1.2950（100pips）
   - **R:R = 1:3.3** → 良好なシグナル ✅

---

## ⚠️ 重要な注意事項

1. **シグナル保証なし**
   - 本ツールは分析補助です
   - 100%の勝率を保証しません

2. **リスク管理必須**
   - 必ずストップロスを設定
   - 損切りを守る

3. **市場状況の変化**
   - 重大なニュース発表時は慎重に
   - ボラティリティ注意

4. **練習から始める**
   - 最初は小ロットか紙取引で練習
   - リアルマネー使用前に十分なテスト

---

## 📝 ファイル構成

```
/home/user/Tenbai/
├── fx_multiframe_analyzer.pine    # TradingView Pine Script
├── fx_analyzer.py                  # Python分析エンジン
├── fx_api.py                       # Flask API
├── app.py                          # メインFlaskアプリ
├── templates/
│   ├── fx_analyzer.html           # Webダッシュボード
│   └── index.html                 # メインページ
├── FX_MULTIFRAME_GUIDE.md         # 詳細ガイド
└── README_FX.md                   # このファイル
```

---

## 🔧 カスタマイズ

### インジケータパラメータの変更

**Pine Script内:**
```pinescript
fast_ma_length = input(9, title="Fast MA Length")  // デフォルト9
slow_ma_length = input(21, title="Slow MA Length") // デフォルト21
rsi_length = input(14, title="RSI Length")         // デフォルト14
```

**Python内:**
```python
analyzer = FXMultiframeAnalyzer(
    fast_ma=9,      # 変更可能
    slow_ma=21,     # 変更可能
    rsi_length=14   # 変更可能
)
```

### トレンド判定ロジックのカスタマイズ

`fx_analyzer.py`の`_determine_trend()`メソッドを編集してカスタマイズ可能

---

## 🆘 トラブルシューティング

### Q: TradingViewでインジケータが表示されない
A: Pine Script v5の文法を確認してください。スクリプト右側のエラーを確認。

### Q: APIが応答しない
A: 
```bash
# ヘルスチェック実行
curl http://localhost:5000/api/fx/health

# Flaskアプリの再起動
python app.py
```

### Q: シグナルが出ない
A: データボリュームが足りない可能性があります（最低20-50バー必要）

---

## 📚 参考資料

- [TradingView Pine Script ドキュメント](https://www.tradingview.com/pine-script-docs/)
- [マルチタイムフレーム分析ガイド](./FX_MULTIFRAME_GUIDE.md)
- [テクニカル分析入門](https://www.investopedia.com/terms/t/technicalanalysis.asp)

---

**Version**: 1.0.0  
**最終更新**: 2024年1月  
**ライセンス**: MIT

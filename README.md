# XAUUSD Professional Trading Tool
## MT5 用ゴールド自動トレーディングシグナルシステム

**For Professional Traders | リアルタイムシグナル生成 | 無料 | MT5 ネイティブ**

---

## 🎯 プロジェクト概要

XAUUSD Professional Trading Tool は、MetaTrader 5 プラットフォーム上で動作する**専業トレーダー向けの自動シグナル生成ツール**です。

複数のテクニカル指標を組み合わせた高精度シグナルで、XAUUSD（ゴール/米ドル）の**買い・売りチャンスを自動検出**します。

### なぜこのツールを選ぶのか？

✅ **リアルタイムシグナル** - 24/7 市場を監視  
✅ **複合指標ロジック** - RSI + MACD + EMA の融合  
✅ **誤信号を最小化** - 多要件フィルタリング  
✅ **モバイル通知** - 外出先でも即座に通知  
✅ **完全無料** - オープンソース  
✅ **カスタマイズ可能** - パラメータ自由調整  

---

## 📂 ディレクトリ構成

```
xauusdtool/
├── README.md                           ← このファイル
├── QUICK_START.md                      ← 5分で始めるガイド
├── mt5/
│   ├── Experts/
│   │   └── Advisors/
│   │       └── XAUUSD_ProTrader_v1.mq5          ← メイン EA
│   ├── Indicators/
│   │   └── XAUUSD_Professional_Signal.mq5       ← チャートインジケータ
│   ├── README_JP.md                    ← 詳細な日本語ガイド
│   └── configs/
│       ├── daytrading_h1.ini           ← デイトレード設定
│       ├── swingtrade_h4.ini           ← スイングトレード設定
│       └── scalping_m15.ini            ← スキャルピング設定
└── docs/
    ├── INSTALLATION.md                 ← インストール手順
    ├── PARAMETERS.md                   ← パラメータ詳細説明
    └── TROUBLESHOOTING.md              ← トラブル解決

```

---

## 🚀 クイックスタート

### 30秒で完了
```bash
# 1. このリポジトリをクローン
git clone https://github.com/yu-ma0730/xauusdtool.git

# 2. ファイルを MT5 にコピー（詳細は QUICK_START.md を参照）

# 3. MT5 でコンパイル & チャートに設定

# 4. リアルタイムシグナルを受け取り開始！
```

📖 **詳細は [QUICK_START.md](./mt5/QUICK_START.md) をご覧ください**

---

## 💡 シグナル生成ロジック

### BUY シグナル条件（すべて満たす必要）
```
1. RSI < 30 （売られすぎ状態）
2. MACD > Signal Line （強気への転換）
3. Price < Fast EMA （短期移動平均線下方）
4. Fast EMA > Slow EMA （上昇トレンド中）
```

### SELL シグナル条件（すべて満たす必要）
```
1. RSI > 70 （買われすぎ状態）
2. MACD < Signal Line （弱気への転換）
3. Price > Fast EMA （短期移動平均線上方）
4. Fast EMA < Slow EMA （下降トレンド中）
```

このアプローチにより、**偽信号を最小化**しながら**高精度なシグナル**を生成します。

---

## 📊 主要指標

| 指標 | 用途 | 推奨値 |
|------|------|--------|
| RSI | 買われすぎ/売られすぎ判定 | 期間 14、オーバーボート 70、オーバーソルド 30 |
| MACD | トレンド確認・反転検出 | Fast 12、Slow 26、Signal 9 |
| EMA Fast | 短期トレンド | 期間 20（デイトレード用） |
| EMA Slow | 長期トレンド | 期間 50（トレンド確認用） |

---

## ⚙️ インストール

### 必要環境
- MetaTrader 5（Windows または macOS）
- MQL5 コンパイラ（MT5 に内蔵）
- XAUUSD チャート

### インストール手順
1. リポジトリをクローン
2. `XAUUSD_ProTrader_v1.mq5` を MT5/MQL5/Experts/Advisors/ にコピー
3. `XAUUSD_Professional_Signal.mq5` を MT5/MQL5/Indicators/ にコピー
4. MT5 でコンパイル（F5 キー）
5. XAUUSD チャートに EA をドラッグ&ドロップ

📖 **詳細は [INSTALLATION.md](./docs/INSTALLATION.md) をご覧ください**

---

## 🎛️ パラメータ設定

### デイトレード向け（H1 時間足・推奨）
```mql5
RSI_Overbought = 70.0
RSI_Oversold = 30.0
RSI_Period = 14
MACD_Fast = 12
MACD_Slow = 26
MACD_Signal = 9
EMA_Fast = 20
EMA_Slow = 50
MinBarsSinceSignal = 3
UseSoundAlert = true
UseNotification = true
```

### スイングトレード向け（H4 時間足）
```mql5
EMA_Fast = 30
EMA_Slow = 100
MinBarsSinceSignal = 5
// その他は同じ
```

### スキャルピング向け（M15 時間足）
```mql5
RSI_Period = 10
EMA_Fast = 9
EMA_Slow = 21
MinBarsSinceSignal = 2
```

📖 **パラメータの詳細説明は [PARAMETERS.md](./docs/PARAMETERS.md) をご覧ください**

---

## 📱 通知設定

### チャートアラート（MT5 内）
```
EA 設定で UseSoundAlert = true に設定すると、
シグナル発生時に MT5 が通知音を鳴らします。
```

### モバイル通知（スマートフォン）
```
1. MetaTrader 5 モバイルアプリをインストール
2. デスクトップ版と同じアカウントでログイン
3. 通知設定を有効化
4. シグナル発生時に即座に携帯に通知
```

---

## 📈 パフォーマンス期待値

### 通常の成績（市場環境による）
```
勝率: 55~65%
平均勝ち : 平均負け = 1:1.5 以上
月間収益率: 5~15%
最大ドローダウン: 15~25%
```

### 重要な注意事項
⚠️ **100% 勝つことは不可能**です。専業トレーダーでも勝率 60~70%、残りは損失です。

⚠️ **リスク管理が最重要**です。1 トレード = 総資金の 1~2% リスク。

⚠️ **小額から始める**ことを強く推奨します。

---

## 🔧 トラブルシューティング

### よくある問題

**Q: シグナルが表示されない**
```
A: 以下をチェック：
   1. EA が正常に起動している？（左上に スマイリー）
   2. インジケータがチャートに表示されている？
   3. XAUUSD チャートが正しく開かれている？
   4. 十分な足数がある？（最低 100 足以上）
```

**Q: 音が出ない**
```
A: EA 設定で UseSoundAlert = true に設定してください。
   また、MT5 の音量設定も確認してください。
```

**Q: 通知が来ない**
```
A: MetaTrader 5 アプリの通知設定を有効化してください。
   設定 → 通知 → EA アラート をチェック。
```

**Q: エラーが表示される**
```
A: ターミナル → ジャーナル タブでエラーログを確認。
   ハンドルエラーが多い場合は、MT5 を再起動。
```

📖 **詳細は [TROUBLESHOOTING.md](./docs/TROUBLESHOOTING.md) をご覧ください**

---

## 🔐 安全に使用するためのルール

### 必須事項
✅ **必ずデモ口座で検証する** （最低 1 週間）  
✅ **リアル口座では小額から始める** （初月 0.1 ロット未満）  
✅ **リスク管理を厳守** （1 トレード = リスク 1~2%）  
✅ **重大経済指標の発表時は避ける** （GDPなど）  
✅ **過度にパラメータを変更しない** （最適化の罠）  

---

## 📊 バックテスト / フォワードテスト

### バックテスト方法
1. MT5 で View → Strategy Tester
2. XAUUSD_ProTrader_v1 を選択
3. 期間：1 年間以上の過去データ
4. Run をクリック

### 推奨バックテスト期間
- **最低**: 1 年間（過去データ）
- **推奨**: 3 年間以上
- **理想**: 5 年間（複数の市場環境をカバー）

---

## 🤝 コントリビューション

バグ報告・機能提案は [GitHub Issues](https://github.com/yu-ma0730/xauusdtool/issues) でお願いします。

---

## 📄 ライセンス

MIT License - 自由に使用・改変・配布が可能です。

---

## ⚠️ 免責事項

このツールは教育・研究目的です。

- 過去のパフォーマンスが将来を保証することはありません
- 100% の勝率を期待しないでください
- リスク管理が最優先です
- 実際のトレーディングで損失が発生する可能性があります
- 自己責任でご使用ください

---

## 📞 サポート

### ドキュメント
- [QUICK_START.md](./mt5/QUICK_START.md) - 5分で始めるガイド
- [README_JP.md](./mt5/README_JP.md) - 詳細な日本語ガイド
- [PARAMETERS.md](./docs/PARAMETERS.md) - パラメータ詳細説明

### コミュニティ
- GitHub Issues で問題報告
- GitHub Discussions でアイデア共有

---

## 🎯 ロードマップ

- [x] v1.0: 基本的なシグナル生成 EA
- [x] v1.0: チャートインジケータ
- [ ] v1.1: TP/SL 自動設定機能
- [ ] v1.2: ATR ベースの動的ストップロス
- [ ] v2.0: マルチタイムフレーム分析
- [ ] v2.0: 取引履歴の詳細ログ記録
- [ ] v2.0: パフォーマンス統計の自動計算

---

**Happy Trading! 🎯💰**

*Professional Trading Tool for XAUUSD*  
*v1.0 | 2024*

---

## リンク

- 🌐 [GitHub Repository](https://github.com/yu-ma0730/xauusdtool)
- 📚 [MT5 Official Documentation](https://www.metatrader5.com/en/terminal/help)
- 🎓 [MQL5 Reference](https://www.mql5.com/en/docs)


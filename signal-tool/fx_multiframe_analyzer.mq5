//+------------------------------------------------------------------+
//| FX Multi-Timeframe Analyzer for MetaTrader 5                     |
//| マルチタイムフレーム FX 分析インジケータ                          |
//+------------------------------------------------------------------+

#property copyright "FX Multiframe Analyzer"
#property link      "https://tradingview.com"
#property version   "1.00"
#property strict
#property indicator_chart_window

// ===== インジケータの表示設定 =====
#property indicator_buffers 0
#property indicator_plots   0

// ===== 入力パラメータ =====
input int FastMALength = 9;          // 短期移動平均期間
input int SlowMALength = 21;         // 長期移動平均期間
input ENUM_MA_METHOD MAType = MODE_SMA;  // 移動平均の種類
input int RSILength = 14;            // RSI期間
input int RSIOverBought = 70;        // RSI買われすぎ水準
input int RSIOverSold = 30;          // RSI売られすぎ水準
input int MACDFast = 12;             // MACD短期期間
input int MACDSlow = 26;             // MACD長期期間
input int MACDSignal = 9;            // MACDシグナル期間

// ===== 表示設定 =====
input bool Show4HTrend = true;       // 4時間足トレンド表示
input bool Show1DTrend = true;       // 日足トレンド表示
input bool Show1WTrend = true;       // 週足トレンド表示
input bool ShowAlerts = true;        // アラート表示
input color TextColor = clrWhite;    // テキスト色
input int TextSize = 12;             // テキストサイズ

// ===== グローバル変数 =====
int handleMA_4H_Fast, handleMA_4H_Slow, handleRSI_4H;
int handleMA_1D_Fast, handleMA_1D_Slow, handleRSI_1D;
int handleMA_1W_Fast, handleMA_1W_Slow, handleRSI_1W;
int handleMACD_4H;

double buffer_4H_Fast[], buffer_4H_Slow[], buffer_RSI_4H[];
double buffer_1D_Fast[], buffer_1D_Slow[], buffer_RSI_1D[];
double buffer_1W_Fast[], buffer_1W_Slow[], buffer_RSI_1W[];
double bufferMACD_Main[], bufferMACD_Signal[], bufferMACD_Hist[];

//+------------------------------------------------------------------+
//| OnInit()                                                          |
//+------------------------------------------------------------------+
int OnInit()
{
    // 4時間足インジケータハンドル取得
    handleMA_4H_Fast = iMA(_Symbol, PERIOD_H4, FastMALength, 0, MAType, PRICE_CLOSE);
    handleMA_4H_Slow = iMA(_Symbol, PERIOD_H4, SlowMALength, 0, MAType, PRICE_CLOSE);
    handleRSI_4H = iRSI(_Symbol, PERIOD_H4, RSILength, PRICE_CLOSE);

    // 日足インジケータハンドル取得
    handleMA_1D_Fast = iMA(_Symbol, PERIOD_D1, FastMALength, 0, MAType, PRICE_CLOSE);
    handleMA_1D_Slow = iMA(_Symbol, PERIOD_D1, SlowMALength, 0, MAType, PRICE_CLOSE);
    handleRSI_1D = iRSI(_Symbol, PERIOD_D1, RSILength, PRICE_CLOSE);

    // 週足インジケータハンドル取得
    handleMA_1W_Fast = iMA(_Symbol, PERIOD_W1, FastMALength, 0, MAType, PRICE_CLOSE);
    handleMA_1W_Slow = iMA(_Symbol, PERIOD_W1, SlowMALength, 0, MAType, PRICE_CLOSE);
    handleRSI_1W = iRSI(_Symbol, PERIOD_W1, RSILength, PRICE_CLOSE);

    // MACD取得（4時間足）
    handleMACD_4H = iMACD(_Symbol, PERIOD_H4, MACDFast, MACDSlow, MACDSignal, PRICE_CLOSE);

    // ハンドル検証
    if(handleMA_4H_Fast == INVALID_HANDLE || handleMA_4H_Slow == INVALID_HANDLE ||
       handleRSI_4H == INVALID_HANDLE || handleMA_1D_Fast == INVALID_HANDLE ||
       handleMA_1D_Slow == INVALID_HANDLE || handleRSI_1D == INVALID_HANDLE ||
       handleMA_1W_Fast == INVALID_HANDLE || handleMA_1W_Slow == INVALID_HANDLE ||
       handleRSI_1W == INVALID_HANDLE || handleMACD_4H == INVALID_HANDLE)
    {
        Alert("インジケータハンドルの取得に失敗しました");
        return(INIT_FAILED);
    }

    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| OnDeinit()                                                        |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // ハンドルのリリース
    ReleasedIndicators();
}

//+------------------------------------------------------------------+
//| OnCalculate()                                                     |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total, const int prev_calculated,
                const datetime &time[], const double &open[],
                const double &high[], const double &low[],
                const double &close[], const long &tick_volume[],
                const long &volume[], const int &spread[])
{
    if(rates_total < SlowMALength + RSILength)
        return(0);

    // データの取得
    CopyBuffer(handleMA_4H_Fast, 0, 0, 1, buffer_4H_Fast);
    CopyBuffer(handleMA_4H_Slow, 0, 0, 1, buffer_4H_Slow);
    CopyBuffer(handleRSI_4H, 0, 0, 1, buffer_RSI_4H);

    CopyBuffer(handleMA_1D_Fast, 0, 0, 1, buffer_1D_Fast);
    CopyBuffer(handleMA_1D_Slow, 0, 0, 1, buffer_1D_Slow);
    CopyBuffer(handleRSI_1D, 0, 0, 1, buffer_RSI_1D);

    CopyBuffer(handleMA_1W_Fast, 0, 0, 1, buffer_1W_Fast);
    CopyBuffer(handleMA_1W_Slow, 0, 0, 1, buffer_1W_Slow);
    CopyBuffer(handleRSI_1W, 0, 0, 1, buffer_RSI_1W);

    CopyBuffer(handleMACD_4H, 0, 0, 1, bufferMACD_Main);
    CopyBuffer(handleMACD_4H, 1, 0, 1, bufferMACD_Signal);
    CopyBuffer(handleMACD_4H, 2, 0, 1, bufferMACD_Hist);

    // トレンド判定
    int trend_4H = DetermineTrend(buffer_4H_Fast[0], buffer_4H_Slow[0], high[0], low[0]);
    int trend_1D = DetermineTrend(buffer_1D_Fast[0], buffer_1D_Slow[0], high[0], low[0]);
    int trend_1W = DetermineTrend(buffer_1W_Fast[0], buffer_1W_Slow[0], high[0], low[0]);

    // チャートに情報を描画
    DrawAnalysisInfo(close[0], trend_4H, trend_1D, trend_1W,
                     buffer_4H_Fast[0], buffer_4H_Slow[0], buffer_RSI_4H[0],
                     buffer_1D_Fast[0], buffer_1D_Slow[0], buffer_RSI_1D[0],
                     buffer_1W_Fast[0], buffer_1W_Slow[0], buffer_RSI_1W[0]);

    // アラート判定
    if(ShowAlerts)
    {
        CheckSignals(trend_4H, trend_1D, trend_1W, buffer_RSI_4H[0], bufferMACD_Hist[0]);
    }

    return(rates_total);
}

//+------------------------------------------------------------------+
//| DetermineTrend() - トレンド判定                                  |
//+------------------------------------------------------------------+
int DetermineTrend(double ma_fast, double ma_slow, double high, double low)
{
    if(ma_fast > ma_slow && high > ma_slow)
        return(1);  // アップトレンド
    else if(ma_fast < ma_slow && low < ma_slow)
        return(-1); // ダウントレンド
    else
        return(0);  // レンジ
}

//+------------------------------------------------------------------+
//| DrawAnalysisInfo() - 分析情報を描画                              |
//+------------------------------------------------------------------+
void DrawAnalysisInfo(double price,
                      int trend_4H, int trend_1D, int trend_1W,
                      double ma_4H_fast, double ma_4H_slow, double rsi_4H,
                      double ma_1D_fast, double ma_1D_slow, double rsi_1D,
                      double ma_1W_fast, double ma_1W_slow, double rsi_1W)
{
    // 古いテキストを削除
    ObjectsDeleteAll(0, OBJ_TEXT, 0);

    // タイトル
    DrawText("TITLE", "FX Multi-Timeframe Analyzer", 20, 20, TextColor, TextSize + 2);

    int yPos = 60;

    // 4時間足
    if(Show4HTrend)
    {
        string trend_txt_4H = (trend_4H > 0) ? "🔼 UPTREND" : (trend_4H < 0) ? "🔽 DOWNTREND" : "→ RANGE";
        color trend_color_4H = (trend_4H > 0) ? clrGreen : (trend_4H < 0) ? clrRed : clrYellow;

        DrawText("TF_4H", "4H: " + trend_txt_4H, 20, yPos, trend_color_4H, TextSize);
        DrawText("RSI_4H", "    RSI: " + DoubleToString(rsi_4H, 2), 20, yPos + 25, TextColor, TextSize - 1);
        DrawText("PRICE_4H", "    Price: " + DoubleToString(price, _Digits), 20, yPos + 45, TextColor, TextSize - 1);
        yPos += 80;
    }

    // 日足
    if(Show1DTrend)
    {
        string trend_txt_1D = (trend_1D > 0) ? "🔼 UPTREND" : (trend_1D < 0) ? "🔽 DOWNTREND" : "→ RANGE";
        color trend_color_1D = (trend_1D > 0) ? clrGreen : (trend_1D < 0) ? clrRed : clrYellow;

        DrawText("TF_1D", "1D: " + trend_txt_1D, 20, yPos, trend_color_1D, TextSize);
        DrawText("RSI_1D", "    RSI: " + DoubleToString(rsi_1D, 2), 20, yPos + 25, TextColor, TextSize - 1);
        yPos += 60;
    }

    // 週足
    if(Show1WTrend)
    {
        string trend_txt_1W = (trend_1W > 0) ? "🔼 UPTREND" : (trend_1W < 0) ? "🔽 DOWNTREND" : "→ RANGE";
        color trend_color_1W = (trend_1W > 0) ? clrGreen : (trend_1W < 0) ? clrRed : clrYellow;

        DrawText("TF_1W", "1W: " + trend_txt_1W, 20, yPos, trend_color_1W, TextSize);
        DrawText("RSI_1W", "    RSI: " + DoubleToString(rsi_1W, 2), 20, yPos + 25, TextColor, TextSize - 1);
        yPos += 60;
    }

    // マルチタイムフレーム確認
    int alignment = 0;
    if(trend_4H > 0 && trend_1D > 0 && trend_1W > 0)
        alignment = 1;  // 全て買い
    else if(trend_4H < 0 && trend_1D < 0 && trend_1W < 0)
        alignment = -1; // 全て売り

    string align_txt;
    color align_color;
    if(alignment > 0)
    {
        align_txt = "✓ ALL BULLISH";
        align_color = clrGreen;
    }
    else if(alignment < 0)
    {
        align_txt = "✓ ALL BEARISH";
        align_color = clrRed;
    }
    else
    {
        align_txt = "⚠ MIXED";
        align_color = clrOrange;
    }

    DrawText("ALIGN", "Alignment: " + align_txt, 20, yPos + 20, align_color, TextSize);
}

//+------------------------------------------------------------------+
//| DrawText() - テキスト描画ヘルパー関数                            |
//+------------------------------------------------------------------+
void DrawText(string name, string text, int x, int y, color textcolor, int size)
{
    if(ObjectFind(0, name) >= 0)
        ObjectDelete(0, name);

    ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
    ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
    ObjectSetString(0, name, OBJPROP_TEXT, text);
    ObjectSetInteger(0, name, OBJPROP_COLOR, textcolor);
    ObjectSetInteger(0, name, OBJPROP_FONTSIZE, size);
    ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}

//+------------------------------------------------------------------+
//| CheckSignals() - シグナル判定                                    |
//+------------------------------------------------------------------+
void CheckSignals(int trend_4H, int trend_1D, int trend_1W, double rsi_4H, double macd_hist)
{
    static int prev_trend_4H = 0;

    // トレンド転換検知
    if(prev_trend_4H != trend_4H)
    {
        if(trend_4H > 0 && trend_1D > 0)
        {
            Alert(_Symbol, " 4時間足: ゴールデンクロス発生！買いシグナル");
        }
        else if(trend_4H < 0 && trend_1D < 0)
        {
            Alert(_Symbol, " 4時間足: デッドクロス発生！売りシグナル");
        }

        prev_trend_4H = trend_4H;
    }

    // マルチタイムフレーム確認（全て一致）
    if(trend_4H > 0 && trend_1D > 0 && trend_1W > 0)
    {
        Alert(_Symbol, " ⭐ STRONG BUY: 全タイムフレーム強気状態！");
    }
    else if(trend_4H < 0 && trend_1D < 0 && trend_1W < 0)
    {
        Alert(_Symbol, " ⭐ STRONG SELL: 全タイムフレーム弱気状態！");
    }
}

//+------------------------------------------------------------------+
//| ReleasedIndicators() - インジケータハンドルリリース             |
//+------------------------------------------------------------------+
void ReleasedIndicators()
{
    IndicatorRelease(handleMA_4H_Fast);
    IndicatorRelease(handleMA_4H_Slow);
    IndicatorRelease(handleRSI_4H);
    IndicatorRelease(handleMA_1D_Fast);
    IndicatorRelease(handleMA_1D_Slow);
    IndicatorRelease(handleRSI_1D);
    IndicatorRelease(handleMA_1W_Fast);
    IndicatorRelease(handleMA_1W_Slow);
    IndicatorRelease(handleRSI_1W);
    IndicatorRelease(handleMACD_4H);
}
//+------------------------------------------------------------------+

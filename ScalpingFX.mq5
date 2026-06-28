//+------------------------------------------------------------------+
//|  Scalping FX Signal Indicator                                    |
//|  EMA(9/21)クロス + RSI(14) | RR 1:1.5 / 1:2.0                 |
//|  対応: USD/JPY, EUR/USD, EUR/JPY, GOLD (XAU/USD)               |
//+------------------------------------------------------------------+
#property copyright "Scalping FX"
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 2
#property indicator_plots   2

// 買いシグナル（青矢印）
#property indicator_label1  "Buy Signal"
#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrDodgerBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  3

// 売りシグナル（赤矢印）
#property indicator_label2  "Sell Signal"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrRed
#property indicator_style2  STYLE_SOLID
#property indicator_width2  3

//--- 入力パラメータ
input group    "=== EMA設定 ==="
input int      EMA_Fast     = 9;      // EMA 短期
input int      EMA_Slow     = 21;     // EMA 長期

input group    "=== RSI設定 ==="
input int      RSI_Period   = 14;     // RSI 期間
input double   RSI_Upper    = 65.0;   // RSI 上限（これ以上は買い過熱）
input double   RSI_Lower    = 35.0;   // RSI 下限（これ以下は売り過熱）

input group    "=== リスクリワード設定 ==="
input double   SL_Pips      = 8.0;    // ストップロス（pips）
input double   RR_TP1       = 1.5;    // TP1のRR比率
input double   RR_TP2       = 2.0;    // TP2のRR比率

input group    "=== 表示設定 ==="
input bool     ShowRRLines  = true;   // RRラインを表示する
input bool     ShowLabel    = true;   // ラベルを表示する
input color    BuyColor     = clrDodgerBlue; // 買い色
input color    SellColor    = clrRed;        // 売り色

input group    "=== アラート設定 ==="
input bool     AlertOn      = true;   // アラートを鳴らす
input bool     PushNotify   = false;  // スマホ通知（MT5モバイル連携）

//--- バッファ
double BuyBuffer[];
double SellBuffer[];

//--- ハンドル
int ema_fast_handle;
int ema_slow_handle;
int rsi_handle;

string OBJ_PREFIX = "ScalpFX_";

//+------------------------------------------------------------------+
int OnInit()
{
    // バッファ設定
    SetIndexBuffer(0, BuyBuffer,  INDICATOR_DATA);
    SetIndexBuffer(1, SellBuffer, INDICATOR_DATA);

    // 矢印コード（241=↑ 242=↓）
    PlotIndexSetInteger(0, PLOT_ARROW, 241);
    PlotIndexSetInteger(1, PLOT_ARROW, 242);

    // 空値
    PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, 0.0);
    PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, 0.0);

    // 矢印の上下オフセット
    PlotIndexSetInteger(0, PLOT_ARROW_SHIFT,  12);
    PlotIndexSetInteger(1, PLOT_ARROW_SHIFT, -12);

    // インジケーター初期化
    ema_fast_handle = iMA(_Symbol, PERIOD_CURRENT, EMA_Fast,   0, MODE_EMA, PRICE_CLOSE);
    ema_slow_handle = iMA(_Symbol, PERIOD_CURRENT, EMA_Slow,   0, MODE_EMA, PRICE_CLOSE);
    rsi_handle      = iRSI(_Symbol, PERIOD_CURRENT, RSI_Period, PRICE_CLOSE);

    if(ema_fast_handle == INVALID_HANDLE ||
       ema_slow_handle == INVALID_HANDLE ||
       rsi_handle      == INVALID_HANDLE)
    {
        Print("インジケーターの初期化に失敗しました");
        return INIT_FAILED;
    }

    // タイトル
    IndicatorSetString(INDICATOR_SHORTNAME,
        StringFormat("ScalpingFX EMA(%d,%d) RSI(%d) RR1:%.1f/1:%.1f",
        EMA_Fast, EMA_Slow, RSI_Period, RR_TP1, RR_TP2));

    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double   &open[],
                const double   &high[],
                const double   &low[],
                const double   &close[],
                const long     &tick_volume[],
                const long     &volume[],
                const int      &spread[])
{
    if(rates_total < EMA_Slow + RSI_Period + 5)
        return 0;

    // データ取得
    double ema_fast[], ema_slow[], rsi[];
    ArraySetAsSeries(ema_fast, true);
    ArraySetAsSeries(ema_slow, true);
    ArraySetAsSeries(rsi,      true);
    ArraySetAsSeries(BuyBuffer,  true);
    ArraySetAsSeries(SellBuffer, true);
    ArraySetAsSeries(high, true);
    ArraySetAsSeries(low,  true);
    ArraySetAsSeries(close, true);
    ArraySetAsSeries(time,  true);

    if(CopyBuffer(ema_fast_handle, 0, 0, rates_total, ema_fast) <= 0) return 0;
    if(CopyBuffer(ema_slow_handle, 0, 0, rates_total, ema_slow) <= 0) return 0;
    if(CopyBuffer(rsi_handle,      0, 0, rates_total, rsi)      <= 0) return 0;

    // 計算開始バー
    int start = (prev_calculated <= 1) ? rates_total - 2 : 1;

    for(int i = start; i >= 1; i--)
    {
        BuyBuffer[i]  = 0.0;
        SellBuffer[i] = 0.0;

        // EMAクロス判定
        bool bull_cross = (ema_fast[i+1] <= ema_slow[i+1]) && (ema_fast[i] > ema_slow[i]);
        bool bear_cross = (ema_fast[i+1] >= ema_slow[i+1]) && (ema_fast[i] < ema_slow[i]);

        // pip幅（JPY系は0.01、他は0.0001）
        double pip = (_Digits == 3 || _Digits == 5) ? _Point * 10 : _Point;
        // GOLD対応
        if(_Symbol == "XAUUSD" || _Symbol == "XAUUSDm") pip = 0.1;
        double sl_dist = SL_Pips * pip;

        // 買いシグナル
        if(bull_cross && rsi[i] > RSI_Lower && rsi[i] < RSI_Upper)
        {
            BuyBuffer[i] = low[i] - sl_dist * 0.3;

            // 最新足のみRRライン描画とアラート
            if(i == 1)
            {
                if(ShowRRLines)
                    DrawRRLines(close[i], sl_dist, true, time[i]);

                if(AlertOn && prev_calculated > 0)
                {
                    string msg = StringFormat("【BUY】%s  Entry:%.%df  SL:%.%df  TP1:%.%df  TP2:%.%df",
                        _Symbol, _Digits, close[i],
                        _Digits, close[i] - sl_dist,
                        _Digits, close[i] + sl_dist * RR_TP1,
                        _Digits, close[i] + sl_dist * RR_TP2);
                    Alert(msg);
                    if(PushNotify) SendNotification(msg);
                }
            }
        }

        // 売りシグナル
        if(bear_cross && rsi[i] > RSI_Lower && rsi[i] < RSI_Upper)
        {
            SellBuffer[i] = high[i] + sl_dist * 0.3;

            if(i == 1)
            {
                if(ShowRRLines)
                    DrawRRLines(close[i], sl_dist, false, time[i]);

                if(AlertOn && prev_calculated > 0)
                {
                    string msg = StringFormat("【SELL】%s  Entry:%.%df  SL:%.%df  TP1:%.%df  TP2:%.%df",
                        _Symbol, _Digits, close[i],
                        _Digits, close[i] + sl_dist,
                        _Digits, close[i] - sl_dist * RR_TP1,
                        _Digits, close[i] - sl_dist * RR_TP2);
                    Alert(msg);
                    if(PushNotify) SendNotification(msg);
                }
            }
        }
    }

    return rates_total;
}

//+------------------------------------------------------------------+
//| RRライン（Entry / SL / TP1 / TP2）を描画                        |
//+------------------------------------------------------------------+
void DrawRRLines(double entry, double sl_dist, bool is_buy, datetime sig_time)
{
    // 古いラインを削除
    ObjectsDeleteAll(0, OBJ_PREFIX);

    double sl  = is_buy ? entry - sl_dist           : entry + sl_dist;
    double tp1 = is_buy ? entry + sl_dist * RR_TP1  : entry - sl_dist * RR_TP1;
    double tp2 = is_buy ? entry + sl_dist * RR_TP2  : entry - sl_dist * RR_TP2;

    // ラインを描画
    CreateHLine(OBJ_PREFIX + "Entry", entry, clrWhite,            STYLE_SOLID, 2,
                "ENTRY: "                   + DoubleToString(entry, _Digits));
    CreateHLine(OBJ_PREFIX + "SL",    sl,    clrOrangeRed,        STYLE_DASH,  1,
                "SL (損切): "              + DoubleToString(sl, _Digits));
    CreateHLine(OBJ_PREFIX + "TP1",   tp1,   clrMediumSpringGreen,STYLE_DASH,  1,
                "TP1  RR1:" + DoubleToString(RR_TP1,1) + "  " + DoubleToString(tp1, _Digits));
    CreateHLine(OBJ_PREFIX + "TP2",   tp2,   clrLime,             STYLE_DASH,  1,
                "TP2  RR1:" + DoubleToString(RR_TP2,1) + "  " + DoubleToString(tp2, _Digits));

    // ラベル表示
    if(ShowLabel)
    {
        string dir   = is_buy ? "▲ BUY" : "▼ SELL";
        color  dclr  = is_buy ? BuyColor : SellColor;
        CreateLabel(OBJ_PREFIX + "SignalLabel",
                    StringFormat("%s  SL:%.%df  TP1:%.%df  TP2:%.%df",
                        dir, _Digits, sl, _Digits, tp1, _Digits, tp2),
                    sig_time, tp2, dclr);
    }

    ChartRedraw();
}

//+------------------------------------------------------------------+
void CreateHLine(string name, double price, color clr,
                 ENUM_LINE_STYLE style, int width, string tooltip)
{
    if(ObjectFind(0, name) >= 0) ObjectDelete(0, name);
    ObjectCreate(0, name, OBJ_HLINE, 0, 0, price);
    ObjectSetInteger(0, name, OBJPROP_COLOR,      clr);
    ObjectSetInteger(0, name, OBJPROP_STYLE,      style);
    ObjectSetInteger(0, name, OBJPROP_WIDTH,      width);
    ObjectSetString (0, name, OBJPROP_TOOLTIP,    tooltip);
    ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, name, OBJPROP_HIDDEN,     true);
}

//+------------------------------------------------------------------+
void CreateLabel(string name, string text, datetime dt, double price, color clr)
{
    if(ObjectFind(0, name) >= 0) ObjectDelete(0, name);
    ObjectCreate(0, name, OBJ_TEXT, 0, dt, price);
    ObjectSetString (0, name, OBJPROP_TEXT,      text);
    ObjectSetInteger(0, name, OBJPROP_COLOR,     clr);
    ObjectSetInteger(0, name, OBJPROP_FONTSIZE,  10);
    ObjectSetInteger(0, name, OBJPROP_SELECTABLE,false);
    ObjectSetInteger(0, name, OBJPROP_HIDDEN,    true);
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    ObjectsDeleteAll(0, OBJ_PREFIX);
    IndicatorRelease(ema_fast_handle);
    IndicatorRelease(ema_slow_handle);
    IndicatorRelease(rsi_handle);
}
//+------------------------------------------------------------------+

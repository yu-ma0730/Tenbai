//+------------------------------------------------------------------+
//|  Scalping FX Signal Indicator  v2.0                             |
//|  EMA(9/21)クロス + RSI(14) + BB + 上位足フィルター + 時間帯    |
//|  対応: USD/JPY, EUR/USD, EUR/JPY, GOLD (XAU/USD)               |
//+------------------------------------------------------------------+
#property copyright "Scalping FX"
#property version   "2.00"
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
input int      EMA_Fast        = 9;       // EMA 短期
input int      EMA_Slow        = 21;      // EMA 長期

input group    "=== 上位足トレンドフィルター (A) ==="
input bool     UseHTF          = true;    // 上位足フィルターを使う
input ENUM_TIMEFRAMES HTF      = PERIOD_M15; // 上位足（15分推奨）

input group    "=== RSI設定 ==="
input int      RSI_Period      = 14;      // RSI 期間
input double   RSI_Upper       = 65.0;    // RSI 上限
input double   RSI_Lower       = 35.0;    // RSI 下限

input group    "=== ボリンジャーバンド設定 (B) ==="
input bool     UseBB           = true;    // BBフィルターを使う
input int      BB_Period       = 20;      // BB 期間
input double   BB_Dev          = 2.0;     // BB 偏差
// バンド内シグナルを除外し、バンド付近のみ採用

input group    "=== 時間帯フィルター (C) ==="
input bool     UseTimeFilter   = true;    // 時間帯フィルターを使う
input int      Session1_Start  = 7;       // セッション1 開始（東京）
input int      Session1_End    = 10;      // セッション1 終了（東京）
input int      Session2_Start  = 15;      // セッション2 開始（ロンドン）
input int      Session2_End    = 24;      // セッション2 終了（NY）

input group    "=== リスクリワード設定 ==="
input double   SL_Pips         = 8.0;    // ストップロス（pips）
input double   RR_TP1          = 1.5;    // TP1のRR比率
input double   RR_TP2          = 2.0;    // TP2のRR比率

input group    "=== 表示設定 ==="
input bool     ShowRRLines     = true;   // RRラインを表示する
input bool     ShowLabel       = true;   // ラベルを表示する
input bool     ShowFilterInfo  = true;   // フィルター状態を表示する
input color    BuyColor        = clrDodgerBlue;
input color    SellColor       = clrRed;

input group    "=== アラート設定 ==="
input bool     AlertOn         = true;   // アラートを鳴らす
input bool     PushNotify      = false;  // スマホ通知

//--- バッファ
double BuyBuffer[];
double SellBuffer[];

//--- ハンドル
int ema_fast_handle;
int ema_slow_handle;
int rsi_handle;
int bb_handle;
int htf_ema_fast_handle;
int htf_ema_slow_handle;

string OBJ_PREFIX = "ScalpFX_";

//+------------------------------------------------------------------+
int OnInit()
{
    SetIndexBuffer(0, BuyBuffer,  INDICATOR_DATA);
    SetIndexBuffer(1, SellBuffer, INDICATOR_DATA);

    PlotIndexSetInteger(0, PLOT_ARROW, 241);
    PlotIndexSetInteger(1, PLOT_ARROW, 242);
    PlotIndexSetDouble(0,  PLOT_EMPTY_VALUE, 0.0);
    PlotIndexSetDouble(1,  PLOT_EMPTY_VALUE, 0.0);
    PlotIndexSetInteger(0, PLOT_ARROW_SHIFT,  14);
    PlotIndexSetInteger(1, PLOT_ARROW_SHIFT, -14);

    // 現在足インジケーター
    ema_fast_handle = iMA(_Symbol, PERIOD_CURRENT, EMA_Fast, 0, MODE_EMA, PRICE_CLOSE);
    ema_slow_handle = iMA(_Symbol, PERIOD_CURRENT, EMA_Slow, 0, MODE_EMA, PRICE_CLOSE);
    rsi_handle      = iRSI(_Symbol, PERIOD_CURRENT, RSI_Period, PRICE_CLOSE);
    bb_handle       = iBands(_Symbol, PERIOD_CURRENT, BB_Period, 0, BB_Dev, PRICE_CLOSE);

    // 上位足EMA
    htf_ema_fast_handle = iMA(_Symbol, HTF, EMA_Fast, 0, MODE_EMA, PRICE_CLOSE);
    htf_ema_slow_handle = iMA(_Symbol, HTF, EMA_Slow, 0, MODE_EMA, PRICE_CLOSE);

    if(ema_fast_handle == INVALID_HANDLE || ema_slow_handle == INVALID_HANDLE ||
       rsi_handle == INVALID_HANDLE || bb_handle == INVALID_HANDLE ||
       htf_ema_fast_handle == INVALID_HANDLE || htf_ema_slow_handle == INVALID_HANDLE)
    {
        Print("インジケーターの初期化に失敗しました");
        return INIT_FAILED;
    }

    IndicatorSetString(INDICATOR_SHORTNAME,
        StringFormat("ScalpingFX v2 EMA(%d,%d) RSI(%d)", EMA_Fast, EMA_Slow, RSI_Period));

    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
// 時間帯チェック
bool IsTradeTime(datetime t)
{
    if(!UseTimeFilter) return true;
    MqlDateTime dt;
    TimeToStruct(t, dt);
    int h = dt.hour;
    if(h >= Session1_Start && h < Session1_End)  return true;
    if(h >= Session2_Start || h < (Session2_End == 24 ? 0 : Session2_End)) return true;
    return false;
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
    if(rates_total < EMA_Slow + RSI_Period + BB_Period + 5)
        return 0;

    double ema_fast[], ema_slow[], rsi[];
    double bb_upper[], bb_lower[], bb_mid[];
    double htf_fast[], htf_slow[];

    ArraySetAsSeries(ema_fast,  true);
    ArraySetAsSeries(ema_slow,  true);
    ArraySetAsSeries(rsi,       true);
    ArraySetAsSeries(bb_upper,  true);
    ArraySetAsSeries(bb_lower,  true);
    ArraySetAsSeries(bb_mid,    true);
    ArraySetAsSeries(htf_fast,  true);
    ArraySetAsSeries(htf_slow,  true);
    ArraySetAsSeries(BuyBuffer,  true);
    ArraySetAsSeries(SellBuffer, true);
    ArraySetAsSeries(high,  true);
    ArraySetAsSeries(low,   true);
    ArraySetAsSeries(close, true);
    ArraySetAsSeries(time,  true);

    if(CopyBuffer(ema_fast_handle, 0, 0, rates_total, ema_fast) <= 0) return 0;
    if(CopyBuffer(ema_slow_handle, 0, 0, rates_total, ema_slow) <= 0) return 0;
    if(CopyBuffer(rsi_handle,      0, 0, rates_total, rsi)      <= 0) return 0;
    if(CopyBuffer(bb_handle, 1, 0, rates_total, bb_upper) <= 0) return 0; // 1=Upper
    if(CopyBuffer(bb_handle, 2, 0, rates_total, bb_lower) <= 0) return 0; // 2=Lower
    if(CopyBuffer(bb_handle, 0, 0, rates_total, bb_mid)   <= 0) return 0; // 0=Mid
    if(CopyBuffer(htf_ema_fast_handle, 0, 0, 5, htf_fast) <= 0) return 0;
    if(CopyBuffer(htf_ema_slow_handle, 0, 0, 5, htf_slow) <= 0) return 0;

    // 上位足トレンド判定
    bool htf_bull = htf_fast[0] > htf_slow[0]; // 上位足が上昇トレンド
    bool htf_bear = htf_fast[0] < htf_slow[0]; // 上位足が下降トレンド

    int start = (prev_calculated <= 1) ? rates_total - 2 : 1;

    for(int i = start; i >= 1; i--)
    {
        BuyBuffer[i]  = 0.0;
        SellBuffer[i] = 0.0;

        // EMAクロス判定
        bool bull_cross = (ema_fast[i+1] <= ema_slow[i+1]) && (ema_fast[i] > ema_slow[i]);
        bool bear_cross = (ema_fast[i+1] >= ema_slow[i+1]) && (ema_fast[i] < ema_slow[i]);

        // pip幅
        double pip = (_Digits == 3 || _Digits == 5) ? _Point * 10 : _Point;
        if(StringFind(_Symbol, "XAU") >= 0) pip = 0.1;
        double sl_dist = SL_Pips * pip;

        // BB帯域チェック：バンド付近（上下10%以内）のみ有効
        double bb_range  = bb_upper[i] - bb_lower[i];
        double bb_margin = bb_range * 0.25;
        bool near_bb_upper = (close[i] >= bb_upper[i] - bb_margin);
        bool near_bb_lower = (close[i] <= bb_lower[i] + bb_margin);
        bool bb_buy_ok  = !UseBB || near_bb_lower; // 買いはバンド下付近
        bool bb_sell_ok = !UseBB || near_bb_upper;  // 売りはバンド上付近

        // 時間帯チェック
        bool time_ok = IsTradeTime(time[i]);

        // 上位足フィルター
        bool htf_buy_ok  = !UseHTF || htf_bull;
        bool htf_sell_ok = !UseHTF || htf_bear;

        // RSIチェック
        bool rsi_ok = rsi[i] > RSI_Lower && rsi[i] < RSI_Upper;

        // ▲ 買いシグナル
        if(bull_cross && rsi_ok && bb_buy_ok && htf_buy_ok && time_ok)
        {
            BuyBuffer[i] = low[i] - sl_dist * 0.3;

            if(i == 1)
            {
                if(ShowRRLines)
                    DrawRRLines(close[i], sl_dist, true, time[i]);

                if(AlertOn && prev_calculated > 0)
                {
                    string msg = StringFormat(
                        "【▲ BUY】%s\nEntry:%.%df  SL:%.%df\nTP1(1:%.1f):%.%df  TP2(1:%.1f):%.%df",
                        _Symbol,
                        _Digits, close[i],
                        _Digits, close[i] - sl_dist,
                        RR_TP1, _Digits, close[i] + sl_dist * RR_TP1,
                        RR_TP2, _Digits, close[i] + sl_dist * RR_TP2);
                    Alert(msg);
                    if(PushNotify) SendNotification(msg);
                }
            }
        }

        // ▼ 売りシグナル
        if(bear_cross && rsi_ok && bb_sell_ok && htf_sell_ok && time_ok)
        {
            SellBuffer[i] = high[i] + sl_dist * 0.3;

            if(i == 1)
            {
                if(ShowRRLines)
                    DrawRRLines(close[i], sl_dist, false, time[i]);

                if(AlertOn && prev_calculated > 0)
                {
                    string msg = StringFormat(
                        "【▼ SELL】%s\nEntry:%.%df  SL:%.%df\nTP1(1:%.1f):%.%df  TP2(1:%.1f):%.%df",
                        _Symbol,
                        _Digits, close[i],
                        _Digits, close[i] + sl_dist,
                        RR_TP1, _Digits, close[i] - sl_dist * RR_TP1,
                        RR_TP2, _Digits, close[i] - sl_dist * RR_TP2);
                    Alert(msg);
                    if(PushNotify) SendNotification(msg);
                }
            }
        }
    }

    // フィルター状態をチャートに表示
    if(ShowFilterInfo)
        ShowFilterStatus(htf_bull, htf_bear);

    return rates_total;
}

//+------------------------------------------------------------------+
void ShowFilterStatus(bool htf_bull, bool htf_bear)
{
    string trend = htf_bull ? "↑ 上昇" : htf_bear ? "↓ 下降" : "→ 横ばい";
    color  tcol  = htf_bull ? clrDodgerBlue : htf_bear ? clrRed : clrGray;

    MqlDateTime now;
    TimeToStruct(TimeCurrent(), now);
    bool in_time = IsTradeTime(TimeCurrent());

    string info = StringFormat(
        "上位足(%s):%s  |  BB:%s  |  時間帯:%s",
        EnumToString(HTF),
        trend,
        UseBB ? "ON" : "OFF",
        in_time ? "取引時間内" : "時間外");

    string name = OBJ_PREFIX + "FilterInfo";
    if(ObjectFind(0, name) < 0)
    {
        ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
        ObjectSetInteger(0, name, OBJPROP_CORNER,    CORNER_LEFT_UPPER);
        ObjectSetInteger(0, name, OBJPROP_XDISTANCE, 10);
        ObjectSetInteger(0, name, OBJPROP_YDISTANCE, 20);
        ObjectSetInteger(0, name, OBJPROP_FONTSIZE,  9);
        ObjectSetInteger(0, name, OBJPROP_SELECTABLE,false);
    }
    ObjectSetString (0, name, OBJPROP_TEXT,  info);
    ObjectSetInteger(0, name, OBJPROP_COLOR, tcol);
    ChartRedraw();
}

//+------------------------------------------------------------------+
void DrawRRLines(double entry, double sl_dist, bool is_buy, datetime sig_time)
{
    ObjectsDeleteAll(0, OBJ_PREFIX + "Line");
    ObjectsDeleteAll(0, OBJ_PREFIX + "Label");

    double sl  = is_buy ? entry - sl_dist          : entry + sl_dist;
    double tp1 = is_buy ? entry + sl_dist * RR_TP1 : entry - sl_dist * RR_TP1;
    double tp2 = is_buy ? entry + sl_dist * RR_TP2 : entry - sl_dist * RR_TP2;

    CreateHLine(OBJ_PREFIX + "LineEntry", entry, clrWhite,             STYLE_SOLID, 2,
                "ENTRY: " + DoubleToString(entry, _Digits));
    CreateHLine(OBJ_PREFIX + "LineSL",    sl,    clrOrangeRed,         STYLE_DASH,  1,
                "SL (損切): " + DoubleToString(sl, _Digits));
    CreateHLine(OBJ_PREFIX + "LineTP1",   tp1,   clrMediumSpringGreen, STYLE_DASH,  1,
                "TP1  RR 1:" + DoubleToString(RR_TP1,1) + "  " + DoubleToString(tp1, _Digits));
    CreateHLine(OBJ_PREFIX + "LineTP2",   tp2,   clrLime,              STYLE_DASH,  1,
                "TP2  RR 1:" + DoubleToString(RR_TP2,1) + "  " + DoubleToString(tp2, _Digits));

    if(ShowLabel)
    {
        string dir  = is_buy ? "▲ BUY" : "▼ SELL";
        color  dclr = is_buy ? BuyColor : SellColor;
        CreateLabel(OBJ_PREFIX + "LabelSignal",
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
    ObjectSetString (0, name, OBJPROP_TEXT,       text);
    ObjectSetInteger(0, name, OBJPROP_COLOR,      clr);
    ObjectSetInteger(0, name, OBJPROP_FONTSIZE,   10);
    ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, name, OBJPROP_HIDDEN,     true);
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    ObjectsDeleteAll(0, OBJ_PREFIX);
    IndicatorRelease(ema_fast_handle);
    IndicatorRelease(ema_slow_handle);
    IndicatorRelease(rsi_handle);
    IndicatorRelease(bb_handle);
    IndicatorRelease(htf_ema_fast_handle);
    IndicatorRelease(htf_ema_slow_handle);
}
//+------------------------------------------------------------------+

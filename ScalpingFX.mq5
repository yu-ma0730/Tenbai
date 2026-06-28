//+------------------------------------------------------------------+
//|  Scalping FX Signal Indicator  v2.1                             |
//|  EMA(9/21)クロス + RSI(14) + BB + 上位足フィルター + 時間帯    |
//|  勝ち○ / 負け✕マーカー付き                                    |
//|  対応: USD/JPY, EUR/USD, EUR/JPY, GOLD (XAU/USD)               |
//+------------------------------------------------------------------+
#property copyright "Scalping FX"
#property version   "2.10"
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
input bool     ShowResult      = true;   // 勝ち○ / 負け✕ マーカーを表示する
input int      ResultMaxBars   = 30;     // 結果を判定する最大足数
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
            else if(ShowResult)
            {
                // 過去シグナル：結果判定して○/✕を描画
                double entry = close[i];
                double sl    = entry - sl_dist;
                double tp1   = entry + sl_dist * RR_TP1;
                DrawTradeResult(i, entry, sl, tp1, true, high, low, time, rates_total);
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
            else if(ShowResult)
            {
                // 過去シグナル：結果判定して○/✕を描画
                double entry = close[i];
                double sl    = entry + sl_dist;
                double tp1   = entry - sl_dist * RR_TP1;
                DrawTradeResult(i, entry, sl, tp1, false, high, low, time, rates_total);
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
    ObjectsDeleteAll(0, OBJ_PREFIX + "Zone");
    ObjectsDeleteAll(0, OBJ_PREFIX + "Label");

    double sl  = is_buy ? entry - sl_dist          : entry + sl_dist;
    double tp1 = is_buy ? entry + sl_dist * RR_TP1 : entry - sl_dist * RR_TP1;
    double tp2 = is_buy ? entry + sl_dist * RR_TP2 : entry - sl_dist * RR_TP2;

    // ゾーン表示用の右端時間（現在から50本先）
    datetime t_left  = sig_time;
    datetime t_right = sig_time + PeriodSeconds(PERIOD_CURRENT) * 50;

    // ---- 赤ゾーン：エントリー → SL（リスク範囲）----
    CreateZone(OBJ_PREFIX + "ZoneSL",
               t_left, entry, t_right, sl,
               clrRed, 60,
               "リスクゾーン (SL): " + DoubleToString(sl, _Digits));

    // ---- 青ゾーン：エントリー → TP1（RR1:1.5）----
    CreateZone(OBJ_PREFIX + "ZoneTP1",
               t_left, entry, t_right, tp1,
               clrDodgerBlue, 50,
               "TP1  RR 1:" + DoubleToString(RR_TP1,1) + "  " + DoubleToString(tp1, _Digits));

    // ---- 水色ゾーン：TP1 → TP2（RR1:2.0）----
    CreateZone(OBJ_PREFIX + "ZoneTP2",
               t_left, tp1, t_right, tp2,
               clrDeepSkyBlue, 40,
               "TP2  RR 1:" + DoubleToString(RR_TP2,1) + "  " + DoubleToString(tp2, _Digits));

    // ---- 水平ライン ----
    CreateHLine(OBJ_PREFIX + "LineEntry", entry, clrWhite,             STYLE_SOLID, 2,
                "ENTRY: " + DoubleToString(entry, _Digits));
    CreateHLine(OBJ_PREFIX + "LineSL",    sl,    clrOrangeRed,         STYLE_DASH,  2,
                "SL (損切): " + DoubleToString(sl, _Digits));
    CreateHLine(OBJ_PREFIX + "LineTP1",   tp1,   clrDodgerBlue,        STYLE_DASH,  2,
                "TP1  RR 1:" + DoubleToString(RR_TP1,1) + "  " + DoubleToString(tp1, _Digits));
    CreateHLine(OBJ_PREFIX + "LineTP2",   tp2,   clrDeepSkyBlue,       STYLE_DASH,  2,
                "TP2  RR 1:" + DoubleToString(RR_TP2,1) + "  " + DoubleToString(tp2, _Digits));

    // ---- ラベル ----
    if(ShowLabel)
    {
        string dir  = is_buy ? "▲ BUY" : "▼ SELL";
        color  dclr = is_buy ? BuyColor : SellColor;

        // SLラベル
        CreateLabel(OBJ_PREFIX + "LabelSL",
                    "SL  " + DoubleToString(sl, _Digits),
                    t_right, sl, clrOrangeRed);
        // TP1ラベル
        CreateLabel(OBJ_PREFIX + "LabelTP1",
                    "TP1 (RR 1:" + DoubleToString(RR_TP1,1) + ")  " + DoubleToString(tp1, _Digits),
                    t_right, tp1, clrDodgerBlue);
        // TP2ラベル
        CreateLabel(OBJ_PREFIX + "LabelTP2",
                    "TP2 (RR 1:" + DoubleToString(RR_TP2,1) + ")  " + DoubleToString(tp2, _Digits),
                    t_right, tp2, clrDeepSkyBlue);
        // シグナルラベル
        CreateLabel(OBJ_PREFIX + "LabelSignal",
                    StringFormat("%s  Entry:%.%df", dir, _Digits, entry),
                    sig_time, entry, dclr);
    }

    ChartRedraw();
}

//+------------------------------------------------------------------+
void CreateZone(string name,
                datetime t1, double price1,
                datetime t2, double price2,
                color clr, uchar alpha, string tooltip)
{
    if(ObjectFind(0, name) >= 0) ObjectDelete(0, name);
    ObjectCreate(0, name, OBJ_RECTANGLE, 0, t1, price1, t2, price2);
    ObjectSetInteger(0, name, OBJPROP_COLOR,      clr);
    ObjectSetInteger(0, name, OBJPROP_STYLE,      STYLE_SOLID);
    ObjectSetInteger(0, name, OBJPROP_WIDTH,      1);
    ObjectSetInteger(0, name, OBJPROP_FILL,       true);       // 塗りつぶし
    ObjectSetInteger(0, name, OBJPROP_BACK,       true);       // 背面表示
    ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, name, OBJPROP_HIDDEN,     true);
    ObjectSetString (0, name, OBJPROP_TOOLTIP,    tooltip);
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
// シグナル後の足をスキャンしてTP/SL到達を判定し○/✕を描画
void DrawTradeResult(int sig_bar,
                     double entry, double sl, double tp1,
                     bool is_buy,
                     const double &high[],
                     const double &low[],
                     const datetime &time[],
                     int rates_total)
{
    // sig_bar はas-series配列のインデックス（0=最新足）
    // sig_bar-1 が次の足（新しい足）
    int result_bar = -1;
    bool win = false;

    int scan_end = MathMax(sig_bar - ResultMaxBars, 1);
    for(int j = sig_bar - 1; j >= scan_end; j--)
    {
        if(is_buy)
        {
            if(high[j] >= tp1) { result_bar = j; win = true;  break; }
            if(low[j]  <= sl)  { result_bar = j; win = false; break; }
        }
        else
        {
            if(low[j]  <= tp1) { result_bar = j; win = true;  break; }
            if(high[j] >= sl)  { result_bar = j; win = false; break; }
        }
    }

    if(result_bar < 0) return; // まだ結果未確定

    string name = OBJ_PREFIX + "Result_" + IntegerToString((int)time[sig_bar]);
    if(ObjectFind(0, name) >= 0) return; // 既に描画済み

    double mark_price;
    string mark_text;
    color  mark_color;

    if(win)
    {
        // ○ 勝ち：緑、TP1側に表示
        mark_text  = "〇";
        mark_color = clrLime;
        mark_price = is_buy ? high[result_bar] + (tp1 - entry) * 0.15
                            : low[result_bar]  - (entry - tp1) * 0.15;
    }
    else
    {
        // ✕ 負け：赤、SL側に表示
        mark_text  = "✕";
        mark_color = clrRed;
        mark_price = is_buy ? low[result_bar]  - MathAbs(entry - sl) * 0.15
                            : high[result_bar] + MathAbs(sl - entry) * 0.15;
    }

    ObjectCreate(0, name, OBJ_TEXT, 0, time[result_bar], mark_price);
    ObjectSetString (0, name, OBJPROP_TEXT,      mark_text);
    ObjectSetInteger(0, name, OBJPROP_COLOR,     mark_color);
    ObjectSetInteger(0, name, OBJPROP_FONTSIZE,  14);
    ObjectSetString (0, name, OBJPROP_FONT,      "Arial Unicode MS");
    ObjectSetInteger(0, name, OBJPROP_ANCHOR,    ANCHOR_CENTER);
    ObjectSetInteger(0, name, OBJPROP_SELECTABLE,false);
    ObjectSetInteger(0, name, OBJPROP_HIDDEN,    true);
    string tip = win
        ? "勝ち ○  TP1到達: " + DoubleToString(tp1, _Digits)
        : "負け ✕  SL到達: " + DoubleToString(sl,  _Digits);
    ObjectSetString(0, name, OBJPROP_TOOLTIP, tip);
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

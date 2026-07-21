//+------------------------------------------------------------------+
//| XAUUSD Multi-Timeframe Analysis Indicator                         |
//| Professional Trading Tool for Advanced Traders                    |
//| Analyzes H1, H4, and D1 simultaneously                           |
//+------------------------------------------------------------------+
#property copyright "Professional Trader 2024"
#property link      "https://github.com/yu-ma0730/xauusdtool"
#property version   "2.00"
#property indicator_chart_window
#property indicator_buffers 12
#property indicator_plots   12

//--- Plot definitions
#property indicator_label1  "H1 Buy Signal"
#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrGreen
#property indicator_width1  3

#property indicator_label2  "H1 Sell Signal"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrRed
#property indicator_width2  3

#property indicator_label3  "H4 Trend"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrDodgerBlue
#property indicator_width3  2

#property indicator_label4  "D1 Trend"
#property indicator_type4   DRAW_LINE
#property indicator_color4  clrCrimson
#property indicator_width4  2

#property indicator_label5  "Support Level"
#property indicator_type5   DRAW_LINE
#property indicator_color5  clrGreen
#property indicator_width5  1
#property indicator_style5  STYLE_DASHED

#property indicator_label6  "Resistance Level"
#property indicator_type6   DRAW_LINE
#property indicator_color6  clrRed
#property indicator_width6  1
#property indicator_style6  STYLE_DASHED

#property indicator_label7  "Swing High"
#property indicator_type7   DRAW_POINT
#property indicator_color7  clrOrange
#property indicator_width7  2

#property indicator_label8  "Swing Low"
#property indicator_type8   DRAW_POINT
#property indicator_color8  clrBlue
#property indicator_width8  2

#property indicator_label9  "H1 RSI"
#property indicator_type9   DRAW_LINE
#property indicator_color9  clrLightBlue
#property indicator_width9  1

#property indicator_label10 "H4 RSI"
#property indicator_type10  DRAW_LINE
#property indicator_color10 clrOrange
#property indicator_width10 1

#property indicator_label11 "D1 RSI"
#property indicator_type11  DRAW_LINE
#property indicator_color11 clrMagenta
#property indicator_width11 1

#property indicator_label12 "Signal Strength"
#property indicator_type12  DRAW_LINE
#property indicator_color12 clrGoldenrod
#property indicator_width12 2

//--- Input Parameters
input int     RSI_Period = 14;
input double  RSI_Overbought = 70.0;
input double  RSI_Oversold = 30.0;
input int     MACD_Fast = 12;
input int     MACD_Slow = 26;
input int     MACD_Signal = 9;
input int     EMA_Fast = 20;
input int     EMA_Slow = 50;
input int     Support_Resistance_Period = 50;
input int     Swing_Period = 10;

//--- Buffers
double H1_Buy_Signal[];
double H1_Sell_Signal[];
double H4_Trend[];
double D1_Trend[];
double Support_Level[];
double Resistance_Level[];
double Swing_High[];
double Swing_Low[];
double H1_RSI_Buffer[];
double H4_RSI_Buffer[];
double D1_RSI_Buffer[];
double Signal_Strength[];

//--- Indicator Handles
int h1_rsi_handle = INVALID_HANDLE;
int h1_macd_handle = INVALID_HANDLE;
int h1_ema_fast_handle = INVALID_HANDLE;
int h1_ema_slow_handle = INVALID_HANDLE;

int h4_rsi_handle = INVALID_HANDLE;
int h4_macd_handle = INVALID_HANDLE;
int h4_ema_fast_handle = INVALID_HANDLE;
int h4_ema_slow_handle = INVALID_HANDLE;

int d1_rsi_handle = INVALID_HANDLE;
int d1_macd_handle = INVALID_HANDLE;
int d1_ema_fast_handle = INVALID_HANDLE;
int d1_ema_slow_handle = INVALID_HANDLE;

//--- Structures
struct MultiTimeFrameData {
    // H1
    double h1_rsi;
    double h1_macd;
    double h1_macd_signal;
    double h1_ema_fast;
    double h1_ema_slow;
    double h1_close;

    // H4
    double h4_rsi;
    double h4_macd;
    double h4_macd_signal;
    double h4_ema_fast;
    double h4_ema_slow;
    double h4_close;

    // D1
    double d1_rsi;
    double d1_macd;
    double d1_macd_signal;
    double d1_ema_fast;
    double d1_ema_slow;
    double d1_close;
};

struct PriceActionSignal {
    bool pinbar_buy;
    bool pinbar_sell;
    bool inside_bar;
    bool engulfing_buy;
    bool engulfing_sell;
    bool breakout;
    double support;
    double resistance;
    int signal_strength;
};

//+------------------------------------------------------------------+
//| Custom indicator initialization function                        |
//+------------------------------------------------------------------+
int OnInit() {
    //--- Bind buffers
    SetIndexBuffer(0, H1_Buy_Signal, INDICATOR_DATA);
    SetIndexBuffer(1, H1_Sell_Signal, INDICATOR_DATA);
    SetIndexBuffer(2, H4_Trend, INDICATOR_DATA);
    SetIndexBuffer(3, D1_Trend, INDICATOR_DATA);
    SetIndexBuffer(4, Support_Level, INDICATOR_DATA);
    SetIndexBuffer(5, Resistance_Level, INDICATOR_DATA);
    SetIndexBuffer(6, Swing_High, INDICATOR_DATA);
    SetIndexBuffer(7, Swing_Low, INDICATOR_DATA);
    SetIndexBuffer(8, H1_RSI_Buffer, INDICATOR_DATA);
    SetIndexBuffer(9, H4_RSI_Buffer, INDICATOR_DATA);
    SetIndexBuffer(10, D1_RSI_Buffer, INDICATOR_DATA);
    SetIndexBuffer(11, Signal_Strength, INDICATOR_DATA);

    //--- Set arrow codes
    PlotIndexSetInteger(0, PLOT_ARROW, 233); // Up arrow
    PlotIndexSetInteger(1, PLOT_ARROW, 234); // Down arrow
    PlotIndexSetInteger(6, PLOT_ARROW, 110); // Swing High
    PlotIndexSetInteger(7, PLOT_ARROW, 108); // Swing Low

    //--- Create H1 handles
    h1_rsi_handle = iRSI(Symbol(), PERIOD_H1, RSI_Period, PRICE_CLOSE);
    h1_macd_handle = iMACD(Symbol(), PERIOD_H1, MACD_Fast, MACD_Slow, MACD_Signal, PRICE_CLOSE);
    h1_ema_fast_handle = iMA(Symbol(), PERIOD_H1, EMA_Fast, 0, MODE_EMA, PRICE_CLOSE);
    h1_ema_slow_handle = iMA(Symbol(), PERIOD_H1, EMA_Slow, 0, MODE_EMA, PRICE_CLOSE);

    //--- Create H4 handles
    h4_rsi_handle = iRSI(Symbol(), PERIOD_H4, RSI_Period, PRICE_CLOSE);
    h4_macd_handle = iMACD(Symbol(), PERIOD_H4, MACD_Fast, MACD_Slow, MACD_Signal, PRICE_CLOSE);
    h4_ema_fast_handle = iMA(Symbol(), PERIOD_H4, EMA_Fast, 0, MODE_EMA, PRICE_CLOSE);
    h4_ema_slow_handle = iMA(Symbol(), PERIOD_H4, EMA_Slow, 0, MODE_EMA, PRICE_CLOSE);

    //--- Create D1 handles
    d1_rsi_handle = iRSI(Symbol(), PERIOD_D1, RSI_Period, PRICE_CLOSE);
    d1_macd_handle = iMACD(Symbol(), PERIOD_D1, MACD_Fast, MACD_Slow, MACD_Signal, PRICE_CLOSE);
    d1_ema_fast_handle = iMA(Symbol(), PERIOD_D1, EMA_Fast, 0, MODE_EMA, PRICE_CLOSE);
    d1_ema_slow_handle = iMA(Symbol(), PERIOD_D1, EMA_Slow, 0, MODE_EMA, PRICE_CLOSE);

    //--- Validate handles
    if (h1_rsi_handle == INVALID_HANDLE || h4_rsi_handle == INVALID_HANDLE || d1_rsi_handle == INVALID_HANDLE) {
        Print("Error creating RSI handles");
        return INIT_FAILED;
    }

    IndicatorSetString(INDICATOR_SHORTNAME, "XAUUSD Multi-Timeframe Analysis");
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                      |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    if (h1_rsi_handle != INVALID_HANDLE) IndicatorRelease(h1_rsi_handle);
    if (h1_macd_handle != INVALID_HANDLE) IndicatorRelease(h1_macd_handle);
    if (h1_ema_fast_handle != INVALID_HANDLE) IndicatorRelease(h1_ema_fast_handle);
    if (h1_ema_slow_handle != INVALID_HANDLE) IndicatorRelease(h1_ema_slow_handle);

    if (h4_rsi_handle != INVALID_HANDLE) IndicatorRelease(h4_rsi_handle);
    if (h4_macd_handle != INVALID_HANDLE) IndicatorRelease(h4_macd_handle);
    if (h4_ema_fast_handle != INVALID_HANDLE) IndicatorRelease(h4_ema_fast_handle);
    if (h4_ema_slow_handle != INVALID_HANDLE) IndicatorRelease(h4_ema_slow_handle);

    if (d1_rsi_handle != INVALID_HANDLE) IndicatorRelease(d1_rsi_handle);
    if (d1_macd_handle != INVALID_HANDLE) IndicatorRelease(d1_macd_handle);
    if (d1_ema_fast_handle != INVALID_HANDLE) IndicatorRelease(d1_ema_fast_handle);
    if (d1_ema_slow_handle != INVALID_HANDLE) IndicatorRelease(d1_ema_slow_handle);
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                             |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[]) {
    int limit = rates_total - prev_calculated;
    if (limit > rates_total - 100) limit = rates_total - 100;

    //--- Get multi-timeframe data
    for (int i = limit - 1; i >= 0; i--) {
        MultiTimeFrameData mtf = GetMultiTimeFrameData(i);

        //--- Store RSI values
        H1_RSI_Buffer[i] = mtf.h1_rsi;
        H4_RSI_Buffer[i] = mtf.h4_rsi;
        D1_RSI_Buffer[i] = mtf.d1_rsi;

        //--- Store trend direction
        H4_Trend[i] = (mtf.h4_ema_fast > mtf.h4_ema_slow) ? high[i] : low[i];
        D1_Trend[i] = (mtf.d1_ema_fast > mtf.d1_ema_slow) ? high[i] : low[i];

        //--- Detect price action patterns
        PriceActionSignal pas = DetectPriceAction(high, low, close, i);

        //--- Store support/resistance
        Support_Level[i] = pas.support;
        Resistance_Level[i] = pas.resistance;

        //--- Detect swing points
        if (IsSwingHigh(high, i, Swing_Period)) {
            Swing_High[i] = high[i];
        } else {
            Swing_High[i] = 0;
        }

        if (IsSwingLow(low, i, Swing_Period)) {
            Swing_Low[i] = low[i];
        } else {
            Swing_Low[i] = 0;
        }

        //--- Generate advanced signals
        if (GenerateAdvancedSignal(mtf, pas, i, close[i], high[i], low[i])) {
            H1_Buy_Signal[i] = low[i] - (high[i] - low[i]) * 0.5;
            H1_Sell_Signal[i] = 0;
            Signal_Strength[i] = pas.signal_strength;
        } else if (GenerateAdvancedSellSignal(mtf, pas, i, close[i], high[i], low[i])) {
            H1_Sell_Signal[i] = high[i] + (high[i] - low[i]) * 0.5;
            H1_Buy_Signal[i] = 0;
            Signal_Strength[i] = pas.signal_strength;
        } else {
            H1_Buy_Signal[i] = 0;
            H1_Sell_Signal[i] = 0;
            Signal_Strength[i] = 0;
        }
    }

    return rates_total;
}

//+------------------------------------------------------------------+
//| Get Multi-Timeframe Data                                        |
//+------------------------------------------------------------------+
MultiTimeFrameData GetMultiTimeFrameData(int bar) {
    MultiTimeFrameData data;

    //--- Get H1 data
    double h1_rsi[], h1_macd[], h1_macd_signal[], h1_ema_fast[], h1_ema_slow[], h1_close[];
    ArraySetAsSeries(h1_rsi, true);
    ArraySetAsSeries(h1_macd, true);
    ArraySetAsSeries(h1_macd_signal, true);
    ArraySetAsSeries(h1_ema_fast, true);
    ArraySetAsSeries(h1_ema_slow, true);
    ArraySetAsSeries(h1_close, true);

    CopyBuffer(h1_rsi_handle, 0, 0, bar + 1, h1_rsi);
    CopyBuffer(h1_macd_handle, 0, 0, bar + 1, h1_macd);
    CopyBuffer(h1_macd_handle, 1, 0, bar + 1, h1_macd_signal);
    CopyBuffer(h1_ema_fast_handle, 0, 0, bar + 1, h1_ema_fast);
    CopyBuffer(h1_ema_slow_handle, 0, 0, bar + 1, h1_ema_slow);
    CopyClose(Symbol(), PERIOD_H1, 0, bar + 1, h1_close);

    data.h1_rsi = h1_rsi[bar];
    data.h1_macd = h1_macd[bar];
    data.h1_macd_signal = h1_macd_signal[bar];
    data.h1_ema_fast = h1_ema_fast[bar];
    data.h1_ema_slow = h1_ema_slow[bar];
    data.h1_close = h1_close[bar];

    //--- Get H4 data
    double h4_rsi[], h4_macd[], h4_macd_signal[], h4_ema_fast[], h4_ema_slow[], h4_close[];
    ArraySetAsSeries(h4_rsi, true);
    ArraySetAsSeries(h4_macd, true);
    ArraySetAsSeries(h4_macd_signal, true);
    ArraySetAsSeries(h4_ema_fast, true);
    ArraySetAsSeries(h4_ema_slow, true);
    ArraySetAsSeries(h4_close, true);

    CopyBuffer(h4_rsi_handle, 0, 0, 100, h4_rsi);
    CopyBuffer(h4_macd_handle, 0, 0, 100, h4_macd);
    CopyBuffer(h4_macd_handle, 1, 0, 100, h4_macd_signal);
    CopyBuffer(h4_ema_fast_handle, 0, 0, 100, h4_ema_fast);
    CopyBuffer(h4_ema_slow_handle, 0, 0, 100, h4_ema_slow);
    CopyClose(Symbol(), PERIOD_H4, 0, 100, h4_close);

    data.h4_rsi = h4_rsi[0];
    data.h4_macd = h4_macd[0];
    data.h4_macd_signal = h4_macd_signal[0];
    data.h4_ema_fast = h4_ema_fast[0];
    data.h4_ema_slow = h4_ema_slow[0];
    data.h4_close = h4_close[0];

    //--- Get D1 data
    double d1_rsi[], d1_macd[], d1_macd_signal[], d1_ema_fast[], d1_ema_slow[], d1_close[];
    ArraySetAsSeries(d1_rsi, true);
    ArraySetAsSeries(d1_macd, true);
    ArraySetAsSeries(d1_macd_signal, true);
    ArraySetAsSeries(d1_ema_fast, true);
    ArraySetAsSeries(d1_ema_slow, true);
    ArraySetAsSeries(d1_close, true);

    CopyBuffer(d1_rsi_handle, 0, 0, 100, d1_rsi);
    CopyBuffer(d1_macd_handle, 0, 0, 100, d1_macd);
    CopyBuffer(d1_macd_handle, 1, 0, 100, d1_macd_signal);
    CopyBuffer(d1_ema_fast_handle, 0, 0, 100, d1_ema_fast);
    CopyBuffer(d1_ema_slow_handle, 0, 0, 100, d1_ema_slow);
    CopyClose(Symbol(), PERIOD_D1, 0, 100, d1_close);

    data.d1_rsi = d1_rsi[0];
    data.d1_macd = d1_macd[0];
    data.d1_macd_signal = d1_macd_signal[0];
    data.d1_ema_fast = d1_ema_fast[0];
    data.d1_ema_slow = d1_ema_slow[0];
    data.d1_close = d1_close[0];

    return data;
}

//+------------------------------------------------------------------+
//| Detect Price Action Patterns                                    |
//+------------------------------------------------------------------+
PriceActionSignal DetectPriceAction(const double &high[], const double &low[], const double &close[], int bar) {
    PriceActionSignal signal;
    signal.pinbar_buy = false;
    signal.pinbar_sell = false;
    signal.inside_bar = false;
    signal.engulfing_buy = false;
    signal.engulfing_sell = false;
    signal.breakout = false;
    signal.signal_strength = 0;

    if (bar < 2) return signal;

    double current_high = high[bar];
    double current_low = low[bar];
    double current_open = close[bar];
    double current_close = close[bar];

    double prev_high = high[bar + 1];
    double prev_low = low[bar + 1];
    double prev_close = close[bar + 1];

    //--- Detect Pinbar (Buy)
    double upper_wick = current_high - MathMax(current_open, current_close);
    double lower_wick = MathMin(current_open, current_close) - current_low;
    double body_size = MathAbs(current_close - current_open);

    if (lower_wick > body_size * 2 && current_close > current_open) {
        signal.pinbar_buy = true;
        signal.signal_strength += 2;
    }

    //--- Detect Pinbar (Sell)
    if (upper_wick > body_size * 2 && current_close < current_open) {
        signal.pinbar_sell = true;
        signal.signal_strength += 2;
    }

    //--- Detect Inside Bar
    if (current_high < prev_high && current_low > prev_low) {
        signal.inside_bar = true;
    }

    //--- Detect Engulfing (Buy)
    if (current_close > prev_open && current_open < prev_close && current_close > prev_close) {
        signal.engulfing_buy = true;
        signal.signal_strength += 1;
    }

    //--- Detect Engulfing (Sell)
    if (current_close < prev_open && current_open > prev_close && current_close < prev_close) {
        signal.engulfing_sell = true;
        signal.signal_strength += 1;
    }

    //--- Calculate Support/Resistance
    double highest = high[bar];
    double lowest = low[bar];
    for (int i = bar; i < bar + Support_Resistance_Period && i < ArraySize(high); i++) {
        if (high[i] > highest) highest = high[i];
        if (low[i] < lowest) lowest = low[i];
    }

    signal.support = lowest + (highest - lowest) * 0.25;
    signal.resistance = lowest + (highest - lowest) * 0.75;

    return signal;
}

//+------------------------------------------------------------------+
//| Check if Swing High                                            |
//+------------------------------------------------------------------+
bool IsSwingHigh(const double &high[], int bar, int period) {
    if (bar < period || bar >= ArraySize(high) - period) return false;

    for (int i = 1; i <= period; i++) {
        if (high[bar - i] >= high[bar] || high[bar + i] >= high[bar]) return false;
    }
    return true;
}

//+------------------------------------------------------------------+
//| Check if Swing Low                                             |
//+------------------------------------------------------------------+
bool IsSwingLow(const double &low[], int bar, int period) {
    if (bar < period || bar >= ArraySize(low) - period) return false;

    for (int i = 1; i <= period; i++) {
        if (low[bar - i] <= low[bar] || low[bar + i] <= low[bar]) return false;
    }
    return true;
}

//+------------------------------------------------------------------+
//| Generate Advanced Buy Signal                                   |
//+------------------------------------------------------------------+
bool GenerateAdvancedSignal(MultiTimeFrameData &mtf, PriceActionSignal &pas, int bar,
                            double close, double high, double low) {
    //--- Requirement 1: H4 and D1 must be in uptrend
    bool h4_uptrend = mtf.h4_ema_fast > mtf.h4_ema_slow;
    bool d1_uptrend = mtf.d1_ema_fast > mtf.d1_ema_slow;

    if (!h4_uptrend || !d1_uptrend) return false;

    //--- Requirement 2: H1 RSI must be oversold or recovering
    bool h1_oversold = mtf.h1_rsi < 35;

    //--- Requirement 3: H1 MACD bullish crossover
    bool h1_macd_bullish = mtf.h1_macd > mtf.h1_macd_signal;

    //--- Requirement 4: Price action confirmation
    bool price_action_confirm = pas.pinbar_buy || pas.engulfing_buy ||
                               (close < mtf.h1_ema_fast && low < pas.support);

    return (h1_oversold || h1_macd_bullish) && price_action_confirm;
}

//+------------------------------------------------------------------+
//| Generate Advanced Sell Signal                                  |
//+------------------------------------------------------------------+
bool GenerateAdvancedSellSignal(MultiTimeFrameData &mtf, PriceActionSignal &pas, int bar,
                                double close, double high, double low) {
    //--- Requirement 1: H4 and D1 must be in downtrend
    bool h4_downtrend = mtf.h4_ema_fast < mtf.h4_ema_slow;
    bool d1_downtrend = mtf.d1_ema_fast < mtf.d1_ema_slow;

    if (!h4_downtrend || !d1_downtrend) return false;

    //--- Requirement 2: H1 RSI must be overbought or declining
    bool h1_overbought = mtf.h1_rsi > 65;

    //--- Requirement 3: H1 MACD bearish crossover
    bool h1_macd_bearish = mtf.h1_macd < mtf.h1_macd_signal;

    //--- Requirement 4: Price action confirmation
    bool price_action_confirm = pas.pinbar_sell || pas.engulfing_sell ||
                               (close > mtf.h1_ema_fast && high > pas.resistance);

    return (h1_overbought || h1_macd_bearish) && price_action_confirm;
}

//+------------------------------------------------------------------+

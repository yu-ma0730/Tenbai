//+------------------------------------------------------------------+
//| XAUUSD Price Action Analysis Indicator                           |
//| Advanced Candlestick Pattern Recognition                         |
//+------------------------------------------------------------------+
#property copyright "Professional Trader 2024"
#property link      "https://github.com/yu-ma0730/xauusdtool"
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 10
#property indicator_plots   10

//--- Plot definitions
#property indicator_label1  "Pinbar Buy"
#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrLimeGreen
#property indicator_width1  3

#property indicator_label2  "Pinbar Sell"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrOrangeRed
#property indicator_width2  3

#property indicator_label3  "Engulfing Buy"
#property indicator_type3   DRAW_ARROW
#property indicator_color3  clrGreen
#property indicator_width3  2

#property indicator_label4  "Engulfing Sell"
#property indicator_type4   DRAW_ARROW
#property indicator_color4  clrRed
#property indicator_width4  2

#property indicator_label5  "Inside Bar"
#property indicator_type5   DRAW_ARROW
#property indicator_color5  clrBlue
#property indicator_width5  2

#property indicator_label6  "Support Level"
#property indicator_type6   DRAW_LINE
#property indicator_color6  clrGreen
#property indicator_width6  1
#property indicator_style6  STYLE_DASHED

#property indicator_label7  "Resistance Level"
#property indicator_type7   DRAW_LINE
#property indicator_color7  clrRed
#property indicator_width7  1
#property indicator_style7  STYLE_DASHED

#property indicator_label8  "Consolidation Zone"
#property indicator_type8   DRAW_FILLING
#property indicator_color8  clrYellow

#property indicator_label9  "Volume Confirmation"
#property indicator_type9   DRAW_HISTOGRAM
#property indicator_color9  clrGray

#property indicator_label10 "Pattern Strength"
#property indicator_type10  DRAW_LINE
#property indicator_color10 clrGoldenrod
#property indicator_width10 2

//--- Input Parameters
input int     Swing_Period = 20;
input double  Pinbar_Ratio = 2.5;      // ウィック/本体の比率
input int     Consolidation_Bars = 5;
input bool    ShowPatterns = true;
input bool    ShowLevels = true;

//--- Buffers
double PinbarBuy[];
double PinbarSell[];
double EngulfingBuy[];
double EngulfingSell[];
double InsideBar[];
double SupportLevel[];
double ResistanceLevel[];
double ConsolidationZone[];
double VolumeConfirm[];
double PatternStrength[];

//+------------------------------------------------------------------+
//| Initialization                                                  |
//+------------------------------------------------------------------+
int OnInit() {
    SetIndexBuffer(0, PinbarBuy, INDICATOR_DATA);
    SetIndexBuffer(1, PinbarSell, INDICATOR_DATA);
    SetIndexBuffer(2, EngulfingBuy, INDICATOR_DATA);
    SetIndexBuffer(3, EngulfingSell, INDICATOR_DATA);
    SetIndexBuffer(4, InsideBar, INDICATOR_DATA);
    SetIndexBuffer(5, SupportLevel, INDICATOR_DATA);
    SetIndexBuffer(6, ResistanceLevel, INDICATOR_DATA);
    SetIndexBuffer(7, ConsolidationZone, INDICATOR_DATA);
    SetIndexBuffer(8, VolumeConfirm, INDICATOR_DATA);
    SetIndexBuffer(9, PatternStrength, INDICATOR_DATA);

    PlotIndexSetInteger(0, PLOT_ARROW, 233); // Up arrow
    PlotIndexSetInteger(1, PLOT_ARROW, 234); // Down arrow
    PlotIndexSetInteger(2, PLOT_ARROW, 233); // Up arrow
    PlotIndexSetInteger(3, PLOT_ARROW, 234); // Down arrow
    PlotIndexSetInteger(4, PLOT_ARROW, 46);  // Point

    IndicatorSetString(INDICATOR_SHORTNAME, "Price Action Patterns");
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Main calculation                                                |
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

    ArraySetAsSeries(open, true);
    ArraySetAsSeries(high, true);
    ArraySetAsSeries(low, true);
    ArraySetAsSeries(close, true);
    ArraySetAsSeries(tick_volume, true);

    for (int i = limit - 1; i >= 1; i--) {
        PinbarBuy[i] = 0;
        PinbarSell[i] = 0;
        EngulfingBuy[i] = 0;
        EngulfingSell[i] = 0;
        InsideBar[i] = 0;

        //--- Detect Pinbar Pattern
        if (IsPinbarBuy(open, high, low, close, i)) {
            PinbarBuy[i] = low[i] - (high[i] - low[i]) * 0.5;
            PatternStrength[i] = 3;
        } else if (IsPinbarSell(open, high, low, close, i)) {
            PinbarSell[i] = high[i] + (high[i] - low[i]) * 0.5;
            PatternStrength[i] = 3;
        }

        //--- Detect Engulfing Pattern
        if (IsEngulfingBuy(open, high, low, close, i)) {
            EngulfingBuy[i] = low[i] - (high[i] - low[i]) * 0.3;
            PatternStrength[i] = 2;
        } else if (IsEngulfingSell(open, high, low, close, i)) {
            EngulfingSell[i] = high[i] + (high[i] - low[i]) * 0.3;
            PatternStrength[i] = 2;
        }

        //--- Detect Inside Bar
        if (IsInsideBar(high, low, i)) {
            InsideBar[i] = (high[i] + low[i]) / 2;
            PatternStrength[i] = 1;
        }

        //--- Calculate Support/Resistance
        SupportLevel[i] = CalculateSupport(low, i, Swing_Period);
        ResistanceLevel[i] = CalculateResistance(high, i, Swing_Period);

        //--- Detect Consolidation Zone
        if (IsConsolidation(high, low, i, Consolidation_Bars)) {
            ConsolidationZone[i] = (high[i] + low[i]) / 2;
        } else {
            ConsolidationZone[i] = 0;
        }

        //--- Check Volume Confirmation
        if (i > 0) {
            if (tick_volume[i] > tick_volume[i + 1] * 1.5) {
                VolumeConfirm[i] = tick_volume[i];
            } else {
                VolumeConfirm[i] = 0;
            }
        }
    }

    return rates_total;
}

//+------------------------------------------------------------------+
//| Pinbar Buy Detection                                            |
//+------------------------------------------------------------------+
bool IsPinbarBuy(const double &open[], const double &high[], const double &low[],
                 const double &close[], int bar) {
    if (bar < 1) return false;

    double h = high[bar];
    double l = low[bar];
    double o = open[bar];
    double c = close[bar];

    //--- Lower wick must be significant
    double lower_wick = MathMin(o, c) - l;
    double upper_wick = h - MathMax(o, c);
    double body = MathAbs(c - o);

    //--- Bullish pinbar: close near high, long lower wick
    if (lower_wick > body * Pinbar_Ratio && c > o && lower_wick > upper_wick * 2) {
        //--- Confirmation: previous bar should be down or neutral
        if (close[bar + 1] < open[bar + 1] || close[bar + 1] < close[bar]) {
            return true;
        }
    }

    return false;
}

//+------------------------------------------------------------------+
//| Pinbar Sell Detection                                           |
//+------------------------------------------------------------------+
bool IsPinbarSell(const double &open[], const double &high[], const double &low[],
                  const double &close[], int bar) {
    if (bar < 1) return false;

    double h = high[bar];
    double l = low[bar];
    double o = open[bar];
    double c = close[bar];

    //--- Upper wick must be significant
    double upper_wick = h - MathMax(o, c);
    double lower_wick = MathMin(o, c) - l;
    double body = MathAbs(c - o);

    //--- Bearish pinbar: close near low, long upper wick
    if (upper_wick > body * Pinbar_Ratio && c < o && upper_wick > lower_wick * 2) {
        //--- Confirmation: previous bar should be up or neutral
        if (close[bar + 1] > open[bar + 1] || close[bar + 1] > close[bar]) {
            return true;
        }
    }

    return false;
}

//+------------------------------------------------------------------+
//| Engulfing Buy Detection                                         |
//+------------------------------------------------------------------+
bool IsEngulfingBuy(const double &open[], const double &high[], const double &low[],
                    const double &close[], int bar) {
    if (bar < 1) return false;

    //--- Previous bar must be bearish
    if (close[bar + 1] >= open[bar + 1]) return false;

    //--- Current bar must be bullish and engulf previous
    if (close[bar] <= open[bar]) return false;
    if (open[bar] < close[bar + 1] && close[bar] > open[bar + 1]) {
        return true;
    }

    return false;
}

//+------------------------------------------------------------------+
//| Engulfing Sell Detection                                        |
//+------------------------------------------------------------------+
bool IsEngulfingSell(const double &open[], const double &high[], const double &low[],
                     const double &close[], int bar) {
    if (bar < 1) return false;

    //--- Previous bar must be bullish
    if (close[bar + 1] <= open[bar + 1]) return false;

    //--- Current bar must be bearish and engulf previous
    if (close[bar] >= open[bar]) return false;
    if (open[bar] > close[bar + 1] && close[bar] < open[bar + 1]) {
        return true;
    }

    return false;
}

//+------------------------------------------------------------------+
//| Inside Bar Detection                                            |
//+------------------------------------------------------------------+
bool IsInsideBar(const double &high[], const double &low[], int bar) {
    if (bar < 1) return false;

    double prev_high = high[bar + 1];
    double prev_low = low[bar + 1];
    double curr_high = high[bar];
    double curr_low = low[bar];

    //--- Current bar is completely inside previous bar
    return (curr_high < prev_high && curr_low > prev_low);
}

//+------------------------------------------------------------------+
//| Calculate Support Level (Swing Low)                             |
//+------------------------------------------------------------------+
double CalculateSupport(const double &low[], int bar, int period) {
    double support = low[bar];

    for (int i = bar; i < bar + period && i < ArraySize(low); i++) {
        if (low[i] < support) support = low[i];
    }

    return support;
}

//+------------------------------------------------------------------+
//| Calculate Resistance Level (Swing High)                         |
//+------------------------------------------------------------------+
double CalculateResistance(const double &high[], int bar, int period) {
    double resistance = high[bar];

    for (int i = bar; i < bar + period && i < ArraySize(high); i++) {
        if (high[i] > resistance) resistance = high[i];
    }

    return resistance;
}

//+------------------------------------------------------------------+
//| Detect Consolidation Zone                                       |
//+------------------------------------------------------------------+
bool IsConsolidation(const double &high[], const double &low[], int bar, int bars) {
    if (bar < bars) return false;

    double h = high[bar];
    double l = low[bar];
    double range = h - l;

    for (int i = 1; i < bars; i++) {
        double prev_range = high[bar - i] - low[bar - i];
        if (prev_range > range * 1.5) return false;
    }

    return true;
}

//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| XAUUSD Professional Signal Indicator                             |
//| Real-time Chart Signal Display                                   |
//+------------------------------------------------------------------+
#property copyright "Professional Trader 2024"
#property link      "https://github.com/yu-ma0730/xauusdtool"
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 8
#property indicator_plots   8

//--- Plot definitions
#property indicator_label1  "Buy Signal"
#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrGreen
#property indicator_width1  2

#property indicator_label2  "Sell Signal"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrRed
#property indicator_width2  2

#property indicator_label3  "RSI Value"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrBlue
#property indicator_width3  1

#property indicator_label4  "MACD Line"
#property indicator_type4   DRAW_LINE
#property indicator_color4  clrOrange
#property indicator_width4  1

#property indicator_label5  "MACD Signal"
#property indicator_type5   DRAW_LINE
#property indicator_color5  clrMagenta
#property indicator_width5  1

#property indicator_label6  "EMA Fast"
#property indicator_type6   DRAW_LINE
#property indicator_color6  clrDodgerBlue
#property indicator_width6  2

#property indicator_label7  "EMA Slow"
#property indicator_type7   DRAW_LINE
#property indicator_color7  clrCrimson
#property indicator_width7  2

#property indicator_label8  "Support/Resistance"
#property indicator_type8   DRAW_LINE
#property indicator_color8  clrGray
#property indicator_width8  1

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

//--- Buffers
double BuySignalBuffer[];
double SellSignalBuffer[];
double RSIBuffer[];
double MACDBuffer[];
double MACDSignalBuffer[];
double EMAFastBuffer[];
double EMASlowBuffer[];
double SRBuffer[];

//--- Handles
int rsi_handle = INVALID_HANDLE;
int macd_handle = INVALID_HANDLE;
int ema_fast_handle = INVALID_HANDLE;
int ema_slow_handle = INVALID_HANDLE;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                        |
//+------------------------------------------------------------------+
int OnInit() {
    //--- Bind buffers
    SetIndexBuffer(0, BuySignalBuffer, INDICATOR_DATA);
    SetIndexBuffer(1, SellSignalBuffer, INDICATOR_DATA);
    SetIndexBuffer(2, RSIBuffer, INDICATOR_DATA);
    SetIndexBuffer(3, MACDBuffer, INDICATOR_DATA);
    SetIndexBuffer(4, MACDSignalBuffer, INDICATOR_DATA);
    SetIndexBuffer(5, EMAFastBuffer, INDICATOR_DATA);
    SetIndexBuffer(6, EMASlowBuffer, INDICATOR_DATA);
    SetIndexBuffer(7, SRBuffer, INDICATOR_DATA);

    //--- Set arrow codes
    PlotIndexSetInteger(0, PLOT_ARROW, 233); // Up arrow
    PlotIndexSetInteger(1, PLOT_ARROW, 234); // Down arrow

    //--- Create handles
    rsi_handle = iRSI(Symbol(), Period(), RSI_Period, PRICE_CLOSE);
    if (rsi_handle == INVALID_HANDLE) {
        Print("Error creating RSI handle");
        return INIT_FAILED;
    }

    macd_handle = iMACD(Symbol(), Period(), MACD_Fast, MACD_Slow, MACD_Signal, PRICE_CLOSE);
    if (macd_handle == INVALID_HANDLE) {
        Print("Error creating MACD handle");
        return INIT_FAILED;
    }

    ema_fast_handle = iMA(Symbol(), Period(), EMA_Fast, 0, MODE_EMA, PRICE_CLOSE);
    if (ema_fast_handle == INVALID_HANDLE) {
        Print("Error creating EMA Fast handle");
        return INIT_FAILED;
    }

    ema_slow_handle = iMA(Symbol(), Period(), EMA_Slow, 0, MODE_EMA, PRICE_CLOSE);
    if (ema_slow_handle == INVALID_HANDLE) {
        Print("Error creating EMA Slow handle");
        return INIT_FAILED;
    }

    IndicatorSetString(INDICATOR_SHORTNAME, "XAUUSD Professional Signals");
    return INIT_SUCCEEDED;
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

    //--- Copy data
    double rsi_values[], macd_values[], macd_signals[], ema_fast[], ema_slow[];
    ArraySetAsSeries(rsi_values, true);
    ArraySetAsSeries(macd_values, true);
    ArraySetAsSeries(macd_signals, true);
    ArraySetAsSeries(ema_fast, true);
    ArraySetAsSeries(ema_slow, true);

    CopyBuffer(rsi_handle, 0, 0, limit, rsi_values);
    CopyBuffer(macd_handle, 0, 0, limit, macd_values);
    CopyBuffer(macd_handle, 1, 0, limit, macd_signals);
    CopyBuffer(ema_fast_handle, 0, 0, limit, ema_fast);
    CopyBuffer(ema_slow_handle, 0, 0, limit, ema_slow);

    //--- Process bars
    for (int i = limit - 1; i >= 0; i--) {
        RSIBuffer[i] = rsi_values[i] / 100.0 * close[i]; // Scale RSI to price
        MACDBuffer[i] = macd_values[i];
        MACDSignalBuffer[i] = macd_signals[i];
        EMAFastBuffer[i] = ema_fast[i];
        EMASlowBuffer[i] = ema_slow[i];

        //--- Calculate Support/Resistance
        SRBuffer[i] = CalculateSR(high, low, i, Support_Resistance_Period);

        //--- Generate Buy Signal
        if (i < rates_total - 1) {
            bool buy = (rsi_values[i] < RSI_Oversold &&
                       macd_values[i] > macd_signals[i] &&
                       close[i] < ema_fast[i] &&
                       ema_fast[i] > ema_slow[i]);

            if (buy) {
                BuySignalBuffer[i] = low[i] - (high[i] - low[i]) * 0.5;
            } else {
                BuySignalBuffer[i] = 0;
            }

            //--- Generate Sell Signal
            bool sell = (rsi_values[i] > RSI_Overbought &&
                        macd_values[i] < macd_signals[i] &&
                        close[i] > ema_fast[i] &&
                        ema_fast[i] < ema_slow[i]);

            if (sell) {
                SellSignalBuffer[i] = high[i] + (high[i] - low[i]) * 0.5;
            } else {
                SellSignalBuffer[i] = 0;
            }
        }
    }

    return rates_total;
}

//+------------------------------------------------------------------+
//| Deinitialization                                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    if (rsi_handle != INVALID_HANDLE) IndicatorRelease(rsi_handle);
    if (macd_handle != INVALID_HANDLE) IndicatorRelease(macd_handle);
    if (ema_fast_handle != INVALID_HANDLE) IndicatorRelease(ema_fast_handle);
    if (ema_slow_handle != INVALID_HANDLE) IndicatorRelease(ema_slow_handle);
}

//+------------------------------------------------------------------+
//| Calculate Support/Resistance Levels                             |
//+------------------------------------------------------------------+
double CalculateSR(const double &high[], const double &low[], int bar, int period) {
    double highest = 0, lowest = 99999;

    for (int i = bar; i < bar + period && i < ArraySize(high); i++) {
        if (high[i] > highest) highest = high[i];
        if (low[i] < lowest) lowest = low[i];
    }

    return (highest + lowest) / 2.0;
}

//+------------------------------------------------------------------+

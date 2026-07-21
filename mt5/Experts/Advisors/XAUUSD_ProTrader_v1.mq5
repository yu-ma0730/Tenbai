//+------------------------------------------------------------------+
//| XAUUSD Professional Trading EA v1.0                              |
//| Real-time Signal Generation for Professional Traders             |
//| Optimized for Gold (XAUUSD) Trading                              |
//+------------------------------------------------------------------+
#property copyright "Professional Trader 2024"
#property link      "https://github.com/yu-ma0730/xauusdtool"
#property version   "1.00"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>

//--- Input Parameters
input double  RSI_Overbought = 70.0;           // RSI Overbought Level
input double  RSI_Oversold = 30.0;            // RSI Oversold Level
input int     RSI_Period = 14;                // RSI Period
input int     MACD_Fast = 12;                 // MACD Fast Period
input int     MACD_Slow = 26;                 // MACD Slow Period
input int     MACD_Signal = 9;                // MACD Signal Period
input int     EMA_Fast = 20;                  // Fast EMA Period
input int     EMA_Slow = 50;                  // Slow EMA Period
input double  Risk_Percent = 2.0;             // Risk % per Trade
input int     MinBarsSinceSignal = 3;         // Min bars between signals
input bool    UseSoundAlert = true;           // Use sound alerts
input bool    UseNotification = true;         // Use notifications

//--- Global Variables
CTrade trade;
CSymbolInfo symbol;
int rsi_handle = INVALID_HANDLE;
int macd_handle = INVALID_HANDLE;
int ema_fast_handle = INVALID_HANDLE;
int ema_slow_handle = INVALID_HANDLE;
int bars_since_buy_signal = 999;
int bars_since_sell_signal = 999;
double last_close = 0;

struct SignalData {
    bool buy_signal;
    bool sell_signal;
    double rsi_value;
    double macd_value;
    double macd_signal;
    double ema_fast;
    double ema_slow;
    double close_price;
};

//+------------------------------------------------------------------+
//| Expert initialization function                                  |
//+------------------------------------------------------------------+
int OnInit() {
    //--- Initialize symbol
    if (!symbol.Name(Symbol())) {
        Print("Error: Symbol not found");
        return INIT_FAILED;
    }

    //--- Create indicator handles
    rsi_handle = iRSI(Symbol(), PERIOD_CURRENT, RSI_Period, PRICE_CLOSE);
    if (rsi_handle == INVALID_HANDLE) {
        Print("Error creating RSI handle");
        return INIT_FAILED;
    }

    macd_handle = iMACD(Symbol(), PERIOD_CURRENT, MACD_Fast, MACD_Slow, MACD_Signal, PRICE_CLOSE);
    if (macd_handle == INVALID_HANDLE) {
        Print("Error creating MACD handle");
        return INIT_FAILED;
    }

    ema_fast_handle = iMA(Symbol(), PERIOD_CURRENT, EMA_Fast, 0, MODE_EMA, PRICE_CLOSE);
    if (ema_fast_handle == INVALID_HANDLE) {
        Print("Error creating Fast EMA handle");
        return INIT_FAILED;
    }

    ema_slow_handle = iMA(Symbol(), PERIOD_CURRENT, EMA_Slow, 0, MODE_EMA, PRICE_CLOSE);
    if (ema_slow_handle == INVALID_HANDLE) {
        Print("Error creating Slow EMA handle");
        return INIT_FAILED;
    }

    Print("XAUUSD Professional Trading EA Initialized Successfully");
    Print("Symbol: ", Symbol(), " | Timeframe: ", Period());
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    //--- Release indicator handles
    if (rsi_handle != INVALID_HANDLE) IndicatorRelease(rsi_handle);
    if (macd_handle != INVALID_HANDLE) IndicatorRelease(macd_handle);
    if (ema_fast_handle != INVALID_HANDLE) IndicatorRelease(ema_fast_handle);
    if (ema_slow_handle != INVALID_HANDLE) IndicatorRelease(ema_slow_handle);

    Print("EA Deinitialized");
}

//+------------------------------------------------------------------+
//| Expert tick function                                            |
//+------------------------------------------------------------------+
void OnTick() {
    //--- Get current signal data
    SignalData signal = GetSignalData();

    if (signal.buy_signal && bars_since_buy_signal >= MinBarsSinceSignal) {
        PrintSignal("BUY SIGNAL", signal);
        AlertSignal("BUY", signal);
        bars_since_buy_signal = 0;
    }

    if (signal.sell_signal && bars_since_sell_signal >= MinBarsSinceSignal) {
        PrintSignal("SELL SIGNAL", signal);
        AlertSignal("SELL", signal);
        bars_since_sell_signal = 0;
    }

    //--- Increment bar counters
    bars_since_buy_signal++;
    bars_since_sell_signal++;
}

//+------------------------------------------------------------------+
//| Get Signal Data                                                 |
//+------------------------------------------------------------------+
SignalData GetSignalData() {
    SignalData signal;
    signal.buy_signal = false;
    signal.sell_signal = false;

    //--- Get current bar data
    double close_prices[];
    ArraySetAsSeries(close_prices, true);
    CopyClose(Symbol(), PERIOD_CURRENT, 0, 3, close_prices);
    signal.close_price = close_prices[0];

    //--- Get RSI values
    double rsi_values[];
    ArraySetAsSeries(rsi_values, true);
    CopyBuffer(rsi_handle, 0, 0, 3, rsi_values);
    signal.rsi_value = rsi_values[0];

    //--- Get MACD values
    double macd_values[], macd_signals[];
    ArraySetAsSeries(macd_values, true);
    ArraySetAsSeries(macd_signals, true);
    CopyBuffer(macd_handle, 0, 0, 3, macd_values);
    CopyBuffer(macd_handle, 1, 0, 3, macd_signals);
    signal.macd_value = macd_values[0];
    signal.macd_signal = macd_signals[0];

    //--- Get EMA values
    double ema_fast[], ema_slow[];
    ArraySetAsSeries(ema_fast, true);
    ArraySetAsSeries(ema_slow, true);
    CopyBuffer(ema_fast_handle, 0, 0, 3, ema_fast);
    CopyBuffer(ema_slow_handle, 0, 0, 3, ema_slow);
    signal.ema_fast = ema_fast[0];
    signal.ema_slow = ema_slow[0];

    //--- BUY SIGNAL Logic
    // Condition 1: RSI < 30 (Oversold)
    // Condition 2: MACD > Signal Line (Bullish crossover)
    // Condition 3: Price below Fast EMA
    // Condition 4: Fast EMA > Slow EMA (Uptrend)
    if (signal.rsi_value < RSI_Oversold &&
        signal.macd_value > signal.macd_signal &&
        signal.close_price < signal.ema_fast &&
        signal.ema_fast > signal.ema_slow) {
        signal.buy_signal = true;
    }

    //--- SELL SIGNAL Logic
    // Condition 1: RSI > 70 (Overbought)
    // Condition 2: MACD < Signal Line (Bearish crossover)
    // Condition 3: Price above Fast EMA
    // Condition 4: Fast EMA < Slow EMA (Downtrend)
    if (signal.rsi_value > RSI_Overbought &&
        signal.macd_value < signal.macd_signal &&
        signal.close_price > signal.ema_fast &&
        signal.ema_fast < signal.ema_slow) {
        signal.sell_signal = true;
    }

    return signal;
}

//+------------------------------------------------------------------+
//| Print Signal Information                                        |
//+------------------------------------------------------------------+
void PrintSignal(string signal_type, SignalData &signal) {
    string msg = StringFormat(
        "%s Generated at %s\n"
        "Price: %.2f | RSI: %.2f\n"
        "MACD: %.4f | Signal: %.4f\n"
        "EMA Fast: %.2f | EMA Slow: %.2f",
        signal_type,
        TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES),
        signal.close_price,
        signal.rsi_value,
        signal.macd_value,
        signal.macd_signal,
        signal.ema_fast,
        signal.ema_slow
    );

    Print(msg);
}

//+------------------------------------------------------------------+
//| Alert Signal                                                    |
//+------------------------------------------------------------------+
void AlertSignal(string signal_type, SignalData &signal) {
    string alert_msg = StringFormat(
        "%s SIGNAL - %s\nPrice: %.2f | RSI: %.2f\nMACD: %.4f",
        signal_type,
        Symbol(),
        signal.close_price,
        signal.rsi_value,
        signal.macd_value
    );

    if (UseSoundAlert) {
        Alert(alert_msg);
    }

    if (UseNotification) {
        SendNotification(alert_msg);
    }
}

//+------------------------------------------------------------------+

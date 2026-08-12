//+------------------------------------------------------------------+
//|                    P4 Signal EA - XAUUSD Pullback Edition         |
//|              Pullback Selling Strategy for Gold                   |
//+------------------------------------------------------------------+
#property copyright "P4 Method - XAUUSD Pullback"
#property link      ""
#property version   "1.00"

//--- Input parameters
input double RiskPercent = 0.75;             // Risk per trade (%)
input int EMA10_Period = 10;
input int EMA20_Period = 20;
input int EMA40_Period = 40;
input int EMA80_Period = 80;
input double ResistanceLevel = 4175.67;     // Resistance point②
input double EMA_Divergence_Threshold = 0.15; // 0.15% for Gold
input bool EnableTrading = false;            // Enable automatic trading
input bool DetectPullbackSignals = true;    // Detect pullback entry signals
input bool SkipNewsTime = true;             // Skip news time
input int AlertLevel = 1;                    // Alert level: 0=none, 1=important only, 2=all

//--- Pullback resistance points
enum ResistanceType
{
   RESISTANCE_EMA40_1H = 1,      // 1-hour EMA40
   RESISTANCE_CUSTOM_4175 = 2,   // 4175.67 level
   RESISTANCE_EMA80_1H = 3       // 1-hour EMA80
};

//--- Global variables
int ema10Handle_1H, ema20Handle_1H, ema40Handle_1H, ema80Handle_1H;  // 1-hour handles
int ema10Handle_4H, ema20Handle_4H, ema40Handle_4H, ema80Handle_4H;  // 4-hour handles
ulong lastAlertTime = 0;
int newsSkipHours[] = {14, 15, 16};  // US time (14:00-17:00)

struct TradeInfo
{
   ulong ticket;
   datetime entryTime;
   double entryPrice;
   double resistanceLevel;
   double stopLoss;
   double takeProfit;
   double riskAmount;
   int resistanceType;
};

TradeInfo activeTrade = {0, 0, 0, 0, 0, 0, 0, 0};

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Create handles for 1-hour timeframe
   ema10Handle_1H = iMA(_Symbol, PERIOD_H1, EMA10_Period, 0, MODE_EMA);
   ema20Handle_1H = iMA(_Symbol, PERIOD_H1, EMA20_Period, 0, MODE_EMA);
   ema40Handle_1H = iMA(_Symbol, PERIOD_H1, EMA40_Period, 0, MODE_EMA);
   ema80Handle_1H = iMA(_Symbol, PERIOD_H1, EMA80_Period, 0, MODE_EMA);

   // Create handles for 4-hour timeframe (PO confirmation)
   ema10Handle_4H = iMA(_Symbol, PERIOD_H4, EMA10_Period, 0, MODE_EMA);
   ema20Handle_4H = iMA(_Symbol, PERIOD_H4, EMA20_Period, 0, MODE_EMA);
   ema40Handle_4H = iMA(_Symbol, PERIOD_H4, EMA40_Period, 0, MODE_EMA);
   ema80Handle_4H = iMA(_Symbol, PERIOD_H4, EMA80_Period, 0, MODE_EMA);

   if (ema10Handle_1H == INVALID_HANDLE || ema10Handle_4H == INVALID_HANDLE)
   {
      Print("Error creating indicator handles");
      return INIT_FAILED;
   }

   Print("P4 Signal EA - XAUUSD Pullback Edition initialized");
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Check if we should skip due to news
   if (SkipNewsTime && IsNewsTime())
   {
      SendAlert("Skipping trade - Economic news time", 2);
      return;
   }

   // Check 4-hour Perfect Order (PO)
   int po4H = Check4HPerfectOrder();
   if (po4H != -1)  // Only SHORT when 4H PO is for SHORT
   {
      SendAlert("4H PO not in SHORT position - Skipping", 2);
      return;
   }

   // Get current price and 1-hour EMA levels
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ema40_1H = GetEMA(ema40Handle_1H, 0);
   double ema80_1H = GetEMA(ema80Handle_1H, 0);
   double ema10_1H = GetEMA(ema10Handle_1H, 0);

   // Check for pullback entry signals
   if (DetectPullbackSignals && activeTrade.ticket == 0)
   {
      // Check resistance approach
      if (currentPrice >= ema40_1H - 50 * _Point && currentPrice <= ema40_1H + 50 * _Point)
      {
         CheckPullbackShortEntry(RESISTANCE_EMA40_1H, ema40_1H, currentPrice, ema10_1H);
      }
      else if (currentPrice >= ResistanceLevel - 50 * _Point && currentPrice <= ResistanceLevel + 50 * _Point)
      {
         CheckPullbackShortEntry(RESISTANCE_CUSTOM_4175, ResistanceLevel, currentPrice, ema10_1H);
      }
      else if (currentPrice >= ema80_1H - 50 * _Point && currentPrice <= ema80_1H + 50 * _Point)
      {
         CheckPullbackShortEntry(RESISTANCE_EMA80_1H, ema80_1H, currentPrice, ema10_1H);
      }
   }

   // Monitor active trade
   if (activeTrade.ticket > 0)
   {
      MonitorPullbackTrade(po4H, currentPrice, ema80_1H);
   }

   // Check for EMA80 breakout (trend reversal warning)
   if (currentPrice > ema80_1H + 100 * _Point)
   {
      SendAlert("WARNING: Price broke above 1H EMA80 - Potential trend reversal!", 1);
      if (activeTrade.ticket > 0)
      {
         ClosePullbackTrade("EMA80 breakout - Trend reversal warning");
      }
   }
}

//+------------------------------------------------------------------+
//| Check 4-hour Perfect Order                                       |
//+------------------------------------------------------------------+
int Check4HPerfectOrder()
{
   double ema10 = GetEMA(ema10Handle_4H, 0);
   double ema20 = GetEMA(ema20Handle_4H, 0);
   double ema40 = GetEMA(ema40Handle_4H, 0);
   double ema80 = GetEMA(ema80Handle_4H, 0);

   // SHORT: EMA80 > EMA40 > EMA20 > EMA10
   if (ema80 > ema40 && ema40 > ema20 && ema20 > ema10)
      return -1;  // SHORT condition met

   return 0;  // PO broken
}

//+------------------------------------------------------------------+
//| Check Pullback Short Entry                                       |
//+------------------------------------------------------------------+
void CheckPullbackShortEntry(int resistanceType, double resistanceLevel,
                             double currentPrice, double ema10_1H)
{
   // Check EMA divergence
   double divergence = MathAbs(currentPrice - ema10_1H) / ema10_1H;
   if (divergence > EMA_Divergence_Threshold)
   {
      SendAlert("EMA divergence too high - Skipping entry at " +
                DoubleToString(resistanceLevel, 2), 2);
      return;
   }

   // Detect pullback signals
   bool hasWickRejection = DetectUpperWick();      // Upper wick rejection
   bool hasPinbarTop = DetectPinbarTop();          // Pinbar at top
   bool hasInversePincer = DetectInversePincer();  // Inverse pincer (毛抜き天井)

   if (hasWickRejection || hasPinbarTop || hasInversePincer)
   {
      string signalType = hasWickRejection ? "Upper Wick Rejection" :
                         hasPinbarTop ? "Pinbar Top" : "Inverse Pincer";

      SendAlert("SHORT Entry Signal: " + signalType + " at " +
                DoubleToString(resistanceLevel, 2), 1);

      if (EnableTrading)
      {
         ExecuteShortTrade(resistanceType, resistanceLevel, currentPrice);
      }
   }
}

//+------------------------------------------------------------------+
//| Detect Upper Wick Rejection                                      |
//+------------------------------------------------------------------+
bool DetectUpperWick()
{
   // Upper wick: High - Close > (Close - Open) * 1.5
   double wickSize = High[0] - Close[0];
   double bodySize = Close[0] - Open[0];

   if (bodySize < 0) bodySize = -bodySize;

   return wickSize > bodySize * 1.5;
}

//+------------------------------------------------------------------+
//| Detect Pinbar at Top                                             |
//+------------------------------------------------------------------+
bool DetectPinbarTop()
{
   // Pinbar: small body at top with long lower wick
   double bodySize = MathAbs(Close[0] - Open[0]);
   double lowerWick = Close[0] - Low[0];
   if (lowerWick < 0) lowerWick = -lowerWick;

   return (bodySize < (High[0] - Low[0]) * 0.3) && (lowerWick > bodySize * 2);
}

//+------------------------------------------------------------------+
//| Detect Inverse Pincer (毛抜き天井)                               |
//+------------------------------------------------------------------+
bool DetectInversePincer()
{
   // Two consecutive candles with same/similar highs but different lows
   if (Bars(_Symbol, _Period) < 2) return false;

   double highDiff = MathAbs(High[0] - High[1]);
   double highAvg = (High[0] + High[1]) / 2;

   // Highs within 20 pips of each other
   return (highDiff < 20 * _Point) && (High[0] > Close[0]) && (High[1] > Close[1]);
}

//+------------------------------------------------------------------+
//| Execute Short Trade at Pullback                                  |
//+------------------------------------------------------------------+
void ExecuteShortTrade(int resistanceType, double resistanceLevel, double currentPrice)
{
   MqlTradeRequest request = {0};
   MqlTradeResult result = {0};

   // Stop loss above resistance + buffer
   double stopLoss = resistanceLevel + 100 * _Point;

   // Calculate risk amount
   double riskAmount = (AccountInfoDouble(ACCOUNT_BALANCE) * RiskPercent) / 100;
   double lotSize = riskAmount / ((stopLoss - currentPrice) / _Point * SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE));
   lotSize = NormalizeDouble(lotSize, 2);

   // Take profit at next support (conservative)
   double takeProfit = currentPrice - ((stopLoss - currentPrice) * 1.0);  // RR 1:1

   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = lotSize;
   request.type = ORDER_TYPE_SELL;
   request.price = currentPrice;
   request.sl = stopLoss;
   request.tp = takeProfit;
   request.deviation = 10;
   request.magic = 123457;
   request.comment = "P4 XAUUSD Pullback Short";

   if (OrderSend(request, result))
   {
      activeTrade.ticket = result.order;
      activeTrade.entryTime = TimeCurrent();
      activeTrade.entryPrice = currentPrice;
      activeTrade.resistanceLevel = resistanceLevel;
      activeTrade.stopLoss = stopLoss;
      activeTrade.takeProfit = takeProfit;
      activeTrade.resistanceType = resistanceType;
      activeTrade.riskAmount = riskAmount;

      Print("SHORT trade opened at ", currentPrice, " | Resistance: ", resistanceLevel);
   }
   else
   {
      Print("Error opening SHORT trade: ", GetLastError());
   }
}

//+------------------------------------------------------------------+
//| Monitor Pullback Trade                                            |
//+------------------------------------------------------------------+
void MonitorPullbackTrade(int po4H, double currentPrice, double ema80_1H)
{
   // If 4H PO breaks, close trade
   if (po4H == 0)
   {
      ClosePullbackTrade("4H Perfect Order broken");
      return;
   }

   // If price breaks above EMA80, close with warning
   if (currentPrice > ema80_1H)
   {
      ClosePullbackTrade("Price broke above 1H EMA80 - Trend reversal!");
      return;
   }
}

//+------------------------------------------------------------------+
//| Close Pullback Trade                                              |
//+------------------------------------------------------------------+
void ClosePullbackTrade(string reason = "")
{
   if (activeTrade.ticket == 0) return;

   MqlTradeRequest request = {0};
   MqlTradeResult result = {0};

   request.action = TRADE_ACTION_DEAL;
   request.position = activeTrade.ticket;
   request.symbol = _Symbol;
   request.deviation = 10;
   request.magic = 123457;

   request.type = ORDER_TYPE_BUY;
   request.volume = PositionGetDouble(POSITION_VOLUME);
   request.price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   if (OrderSend(request, result))
   {
      Print("Trade closed: ", reason);
      activeTrade.ticket = 0;
   }
   else
   {
      Print("Error closing trade: ", GetLastError());
   }
}

//+------------------------------------------------------------------+
//| Check if News Time (avoid trading)                               |
//+------------------------------------------------------------------+
bool IsNewsTime()
{
   if (!SkipNewsTime) return false;

   datetime now = TimeCurrent();
   int hour = TimeHour(now);

   // Skip 14:00-17:00 US time
   for (int i = 0; i < 3; i++)
   {
      if (hour == newsSkipHours[i])
         return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| Send Alert with Level Control                                    |
//+------------------------------------------------------------------+
void SendAlert(string message, int level = 1)
{
   if (AlertLevel == 0) return;  // No alerts
   if (AlertLevel == 1 && level > 1) return;  // Skip informational messages at level 1

   // Throttle alerts
   if (TimeCurrent() - lastAlertTime < 300) return;

   Alert(message);
   Print(message);
   lastAlertTime = TimeCurrent();
}

//+------------------------------------------------------------------+
//| Get EMA value                                                     |
//+------------------------------------------------------------------+
double GetEMA(int handle, int shift)
{
   double buffer[];
   ArraySetAsSeries(buffer, true);
   CopyBuffer(handle, 0, shift, 1, buffer);
   return buffer[0];
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   IndicatorRelease(ema10Handle_1H);
   IndicatorRelease(ema20Handle_1H);
   IndicatorRelease(ema40Handle_1H);
   IndicatorRelease(ema80Handle_1H);
   IndicatorRelease(ema10Handle_4H);
   IndicatorRelease(ema20Handle_4H);
   IndicatorRelease(ema40Handle_4H);
   IndicatorRelease(ema80Handle_4H);

   Print("P4 XAUUSD Pullback EA unloaded");
}

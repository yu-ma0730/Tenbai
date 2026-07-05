//+------------------------------------------------------------------+
//|                        P4 Signal EA                               |
//|              Expert Advisor for P4 Method Trading                 |
//+------------------------------------------------------------------+
#property copyright "P4 Method Signal Tool"
#property link      ""
#property version   "1.00"

//--- Input parameters
input double RiskPercent = 2.0;              // Risk per trade (%)
input double InitialRiskRewardRatio = 1.0;  // Initial RR ratio (1:1)
input int EMA10_Period = 10;
input int EMA20_Period = 20;
input int EMA40_Period = 40;
input int EMA80_Period = 80;
input int BB_Period = 20;
input double BB_Deviation = 2.0;
input double EMA_Divergence_Threshold = 0.003;  // 0.3% threshold
input bool CheckEMADivergence = true;        // Check EMA divergence
input bool CheckHighRejection = true;        // Check high rejection
input bool CheckShortTermWeakness = true;    // Check short-term weakness
input bool EnableTrading = false;            // Enable automatic trading
input bool UsePartialTakeProfit = true;      // Use trailing TP strategy
input double PartialTPRatio = 1.5;           // TP ratio for partial exit
input bool SendAlerts = true;                // Send alerts

//--- Global variables
int ema10Handle, ema20Handle, ema40Handle, ema80Handle;
int bbHandle;
ulong lastAlertTime = 0;
ulong lastTradeTime = 0;

struct TradeInfo
{
   ulong ticket;
   datetime entryTime;
   double entryPrice;
   double stopLoss;
   double takeProfit;
   double riskAmount;
   bool isLong;
   int tradeStage; // 0: initial, 1: BB broken, 2: partial TP hit
};

TradeInfo activeTrade = {0, 0, 0, 0, 0, 0, false, 0};

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Create indicator handles
   ema10Handle = iMA(_Symbol, PERIOD_CURRENT, EMA10_Period, 0, MODE_EMA);
   ema20Handle = iMA(_Symbol, PERIOD_CURRENT, EMA20_Period, 0, MODE_EMA);
   ema40Handle = iMA(_Symbol, PERIOD_CURRENT, EMA40_Period, 0, MODE_EMA);
   ema80Handle = iMA(_Symbol, PERIOD_CURRENT, EMA80_Period, 0, MODE_EMA);
   bbHandle = iBands(_Symbol, PERIOD_CURRENT, BB_Period, 0, BB_Deviation);

   if (ema10Handle == INVALID_HANDLE || ema20Handle == INVALID_HANDLE ||
       ema40Handle == INVALID_HANDLE || ema80Handle == INVALID_HANDLE ||
       bbHandle == INVALID_HANDLE)
   {
      Print("Error creating indicator handles");
      return INIT_FAILED;
   }

   Print("P4 Signal EA initialized on ", _Symbol, " ", _Period, " minutes");
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Get current prices and indicators
   double ema10 = GetEMA(ema10Handle, 0);
   double ema20 = GetEMA(ema20Handle, 0);
   double ema40 = GetEMA(ema40Handle, 0);
   double ema80 = GetEMA(ema80Handle, 0);

   double bbUpper = GetBBValue(bbHandle, 0, 0);
   double bbMiddle = GetBBValue(bbHandle, 1, 0);
   double bbLower = GetBBValue(bbHandle, 2, 0);

   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   int direction = CheckPerfectOrder(ema10, ema20, ema40, ema80);

   // Check and close active trade if conditions fail
   if (activeTrade.ticket > 0)
   {
      CheckTradeConditions(ema10, ema20, ema40, ema80);
      UpdateTrailingStop(currentPrice, bbUpper, bbLower);
   }

   // Generate signals
   if (direction == 1) // Perfect Order for LONG
   {
      CheckLongEntry(currentPrice, bbLower, ema80);
   }
   else if (direction == -1) // Perfect Order for SHORT
   {
      CheckShortEntry(currentPrice, bbUpper, ema80);
   }
}

//+------------------------------------------------------------------+
//| Check Perfect Order                                              |
//+------------------------------------------------------------------+
int CheckPerfectOrder(double ema10, double ema20, double ema40, double ema80)
{
   // LONG: EMA10 > EMA20 > EMA40 > EMA80
   if (ema10 > ema20 && ema20 > ema40 && ema40 > ema80)
      return 1;

   // SHORT: EMA80 > EMA40 > EMA20 > EMA10
   if (ema80 > ema40 && ema40 > ema20 && ema20 > ema10)
      return -1;

   return 0; // No perfect order
}

//+------------------------------------------------------------------+
//| Check Long Entry Signal                                          |
//+------------------------------------------------------------------+
void CheckLongEntry(double currentPrice, double bbLower, double ema80)
{
   static double prevPrice = 0;

   if (prevPrice == 0)
   {
      prevPrice = currentPrice;
      return;
   }

   // Check if price breaks above BB Lower
   if (currentPrice > bbLower && prevPrice <= bbLower)
   {
      SendAlert("LONG ENTRY SIGNAL on " + _Symbol);

      if (EnableTrading && activeTrade.ticket == 0)
      {
         ExecuteLongTrade(currentPrice, ema80);
      }
   }

   prevPrice = currentPrice;
}

//+------------------------------------------------------------------+
//| Check Short Entry Signal                                         |
//+------------------------------------------------------------------+
void CheckShortEntry(double currentPrice, double bbUpper, double ema80)
{
   static double prevPrice = 0;

   if (prevPrice == 0)
   {
      prevPrice = currentPrice;
      return;
   }

   // Check if price breaks below BB Upper
   if (currentPrice < bbUpper && prevPrice >= bbUpper)
   {
      // Additional confirmation checks for short entry
      double ema10 = GetEMA(ema10Handle, 0);
      bool hasEMADivergence = CheckEMADivergence && CalculateEMADivergence(currentPrice, ema10) > EMA_Divergence_Threshold;
      bool hasHighRejection = CheckHighRejection && IsHighRejection(50);
      bool hasWeaknesSignal = CheckShortTermWeakness && HasShortTermWeakness();

      // Generate signal with confidence level
      string signalReason = "SHORT: BB breakthrough";
      int confirmationCount = 0;

      if (hasEMADivergence)
      {
         signalReason += " + EMA Divergence";
         confirmationCount++;
      }
      if (hasHighRejection)
      {
         signalReason += " + High Rejection";
         confirmationCount++;
      }
      if (hasWeaknesSignal)
      {
         signalReason += " + Short-term Weakness";
         confirmationCount++;
      }

      SendAlert(signalReason + " on " + _Symbol);

      // Only execute if multiple confirmations OR high confidence signal
      if (EnableTrading && activeTrade.ticket == 0 && confirmationCount >= 1)
      {
         ExecuteShortTrade(currentPrice, ema80);
      }
   }

   prevPrice = currentPrice;
}

//+------------------------------------------------------------------+
//| Execute Long Trade                                               |
//+------------------------------------------------------------------+
void ExecuteLongTrade(double entryPrice, double ema80)
{
   MqlTradeRequest request = {0};
   MqlTradeResult result = {0};

   // Calculate stop loss (recent lowest point - this needs manual adjustment)
   double stopLoss = entryPrice - 50 * _Point; // Placeholder

   // Calculate risk amount
   double riskAmount = (AccountInfoDouble(ACCOUNT_BALANCE) * RiskPercent) / 100;
   double lotSize = riskAmount / ((entryPrice - stopLoss) / _Point * SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE));
   lotSize = NormalizeDouble(lotSize, 2);

   // Calculate take profit
   double takeProfit = entryPrice + ((entryPrice - stopLoss) * InitialRiskRewardRatio);

   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = lotSize;
   request.type = ORDER_TYPE_BUY;
   request.price = entryPrice;
   request.sl = stopLoss;
   request.tp = takeProfit;
   request.deviation = 10;
   request.magic = 123456;
   request.comment = "P4 Long Entry";

   if (OrderSend(request, result))
   {
      activeTrade.ticket = result.order;
      activeTrade.entryTime = TimeCurrent();
      activeTrade.entryPrice = entryPrice;
      activeTrade.stopLoss = stopLoss;
      activeTrade.takeProfit = takeProfit;
      activeTrade.riskAmount = riskAmount;
      activeTrade.isLong = true;
      activeTrade.tradeStage = 0;

      Print("LONG trade opened: ", result.order, " at ", entryPrice);
   }
   else
   {
      Print("Error opening LONG trade: ", GetLastError());
   }
}

//+------------------------------------------------------------------+
//| Execute Short Trade                                              |
//+------------------------------------------------------------------+
void ExecuteShortTrade(double entryPrice, double ema80)
{
   MqlTradeRequest request = {0};
   MqlTradeResult result = {0};

   // Calculate stop loss (recent highest point - this needs manual adjustment)
   double stopLoss = entryPrice + 50 * _Point; // Placeholder

   // Calculate risk amount
   double riskAmount = (AccountInfoDouble(ACCOUNT_BALANCE) * RiskPercent) / 100;
   double lotSize = riskAmount / ((stopLoss - entryPrice) / _Point * SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE));
   lotSize = NormalizeDouble(lotSize, 2);

   // Calculate take profit
   double takeProfit = entryPrice - ((stopLoss - entryPrice) * InitialRiskRewardRatio);

   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = lotSize;
   request.type = ORDER_TYPE_SELL;
   request.price = entryPrice;
   request.sl = stopLoss;
   request.tp = takeProfit;
   request.deviation = 10;
   request.magic = 123456;
   request.comment = "P4 Short Entry";

   if (OrderSend(request, result))
   {
      activeTrade.ticket = result.order;
      activeTrade.entryTime = TimeCurrent();
      activeTrade.entryPrice = entryPrice;
      activeTrade.stopLoss = stopLoss;
      activeTrade.takeProfit = takeProfit;
      activeTrade.riskAmount = riskAmount;
      activeTrade.isLong = false;
      activeTrade.tradeStage = 0;

      Print("SHORT trade opened: ", result.order, " at ", entryPrice);
   }
   else
   {
      Print("Error opening SHORT trade: ", GetLastError());
   }
}

//+------------------------------------------------------------------+
//| Check if trade conditions still valid                            |
//+------------------------------------------------------------------+
void CheckTradeConditions(double ema10, double ema20, double ema40, double ema80)
{
   // Close trade if Perfect Order breaks
   if (activeTrade.isLong)
   {
      // Long: if order reverses to short order, close
      if (ema80 > ema40 && ema40 > ema20 && ema20 > ema10)
      {
         CloseActiveTrade("Perfect Order reversal");
      }
   }
   else
   {
      // Short: if order reverses to long order, close
      if (ema10 > ema20 && ema20 > ema40 && ema40 > ema80)
      {
         CloseActiveTrade("Perfect Order reversal");
      }
   }
}

//+------------------------------------------------------------------+
//| Update Trailing Stop                                             |
//+------------------------------------------------------------------+
void UpdateTrailingStop(double currentPrice, double bbUpper, double bbLower)
{
   if (activeTrade.ticket == 0) return;

   MqlTradeRequest request = {0};
   MqlTradeResult result = {0};
   MqlPositionInfo posInfo;

   if (!PositionSelectByTicket(activeTrade.ticket))
      return;

   request.action = TRADE_ACTION_SLTP;
   request.position = activeTrade.ticket;
   request.symbol = _Symbol;

   if (activeTrade.isLong)
   {
      // Move SL to breakeven if price is above initial TP
      if (currentPrice > activeTrade.takeProfit && activeTrade.tradeStage == 0)
      {
         request.sl = activeTrade.entryPrice;
         activeTrade.tradeStage = 1;
      }
      // If BB is broken upward and RR > 1.5, move TP
      else if (currentPrice > bbUpper && activeTrade.tradeStage == 1)
      {
         request.tp = activeTrade.entryPrice + ((activeTrade.entryPrice - activeTrade.stopLoss) * PartialTPRatio);
         activeTrade.tradeStage = 2;
      }
   }
   else
   {
      // Move SL to breakeven if price is below initial TP
      if (currentPrice < activeTrade.takeProfit && activeTrade.tradeStage == 0)
      {
         request.sl = activeTrade.entryPrice;
         activeTrade.tradeStage = 1;
      }
      // If BB is broken downward and RR > 1.5, move TP
      else if (currentPrice < bbLower && activeTrade.tradeStage == 1)
      {
         request.tp = activeTrade.entryPrice - ((activeTrade.stopLoss - activeTrade.entryPrice) * PartialTPRatio);
         activeTrade.tradeStage = 2;
      }
   }

   if (request.sl != 0 || request.tp != 0)
   {
      OrderSend(request, result);
   }
}

//+------------------------------------------------------------------+
//| Close Active Trade                                               |
//+------------------------------------------------------------------+
void CloseActiveTrade(string reason = "")
{
   if (activeTrade.ticket == 0) return;

   MqlTradeRequest request = {0};
   MqlTradeResult result = {0};

   request.action = TRADE_ACTION_DEAL;
   request.position = activeTrade.ticket;
   request.symbol = _Symbol;
   request.deviation = 10;
   request.magic = 123456;

   if (activeTrade.isLong)
   {
      request.type = ORDER_TYPE_SELL;
      request.volume = PositionGetDouble(POSITION_VOLUME);
      request.price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   }
   else
   {
      request.type = ORDER_TYPE_BUY;
      request.volume = PositionGetDouble(POSITION_VOLUME);
      request.price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   }

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
//| Send Alert                                                       |
//+------------------------------------------------------------------+
void SendAlert(string message)
{
   if (!SendAlerts) return;

   // Throttle alerts to avoid spam
   if (TimeCurrent() - lastAlertTime < 300) return;

   Alert(message);
   Print(message);
   lastAlertTime = TimeCurrent();
}

//+------------------------------------------------------------------+
//| Helper: Get EMA value                                            |
//+------------------------------------------------------------------+
double GetEMA(int handle, int shift)
{
   double buffer[];
   ArraySetAsSeries(buffer, true);
   CopyBuffer(handle, 0, shift, 1, buffer);
   return buffer[0];
}

//+------------------------------------------------------------------+
//| Helper: Get Bollinger Bands value                               |
//+------------------------------------------------------------------+
double GetBBValue(int handle, int line, int shift)
{
   double buffer[];
   ArraySetAsSeries(buffer, true);
   CopyBuffer(handle, line, shift, 1, buffer);
   return buffer[0];
}

//+------------------------------------------------------------------+
//| Calculate EMA Divergence as Percentage                          |
//+------------------------------------------------------------------+
double CalculateEMADivergence(double price, double ema)
{
   if (ema == 0) return 0;
   return MathAbs(price - ema) / ema;
}

//+------------------------------------------------------------------+
//| Check for High Rejection Pattern                                |
//+------------------------------------------------------------------+
bool IsHighRejection(int lookbackPeriod)
{
   if (lookbackPeriod < 3) return false;

   // Check if recent highs are declining
   double high1 = High[0];
   double high2 = High[lookbackPeriod / 2];
   double high3 = High[lookbackPeriod];

   // High rejection: highs getting progressively lower
   return (high2 < high1) && (high3 < high2);
}

//+------------------------------------------------------------------+
//| Check for Short-Term Weakness (Candle Pattern Analysis)        |
//+------------------------------------------------------------------+
bool HasShortTermWeakness()
{
   // Check if recent candles show weakness:
   // - Inside bars increasing (candles contained within previous range)
   // - Failed to make higher highs
   // - Lower closes compared to opens

   int insideBarsCount = 0;
   int totalBars = 10;

   for (int i = 1; i < totalBars; i++)
   {
      // Inside bar: High < PrevHigh AND Low > PrevLow
      if (High[i] < High[i+1] && Low[i] > Low[i+1])
         insideBarsCount++;
   }

   // Weakness signal: 40% or more are inside bars + declining highs
   bool hasInsideBarPattern = insideBarsCount >= (totalBars * 0.4);
   bool hasDeclineHighs = High[0] < High[5];

   return hasInsideBarPattern && hasDeclineHighs;
}

//+------------------------------------------------------------------+
//| Check for Outside Bar Pattern                                  |
//+------------------------------------------------------------------+
bool IsOutsideBar(int shift)
{
   // Outside bar: High > PrevHigh AND Low < PrevLow
   if (shift < 1) return false;
   return (High[shift] > High[shift+1]) && (Low[shift] < Low[shift+1]);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   IndicatorRelease(ema10Handle);
   IndicatorRelease(ema20Handle);
   IndicatorRelease(ema40Handle);
   IndicatorRelease(ema80Handle);
   IndicatorRelease(bbHandle);

   Print("P4 Signal EA unloaded");
}

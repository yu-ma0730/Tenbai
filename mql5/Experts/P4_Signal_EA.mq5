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
input bool UseBTCUSDMode = false;            // BTCUSD mode (RR 1:1.5, 1:2)
input bool UseEMA80TP = true;                // Use EMA80 as TP target
input bool UseNShapeExtension = true;        // Extend profit on N-shape pattern
input double BB_Overshoot_Percent = 0.5;    // % beyond BB to detect overshoot (50%)
input bool DetectBBOvershoot = true;        // Detect BB overshoot
input bool Use75Percent_Entry = true;       // Use 75/25 entry composition (skip 25%)
input double ReducedRRRatio = 0.75;         // Reduced RR when BB overshoot (0.75:1)
input int AlertLevel = 1;                    // Alert level: 0=none, 1=important only, 2=all

//--- Global variables
int ema10Handle, ema20Handle, ema40Handle, ema80Handle;
int bbHandle;
ulong lastAlertTime = 0;
ulong lastTradeTime = 0;
int entrySignalCount = 0;  // For 75/25 entry composition

struct TradeInfo
{
   ulong ticket;
   datetime entryTime;
   double entryPrice;
   double stopLoss;
   double takeProfit;
   double entryLine;           // Entry line level
   double riskAmount;
   bool isLong;
   int tradeStage;             // 0: initial, 1: BB broken, 2: partial TP hit, 3: EMA80 target
   double tp1;                 // First TP (RR 1:1 or BTCUSD 1:1.5)
   double tp2;                 // Second TP (RR 1:2 or BTCUSD 1:2)
   int emaWickCount;           // Count for N-shape detection
};

TradeInfo activeTrade = {0, 0, 0, 0, 0, 0, 0, false, 0, 0, 0, 0};

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
      SendAlert("LONG ENTRY SIGNAL on " + _Symbol, 1);

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

      // Check for BB Overshoot (price far beyond BB)
      double bbRange = bbUpper - bbLower;
      double overshootDistance = bbRange * BB_Overshoot_Percent;
      bool isAboveOvershoot = currentPrice > (bbUpper + overshootDistance);

      // Check 75/25 entry composition
      bool shouldUseFullEntry = true;
      double appliedRRRatio = InitialRiskRewardRatio;

      if (Use75Percent_Entry)
      {
         bool skipThisEntry = (entrySignalCount % 4) == 3;  // Skip every 4th
         if (skipThisEntry)
         {
            shouldUseFullEntry = false;
            SendAlert("SHORT signal SKIPPED (25% skip rule) on " + _Symbol, 2);
         }
         entrySignalCount++;
      }

      if (isAboveOvershoot && DetectBBOvershoot)
      {
         // BB overshoot detected: use reduced RR or skip
         appliedRRRatio = ReducedRRRatio;
         SendAlert("SHORT: BB Overshoot detected! Using reduced RR " + DoubleToString(ReducedRRRatio) + " on " + _Symbol, 2);
      }

      if (!shouldUseFullEntry)
      {
         // Skip this entry
         prevPrice = currentPrice;
         return;
      }

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

      SendAlert(signalReason + " on " + _Symbol, 1);

      // Only execute if multiple confirmations OR high confidence signal
      if (EnableTrading && activeTrade.ticket == 0 && confirmationCount >= 1)
      {
         ExecuteShortTrade(currentPrice, ema80, appliedRRRatio);
      }
   }

   prevPrice = currentPrice;
}

//+------------------------------------------------------------------+
//| Execute Long Trade                                               |
//+------------------------------------------------------------------+
void ExecuteLongTrade(double entryPrice, double ema80, double appliedRRRatio = 1.0)
{
   MqlTradeRequest request = {0};
   MqlTradeResult result = {0};

   // Calculate stop loss (recent lowest point - this needs manual adjustment)
   double stopLoss = entryPrice - 50 * _Point; // Placeholder

   // Calculate risk amount
   double riskAmount = (AccountInfoDouble(ACCOUNT_BALANCE) * RiskPercent) / 100;
   double lotSize = riskAmount / ((entryPrice - stopLoss) / _Point * SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE));
   lotSize = NormalizeDouble(lotSize, 2);

   // Calculate risk distance
   double risk = entryPrice - stopLoss;

   // Calculate take profit levels based on mode and applied RR ratio
   double tp1, tp2, tp;
   if (UseBTCUSDMode)
   {
      tp1 = entryPrice + (risk * 1.5 * appliedRRRatio);  // RR 1:1.5 or reduced
      tp2 = entryPrice + (risk * 2.0 * appliedRRRatio);  // RR 1:2 or reduced
      tp = tp1;  // Start with first level
   }
   else
   {
      tp1 = entryPrice + (risk * appliedRRRatio);        // RR 1:1 or reduced
      tp2 = entryPrice + (risk * 1.5 * appliedRRRatio);  // RR 1:1.5 or reduced
      tp = tp1;
   }

   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = lotSize;
   request.type = ORDER_TYPE_BUY;
   request.price = entryPrice;
   request.sl = stopLoss;
   request.tp = tp;
   request.deviation = 10;
   request.magic = 123456;
   request.comment = "P4 Long Entry";

   if (OrderSend(request, result))
   {
      activeTrade.ticket = result.order;
      activeTrade.entryTime = TimeCurrent();
      activeTrade.entryPrice = entryPrice;
      activeTrade.stopLoss = stopLoss;
      activeTrade.takeProfit = tp;
      activeTrade.tp1 = tp1;
      activeTrade.tp2 = tp2;
      activeTrade.riskAmount = riskAmount;
      activeTrade.isLong = true;
      activeTrade.tradeStage = 0;

      Print("LONG trade opened: ", result.order, " at ", entryPrice, " | TP1: ", tp1, " TP2: ", tp2);
   }
   else
   {
      Print("Error opening LONG trade: ", GetLastError());
   }
}

//+------------------------------------------------------------------+
//| Execute Short Trade                                              |
//+------------------------------------------------------------------+
void ExecuteShortTrade(double entryPrice, double ema80, double appliedRRRatio = 1.0)
{
   MqlTradeRequest request = {0};
   MqlTradeResult result = {0};

   // Calculate stop loss (recent highest point - this needs manual adjustment)
   double stopLoss = entryPrice + 50 * _Point; // Placeholder

   // Calculate risk amount
   double riskAmount = (AccountInfoDouble(ACCOUNT_BALANCE) * RiskPercent) / 100;
   double lotSize = riskAmount / ((stopLoss - entryPrice) / _Point * SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE));
   lotSize = NormalizeDouble(lotSize, 2);

   // Calculate risk distance
   double risk = stopLoss - entryPrice;

   // Calculate take profit levels based on mode and applied RR ratio
   double tp1, tp2, tp;
   if (UseBTCUSDMode)
   {
      tp1 = entryPrice - (risk * 1.5 * appliedRRRatio);  // RR 1:1.5 or reduced
      tp2 = entryPrice - (risk * 2.0 * appliedRRRatio);  // RR 1:2 or reduced
      tp = tp1;  // Start with first level
   }
   else
   {
      tp1 = entryPrice - (risk * appliedRRRatio);        // RR 1:1 or reduced
      tp2 = entryPrice - (risk * 1.5 * appliedRRRatio);  // RR 1:1.5 or reduced
      tp = tp1;
   }

   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = lotSize;
   request.type = ORDER_TYPE_SELL;
   request.price = entryPrice;
   request.sl = stopLoss;
   request.tp = tp;
   request.deviation = 10;
   request.magic = 123456;
   request.comment = "P4 Short Entry";

   if (OrderSend(request, result))
   {
      activeTrade.ticket = result.order;
      activeTrade.entryTime = TimeCurrent();
      activeTrade.entryPrice = entryPrice;
      activeTrade.stopLoss = stopLoss;
      activeTrade.takeProfit = tp;
      activeTrade.tp1 = tp1;
      activeTrade.tp2 = tp2;
      activeTrade.riskAmount = riskAmount;
      activeTrade.isLong = false;
      activeTrade.tradeStage = 0;

      Print("SHORT trade opened: ", result.order, " at ", entryPrice, " | TP1: ", tp1, " TP2: ", tp2);
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

   double ema80 = GetEMA(ema80Handle, 0);
   request.action = TRADE_ACTION_SLTP;
   request.position = activeTrade.ticket;
   request.symbol = _Symbol;

   if (activeTrade.isLong)
   {
      // Stage 0: Initial TP reached - Move SL to breakeven
      if (currentPrice > activeTrade.tp1 && activeTrade.tradeStage == 0)
      {
         request.sl = activeTrade.entryPrice;
         activeTrade.tradeStage = 1;
         SendAlert("LONG: Initial TP reached. SL moved to breakeven.", 1);
      }
      // Stage 1: BB broken upward - Extend TP to TP2
      else if (currentPrice > bbUpper && activeTrade.tradeStage == 1)
      {
         if (UseBTCUSDMode)
            request.tp = activeTrade.tp2;  // Move to RR 1:2
         else
            request.tp = activeTrade.tp2;  // Move to RR 1:1.5

         request.sl = activeTrade.tp1;  // Move SL to TP1 level
         activeTrade.tradeStage = 2;
         SendAlert("LONG: BB breakout detected. TP extended to level 2.", 1);
      }
      // Stage 2: EMA80 touch - Use EMA80 as TP or continue
      else if (UseEMA80TP && currentPrice >= ema80 && activeTrade.tradeStage == 2)
      {
         // Option: Take profit at EMA80 or continue based on N-shape
         if (!UseNShapeExtension || !HasNShapePattern())
         {
            CloseActiveTrade("EMA80 TP reached");
         }
         else
         {
            SendAlert("LONG: N-shape detected. Extending profit beyond EMA80.", 2);
            activeTrade.tradeStage = 3;
         }
      }
   }
   else
   {
      // Stage 0: Initial TP reached - Move SL to breakeven
      if (currentPrice < activeTrade.tp1 && activeTrade.tradeStage == 0)
      {
         request.sl = activeTrade.entryPrice;
         activeTrade.tradeStage = 1;
         SendAlert("SHORT: Initial TP reached. SL moved to breakeven.", 1);
      }
      // Stage 1: BB broken downward - Extend TP to TP2
      else if (currentPrice < bbLower && activeTrade.tradeStage == 1)
      {
         if (UseBTCUSDMode)
            request.tp = activeTrade.tp2;  // Move to RR 1:2
         else
            request.tp = activeTrade.tp2;  // Move to RR 1:1.5

         request.sl = activeTrade.tp1;  // Move SL to TP1 level
         activeTrade.tradeStage = 2;
         SendAlert("SHORT: BB breakout detected. TP extended to level 2.", 1);
      }
      // Stage 2: EMA80 touch - Use EMA80 as TP or continue
      else if (UseEMA80TP && currentPrice <= ema80 && activeTrade.tradeStage == 2)
      {
         // Option: Take profit at EMA80 or continue based on N-shape
         if (!UseNShapeExtension || !HasNShapePattern())
         {
            CloseActiveTrade("EMA80 TP reached");
         }
         else
         {
            SendAlert("SHORT: N-shape detected. Extending profit beyond EMA80.", 2);
            activeTrade.tradeStage = 3;
         }
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
//| Send Alert with Level Control                                    |
//+------------------------------------------------------------------+
void SendAlert(string message, int level = 1)
{
   if (AlertLevel == 0) return;  // No alerts
   if (AlertLevel == 1 && level > 1) return;  // Skip informational messages at level 1

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
//| Check for N-Shape Pattern                                      |
//+------------------------------------------------------------------+
bool HasNShapePattern()
{
   // N-shape: Down-Up-Down-Up pattern
   // Check if recent candles form N-shape (zigzag)
   if (activeTrade.isLong)
   {
      // For Long: Check if we have multiple wicks creating zigzag
      int wickCount = 0;
      for (int i = 0; i < 10 && i < Bars(_Symbol, _Period); i++)
      {
         // Wick above close (resistance rejection)
         if (High[i] - Close[i] > (High[i] - Low[i]) * 0.5)
            wickCount++;
      }
      return wickCount >= 3;  // Multiple wicks = N-shape forming
   }
   else
   {
      // For Short: Check if we have multiple wicks creating zigzag
      int wickCount = 0;
      for (int i = 0; i < 10 && i < Bars(_Symbol, _Period); i++)
      {
         // Wick below close (support rejection)
         if (Close[i] - Low[i] > (High[i] - Low[i]) * 0.5)
            wickCount++;
      }
      return wickCount >= 3;  // Multiple wicks = N-shape forming
   }
}

//+------------------------------------------------------------------+
//| Draw Entry Line (Support/Resistance)                           |
//+------------------------------------------------------------------+
void DrawEntryLine(double level, string lineType)
{
   static int lineCount = 0;
   string lineName = "P4_Entry_Line_" + IntegerToString(lineCount++);

   ObjectCreate(0, lineName, OBJ_HLINE, 0, 0, level);
   ObjectSetInteger(0, lineName, OBJPROP_COLOR, clrDodgerBlue);
   ObjectSetInteger(0, lineName, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, lineName, OBJPROP_STYLE, STYLE_DASH);
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

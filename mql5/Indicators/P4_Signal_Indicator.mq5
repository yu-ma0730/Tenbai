//+------------------------------------------------------------------+
//|                         P4 Signal Indicator                       |
//|                    FX Trading Signal Tool for MT5                 |
//+------------------------------------------------------------------+
#property copyright "P4 Method Signal Tool"
#property link      ""
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 9
#property indicator_plots   9

#property indicator_label1  "EMA10"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrBlue
#property indicator_width1  2

#property indicator_label2  "EMA20"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrGreen
#property indicator_width2  2

#property indicator_label3  "EMA40"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrOrange
#property indicator_width3  2

#property indicator_label4  "EMA80"
#property indicator_type4   DRAW_LINE
#property indicator_color4  clrRed
#property indicator_width4  2

#property indicator_label5  "BB Upper"
#property indicator_type5   DRAW_LINE
#property indicator_color5  clrGray
#property indicator_width5  1
#property indicator_style5  STYLE_DASH

#property indicator_label6  "BB Lower"
#property indicator_type6   DRAW_LINE
#property indicator_color6  clrGray
#property indicator_width6  1
#property indicator_style6  STYLE_DASH

#property indicator_label7  "BB Middle"
#property indicator_type7   DRAW_LINE
#property indicator_color7  clrGray
#property indicator_width7  1
#property indicator_style7  STYLE_DOT

#property indicator_label8  "Long Signal"
#property indicator_type8   DRAW_ARROW
#property indicator_color8  clrBlue
#property indicator_width8  2

#property indicator_label9  "Short Signal"
#property indicator_type9   DRAW_ARROW
#property indicator_color9  clrRed
#property indicator_width9  2

#property indicator_label10 "EMA Divergence Warning"
#property indicator_type10  DRAW_ARROW
#property indicator_color10 clrOrange
#property indicator_width10 2

#property indicator_label11 "High Rejection Warning"
#property indicator_type11  DRAW_ARROW
#property indicator_color11 clrPurple
#property indicator_width11 2

#property indicator_label12 "BB Overshoot Warning"
#property indicator_type12  DRAW_ARROW
#property indicator_color12 clrHotPink
#property indicator_width12 2

#property indicator_label13 "75% Entry Signal"
#property indicator_type13  DRAW_ARROW
#property indicator_color13 clrLime
#property indicator_width13 3

//--- Input parameters
input int EMA10_Period = 10;
input int EMA20_Period = 20;
input int EMA40_Period = 40;
input int EMA80_Period = 80;
input int BB_Period = 20;
input double BB_Deviation = 2.0;
input double EMA_Divergence_Threshold = 0.003;  // 0.3% threshold
input bool ShowSignalArrows = true;
input bool ShowDivergenceWarning = true;
input bool ShowHighRejectionWarning = true;
input bool ShowEntryLines = true;           // Show entry lines (support/resistance)
input bool ShowEMA80Level = true;           // Show EMA80 take profit level
input bool UseBTCUSDMode = false;           // BTCUSD mode (RR 1:1.5, 1:2)
input double BB_Overshoot_Percent = 0.5;   // % beyond BB to detect overshoot (50%)
input bool ShowBBOvershotWarning = true;   // Show BB overshoot warning
input bool Use75Percent_Entry = true;      // Use 75/25 entry composition

//--- Buffers
double ema10Buffer[];
double ema20Buffer[];
double ema40Buffer[];
double ema80Buffer[];
double bbUpperBuffer[];
double bbLowerBuffer[];
double bbMiddleBuffer[];
double longSignalBuffer[];
double shortSignalBuffer[];
double divergenceBuffer[];
double highRejectionBuffer[];
double bbOvershotBuffer[];
double entryCompositionBuffer[];

//--- Handle for existing indicator
int ema10Handle, ema20Handle, ema40Handle, ema80Handle;
int bbHandle;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   // Set indicator buffers
   SetIndexBuffer(0, ema10Buffer, INDICATOR_DATA);
   SetIndexBuffer(1, ema20Buffer, INDICATOR_DATA);
   SetIndexBuffer(2, ema40Buffer, INDICATOR_DATA);
   SetIndexBuffer(3, ema80Buffer, INDICATOR_DATA);
   SetIndexBuffer(4, bbUpperBuffer, INDICATOR_DATA);
   SetIndexBuffer(5, bbLowerBuffer, INDICATOR_DATA);
   SetIndexBuffer(6, bbMiddleBuffer, INDICATOR_DATA);
   SetIndexBuffer(7, longSignalBuffer, INDICATOR_DATA);
   SetIndexBuffer(8, shortSignalBuffer, INDICATOR_DATA);
   SetIndexBuffer(9, divergenceBuffer, INDICATOR_DATA);
   SetIndexBuffer(10, highRejectionBuffer, INDICATOR_DATA);
   SetIndexBuffer(11, bbOvershotBuffer, INDICATOR_DATA);
   SetIndexBuffer(12, entryCompositionBuffer, INDICATOR_DATA);

   // Create handles for iMA (EMA)
   ema10Handle = iMA(_Symbol, _Period, EMA10_Period, 0, MODE_EMA);
   ema20Handle = iMA(_Symbol, _Period, EMA20_Period, 0, MODE_EMA);
   ema40Handle = iMA(_Symbol, _Period, EMA40_Period, 0, MODE_EMA);
   ema80Handle = iMA(_Symbol, _Period, EMA80_Period, 0, MODE_EMA);

   // Create handle for Bollinger Bands
   bbHandle = iBands(_Symbol, _Period, BB_Period, 0, BB_Deviation);

   if (ema10Handle == INVALID_HANDLE || ema20Handle == INVALID_HANDLE ||
       ema40Handle == INVALID_HANDLE || ema80Handle == INVALID_HANDLE ||
       bbHandle == INVALID_HANDLE)
   {
      Print("Error creating indicator handles");
      return INIT_FAILED;
   }

   // Indicator name
   IndicatorSetString(INDICATOR_SHORTNAME, "P4 Signal (10,20,40,80)");

   // Set digit count
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
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
                const int &spread[])
{
   if (rates_total < 100) return 0;

   // Copy EMA values
   CopyBuffer(ema10Handle, 0, 0, rates_total, ema10Buffer);
   CopyBuffer(ema20Handle, 0, 0, rates_total, ema20Buffer);
   CopyBuffer(ema40Handle, 0, 0, rates_total, ema40Buffer);
   CopyBuffer(ema80Handle, 0, 0, rates_total, ema80Buffer);

   // Copy Bollinger Bands values (Upper, Lower, Middle)
   CopyBuffer(bbHandle, 0, 0, rates_total, bbUpperBuffer);  // Upper band
   CopyBuffer(bbHandle, 1, 0, rates_total, bbMiddleBuffer); // Middle band (SMA)
   CopyBuffer(bbHandle, 2, 0, rates_total, bbLowerBuffer);  // Lower band

   // Check for Perfect Order and generate signals
   int start = rates_total - prev_calculated + 1;
   if (start < 100) start = 100;

   for (int i = start; i < rates_total; i++)
   {
      longSignalBuffer[i] = EMPTY_VALUE;
      shortSignalBuffer[i] = EMPTY_VALUE;
      divergenceBuffer[i] = EMPTY_VALUE;
      highRejectionBuffer[i] = EMPTY_VALUE;
      bbOvershotBuffer[i] = EMPTY_VALUE;
      entryCompositionBuffer[i] = EMPTY_VALUE;

      // Calculate EMA divergence (distance as percentage)
      double divergencePercent = 0;
      if (ema10Buffer[i] != 0)
         divergencePercent = MathAbs(close[i] - ema10Buffer[i]) / ema10Buffer[i];

      // Check for EMA divergence warning (> 0.3%)
      if (divergencePercent > EMA_Divergence_Threshold && ShowDivergenceWarning)
      {
         if (close[i] > ema10Buffer[i])
            divergenceBuffer[i] = low[i] - 20 * _Point;  // Price above EMA
         else
            divergenceBuffer[i] = high[i] + 20 * _Point; // Price below EMA
      }

      // Check for BB Overshoot (price far beyond BB)
      double bbRange = bbUpperBuffer[i] - bbLowerBuffer[i];
      double overshootDistance = bbRange * BB_Overshoot_Percent;

      bool isAboveOvershoot = close[i] > (bbUpperBuffer[i] + overshootDistance);
      bool isBelowOvershoot = close[i] < (bbLowerBuffer[i] - overshootDistance);

      if (ShowBBOvershotWarning && (isAboveOvershoot || isBelowOvershoot))
      {
         if (isAboveOvershoot)
            bbOvershotBuffer[i] = high[i] + 30 * _Point;  // Pink arrow above
         else
            bbOvershotBuffer[i] = low[i] - 30 * _Point;   // Pink arrow below
      }

      // 75% Entry Composition: Determine if this should be a full entry or skip entry
      // Every 4th signal can be skipped (25% skip rate = 75% entry rate)
      static int signalCount = 0;
      bool shouldUseFullEntry = (signalCount % 4) != 3;  // Skip every 4th (75% rule)
      if (Use75Percent_Entry)
         signalCount++;

      // Check Perfect Order for LONG
      if (ema10Buffer[i] > ema20Buffer[i] &&
          ema20Buffer[i] > ema40Buffer[i] &&
          ema40Buffer[i] > ema80Buffer[i])
      {
         // Check if price breaks above lower band (pullback entry)
         if (close[i] > bbLowerBuffer[i] &&
             close[i-1] <= bbLowerBuffer[i-1])
         {
            if (ShowSignalArrows && divergencePercent <= EMA_Divergence_Threshold)
               longSignalBuffer[i] = low[i] - 10 * _Point;
         }
      }

      // Check Perfect Order for SHORT
      if (ema80Buffer[i] > ema40Buffer[i] &&
          ema40Buffer[i] > ema20Buffer[i] &&
          ema20Buffer[i] > ema10Buffer[i])
      {
         // Check if price breaks below upper band (pullback entry)
         if (close[i] < bbUpperBuffer[i] &&
             close[i-1] >= bbUpperBuffer[i-1])
         {
            // Check for high rejection signal (failing to update higher highs)
            bool highRejection = CheckHighRejection(i, 50, high);  // Look back 50 bars

            if (ShowSignalArrows && divergencePercent <= EMA_Divergence_Threshold)
            {
               // Determine signal type based on BB overshoot and entry composition
               if (isAboveOvershoot)
               {
                  // Above BB overshoot: reduced RR warning or skip signal
                  if (shouldUseFullEntry)
                  {
                     // Show as 75% entry (green signal)
                     entryCompositionBuffer[i] = high[i] + 15 * _Point;
                  }
                  // else: skip this entry (no signal)
               }
               else if (highRejection && ShowHighRejectionWarning)
               {
                  highRejectionBuffer[i] = high[i] + 20 * _Point;
               }
               else if (shouldUseFullEntry)
               {
                  shortSignalBuffer[i] = high[i] + 10 * _Point;
               }
            }
         }
      }
   }

   return rates_total;
}

//+------------------------------------------------------------------+
//| Check High Rejection (Higher High Update Failure)                |
//+------------------------------------------------------------------+
bool CheckHighRejection(const int currentBar, const int lookbackPeriod, const double &high[])
{
   // Check if recent highs are declining (high rejection pattern)
   if (currentBar < lookbackPeriod) return false;

   double recentHighs[];
   int highsCount = 0;

   // Get recent 3 significant highs
   for (int i = currentBar - 1; i >= currentBar - lookbackPeriod && highsCount < 3; i--)
   {
      if (i > 0)
      {
         // Simple high rejection: recent bar's high < previous significant high
         if (high[i] > high[i-1] && high[i] > high[i-5])
         {
            if (highsCount == 0 || high[i] < recentHighs[highsCount-1])
               recentHighs[highsCount++] = high[i];
         }
      }
   }

   // High rejection if highs are getting lower
   if (highsCount >= 2)
      return recentHighs[1] < recentHighs[0];

   return false;
}

//+------------------------------------------------------------------+
//| Deinit                                                            |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   IndicatorRelease(ema10Handle);
   IndicatorRelease(ema20Handle);
   IndicatorRelease(ema40Handle);
   IndicatorRelease(ema80Handle);
   IndicatorRelease(bbHandle);
}

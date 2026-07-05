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

//--- Input parameters
input int EMA10_Period = 10;
input int EMA20_Period = 20;
input int EMA40_Period = 40;
input int EMA80_Period = 80;
input int BB_Period = 20;
input double BB_Deviation = 2.0;
input bool ShowSignalArrows = true;

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

      // Check Perfect Order for LONG
      if (ema10Buffer[i] > ema20Buffer[i] &&
          ema20Buffer[i] > ema40Buffer[i] &&
          ema40Buffer[i] > ema80Buffer[i])
      {
         // Check if price breaks above lower band (pullback entry)
         if (close[i] > bbLowerBuffer[i] &&
             close[i-1] <= bbLowerBuffer[i-1])
         {
            if (ShowSignalArrows)
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
            if (ShowSignalArrows)
               shortSignalBuffer[i] = high[i] + 10 * _Point;
         }
      }
   }

   return rates_total;
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

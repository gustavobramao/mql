//+------------------------------------------------------------------+
//|                                     Supertrend EMA Indicator.mq5 |
//|                                                Sebastijan Koščak |
//|           https://www.upwork.com/freelancers/~012f6640e05a15d214 |
//+------------------------------------------------------------------+
#property copyright "Sebastijan Koščak"
#property link      "https://www.upwork.com/freelancers/~012f6640e05a15d214"
#property version   "1.00"
#property indicator_chart_window

#property indicator_buffers 9
#property indicator_plots 7

#property indicator_label1 "Trend Up"
#property indicator_type1   DRAW_COLOR_LINE
#property indicator_color1  clrGreen,clrNONE
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

#property indicator_label2 "Trend Down"
#property indicator_type2   DRAW_COLOR_LINE
#property indicator_color2  clrNONE,clrRed
#property indicator_style2  STYLE_SOLID
#property indicator_width2  2

#property indicator_label3 "ATR"
#property indicator_type3   DRAW_NONE

#property indicator_label4 "EMA 1"
#property indicator_type4   DRAW_LINE
#property indicator_color4  clrNONE
#property indicator_style4  STYLE_SOLID
#property indicator_width4  2

#property indicator_label5 "EMA 2"
#property indicator_type5   DRAW_LINE
#property indicator_color5  clrNONE
#property indicator_style5  STYLE_SOLID
#property indicator_width5  2

#property indicator_label6 "Arrow Up"
#property indicator_type6   DRAW_ARROW
#property indicator_color6  clrLime
#property indicator_style6  STYLE_SOLID
#property indicator_width6  2

#property indicator_label7 "Arrow Down"
#property indicator_type7   DRAW_ARROW
#property indicator_color7  clrRed
#property indicator_style7  STYLE_SOLID
#property indicator_width7  2

// I did this to make it like it is in pine
// typing hl2 anywhere is literally the same as typing ((high[i]+low[i])/2), meaning hl2 can't be used outside of the loop because 'i' won't be defined
#define hl2 ((high[i]+low[i])/2)

// Inputs you see when you add the indicator to the chart and go to change it's settings
input group "SuperTrend"
input int InpATRPeriod = 1;   // ATR Lenght
input double InpATRFactor = 3;   // ATR Factor

input group "Moving Average 1"
input int InpMA1Period = 13; // MA 1 Period
input ENUM_MA_METHOD InpMA1Method = MODE_EMA;   // MA 1 Method

input group "Moving Average 2"
input int InpMA2Period = 34; // MA 2 Period
input ENUM_MA_METHOD InpMA2Method = MODE_EMA;   // MA 2 Method

// Global Variables and Buffers
double TrendUp[],TrendUp_C[];
double TrendDown[],TrendDown_C[];
double ATR[];
double MA1[],MA2[];
double ArrowUp[],ArrowDown[];

// A structure to keep the handles in the same spot, makes things easier
struct IndiStruct
{
   int ATR;
   int MA1;
   int MA2;
}Indi;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
//--- indicator buffers mapping
   // Setting index buffers and what not, this is what every indicator has to have.
   SetIndexBuffer(0,TrendUp,INDICATOR_DATA);
   SetIndexBuffer(1,TrendUp_C,INDICATOR_COLOR_INDEX);
   SetIndexBuffer(2,TrendDown,INDICATOR_DATA); 
   SetIndexBuffer(3,TrendDown_C,INDICATOR_COLOR_INDEX);
   SetIndexBuffer(4,ATR,INDICATOR_DATA);
   SetIndexBuffer(5,MA1,INDICATOR_DATA);
   SetIndexBuffer(6,MA2,INDICATOR_DATA);
   SetIndexBuffer(7,ArrowUp,INDICATOR_DATA); PlotIndexSetInteger(5, PLOT_ARROW, 233);
   SetIndexBuffer(8,ArrowDown,INDICATOR_DATA); PlotIndexSetInteger(6, PLOT_ARROW, 234);
   
   // Emptying out the buffers just because it's good practice and this can fix some issues on some indicators 
   ArrayInitialize(TrendUp,EMPTY_VALUE);
   ArrayInitialize(TrendUp_C,EMPTY_VALUE);
   ArrayInitialize(TrendDown,EMPTY_VALUE);
   ArrayInitialize(TrendDown_C,EMPTY_VALUE);
   ArrayInitialize(ATR,EMPTY_VALUE);
   ArrayInitialize(MA1,EMPTY_VALUE);
   ArrayInitialize(MA2,EMPTY_VALUE);
   ArrayInitialize(ArrowUp,EMPTY_VALUE);
   ArrayInitialize(ArrowDown,EMPTY_VALUE);
   
   // Cleaning the Indi structure because if you just change the timeframe of the chart or the parameters, global variables aren't re-initialized and they retain their values, so I clean them if they need to be cleaned.
   ZeroMemory(Indi);
   Indi.ATR = iATR(_Symbol,_Period,InpATRPeriod);
   Indi.MA1 = iMA(_Symbol,_Period,InpMA1Period,0,InpMA1Method,PRICE_CLOSE);
   Indi.MA2 = iMA(_Symbol,_Period,InpMA2Period,0,InpMA2Method,PRICE_CLOSE);
//---
   return(INIT_SUCCEEDED);
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
//---
   // 'Reversing' the arrays, is the array is a Series 0 will be the last value, this is done so that 0 is always the newest candle, and the values get pushed
   // This is much easier to work with than having 0 be the last value and the number of bars which can be any number be the current candle. this way you always know index of 1 is the candle before the current one.
   ArraySetAsSeries(TrendUp,true);
   ArraySetAsSeries(TrendUp_C,true);
   ArraySetAsSeries(TrendDown,true);
   ArraySetAsSeries(TrendDown_C,true);
   ArraySetAsSeries(ATR,true);
   ArraySetAsSeries(MA1,true);
   ArraySetAsSeries(MA2,true);
   ArraySetAsSeries(ArrowUp,true);
   ArraySetAsSeries(ArrowDown,true);
   
   ArraySetAsSeries(high,true);
   ArraySetAsSeries(low,true);
   ArraySetAsSeries(close,true);
   ArraySetAsSeries(open,true);
   ArraySetAsSeries(time,true);
   
   // Making sure the indicators are handled if not we return 0 so that when we actually get through all the safety checks we are still on that "first" run
   if(Indi.ATR == INVALID_HANDLE) { Indi.ATR = iATR(_Symbol,_Period,InpATRPeriod); return 0; }
   if(Indi.MA1 == INVALID_HANDLE) { Indi.MA1 = iMA(_Symbol,_Period,InpMA1Period,0,InpMA1Method,PRICE_CLOSE); return 0; }
   if(Indi.MA2 == INVALID_HANDLE) { Indi.MA2 = iMA(_Symbol,_Period,InpMA2Period,0,InpMA2Method,PRICE_CLOSE); return 0; }
   
   // This will usually result in 0, except on the first tick of a new candle, at which it will be 1, and this way we check tat candle just one more time after it closes
   int limit = rates_total-prev_calculated;
   static datetime old_time=time[0];
   
   // If this is our first run of the indicator and previusly calculated number of candles is 0
   if(prev_calculated==0) 
   {
      // Max number to start looping from 
      limit = rates_total-MathMax(InpMA2Period,InpATRPeriod)-20;
      if(BarsCalculated(Indi.ATR) < limit || BarsCalculated(Indi.MA1) < limit || BarsCalculated(Indi.MA2) < limit) return 0;
      
      // Copy the indicator values for all the candles we will do calculations on, since this is the first run we copy all the values we need
      if(CopyBuffer(Indi.ATR,0,0,limit,ATR) < limit) return 0;
      if(CopyBuffer(Indi.MA1,0,0,limit,MA1) < limit) return 0;
      if(CopyBuffer(Indi.MA2,0,0,limit,MA2) < limit) return 0;
   }
   
   // Since mql just runs the OnCalculate function on each tick and doesn't work like pine where the whole code you write gets executed on each candle from last to current automatically
   // We have to make our own loop here and loop through candles, so on our first run of the indicator we need to loop through all the candles, or at least through how many we can taking in mind that if we use ema period 36, it needs at least 36 candles before it to make a calculation
   // so I always do rates_total - theInputValue - 'a few extra candles just to make sure we have enough candles in history for the calculations'
   // as you can see limit = rates_total-MathMax(InpMA2Period,InpATRPeriod)-20;
   // then on the next loop we just run the current candle or something like that
   for(int i=limit;i>=0;i--)
   {
      ArrowUp[i] = EMPTY_VALUE;
      ArrowDown[i] = EMPTY_VALUE;
      
      // only run on the new candles because we have already filled the buffers with values using CopyBuffer
      if(i == 1 || i == 0)
      {
         MA1[i] = iCustom(Indi.MA1,0,i);
         MA2[i] = iCustom(Indi.MA2,0,i);
         ATR[i] = iCustom(Indi.ATR,0,i);
      }
      
      // Super Trend calculations
      double Up = hl2 - (InpATRFactor * ATR[i]);
      double Dn = hl2 + (InpATRFactor * ATR[i]);
      
      TrendUp[i] = close[i+1] > TrendUp[i+1] ? MathMax(Up, TrendUp[i+1]) : Up;
      TrendDown[i] = close[i+1] < TrendDown[i+1] ? MathMin(Dn, TrendDown[i+1]) : Dn;
      TrendUp_C[i] = close[i] > TrendDown[i+1] ? 0 : close[i] < TrendUp[i+1] ? 1 : TrendUp_C[i+1];
      TrendDown_C[i] = TrendUp_C[i];
      
      // Signal Calculation
      ArrowUp[i]   = TrendUp_C[i] != TrendUp_C[i+1] && TrendUp_C[i] == 0 && MA1[i] > MA2[i] ? TrendUp[i] : EMPTY_VALUE;
      ArrowDown[i] = TrendUp_C[i] != TrendUp_C[i+1] && TrendUp_C[i] == 1 && MA1[i] < MA2[i] ? TrendDown[i] : EMPTY_VALUE;
   }
   
//--- return value of prev_calculated for next call
   return(rates_total);
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| custom iCustom so it's use is similar to MQL4
//+------------------------------------------------------------------+
double iCustom(int handle, int mode=0, int shift=0)
{
   static double buffer[1];
   ResetLastError();
   if (handle < 0)
   {
      Print("Error: Indicator not handled. (handle=", handle, " | error code=", GetLastError(), ")");
      return 0;
   }
   
   int success = CopyBuffer(handle, mode, shift, 1, buffer);
   if (success <= 0)
   {
      Print(_Symbol,": Error! Cannot get value from a custom indicator. (handle=", handle, " | error code=", GetLastError(), ")");
      return 0;
   }
   return buffer[0];
}
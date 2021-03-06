//+------------------------------------------------------------------+
//|                                            SuperTrend EMA EA.mq5 |
//|                                                Sebastijan Koščak |
//|           https://www.upwork.com/freelancers/~012f6640e05a15d214 |
//+------------------------------------------------------------------+
#property copyright "Sebastijan Koščak"
#property link      "https://www.upwork.com/freelancers/~012f6640e05a15d214"
#property version   "1.00"

// Making a custom enumeration so we can have a drop-down input menu
enum ENUM_LOTS
{
   LOTS_FIXED, // Fixed Lots
   LOTS_RISK   // Risk %
};
enum ENUM_TRADE_DIR
{
   DIR_BOTH=0,   // Both
   DIR_BUY=1,    // Buy
   DIR_SELL=-1    // Sell
};
input group "Risk Settings"
input double InpStopLoss = 20;   // Stop Loss
input double InpTakeProfit = 20; // Take Profit
input ENUM_LOTS InpLotsType = LOTS_FIXED; // Volume Type
input double InpLots = 0.1;   // Volume Value

input group "Trade Settings"
input ENUM_TRADE_DIR InpAllowedTradeDir = DIR_BOTH; // Allowed trade direction
input bool InpCloseTradeSignal = false;   // Close running trade if opposite trade signal appears
input int InpMaxTrades = 5;   // Max number of running trades on this symbol

input group "SuperTrend"
input int InpATRPeriod = 1;   // ATR Lenght
input double InpATRFactor = 3;   // ATR Factor

input group "Moving Average 1"
input int InpMA1Period = 13; // MA 1 Period
input ENUM_MA_METHOD InpMA1Method = MODE_EMA;   // MA 1 Method

input group "Moving Average 2"
input int InpMA2Period = 34; // MA 2 Period
input ENUM_MA_METHOD InpMA2Method = MODE_EMA;   // MA 2 Method

input group "Trading sessions"
input bool   InpSessionEnabled = true; // Use Trading sessions
input string InpSessionTime = "07:00-16:00"; // Trading times you can set multiple using ',' as a divider (07:00-16:00,18:00-21:00)

input group "EA Settings"
input bool InpPrintMaxTrades = true; // Print in the log if a trade doesn't open because of Max Trades limit
input bool InpPrintTF = true; // Print in the log if a trade doesn't open because of Time Filtering
input int PipValue = 10;
input int magicNumber = 234621;

// for EURUSD _Point is 0.00001 so _Pip will be 0.0001 which we will use later
double _Pip = _Point*PipValue;
int Handle;
int count1 = 0;
int count2= 0;

// Include the Trade.mqh include file which has all the trade operation functions you need, makes life a lot easier 
#include <Trade/Trade.mqh>
CTrade TRADE;

struct TradeInfoStruct
{
   int Buys;
   int Sells;
   int Total;
}TradeInfo;
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
//---
   // Initializing the Trade Class 
   // magic number is how EA recognizes which trades were made by it, each trade has a magic number, manual trades have a magic number of 0
   // in this EA we don't manage trades later, but if we did we would loop through all trades and check if the trade has the same magic number as in the inputs to make sure that trade belongs to this EA
   TRADE.SetExpertMagicNumber(magicNumber);
   TRADE.SetTypeFillingBySymbol(_Symbol);
   TRADE.LogLevel(LOG_LEVEL_ALL);
   
   // Handle the indicator, the empty "" are there because group input counts as a string input when calling the indicator with iCustom
   Handle = iCustom(_Symbol, _Period, "Supertrend EMA Indicator", "", InpATRPeriod, InpATRFactor, "", InpMA1Period, InpMA1Method, "", InpMA2Period, InpMA2Method);
   count1 = 0;
   count2 = 0;

//---
   return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
//---
   // This is usually automatically done, but I have a habit of doing it here anyway just in case
   IndicatorRelease(Handle);
}
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
//---
   // Make sure our indicator was handled without any error
   if(Handle == INVALID_HANDLE)
   {
      if(count1 > 5) ExpertRemove();
      count1++;
      Print("Failed to handle 'Supertrend EMA Indicator' (",GetLastError(),")");
      Handle = iCustom(_Symbol, _Period, "Supertrend EMA Indicator", "", InpATRPeriod, InpATRFactor, "", InpMA1Period, InpMA1Method, "", InpMA2Period, InpMA2Method);
      return;
   }
   // Make sure the indicator was calculated to make sure it has the correct values
   if(BarsCalculated(Handle) < 50) 
   {
      if(count2 > 5) { Print("Failed to calculate more than 50 bars of the indicator"); ExpertRemove(); }
      count2++;
      return;
   }
   
   
   // Only check once per new candle to reduce CPU load. We only want to enter on confirmed candles and not while it's repainting
   if(IsNewCandle())
   {
      // Count how many trades are running on this Symbol + magicNumber combo
      CheckTrades();
      
      // we fetch the values on every candle even if timefilter is false because if we don't fetch the values on every candle the indicator that's handled can sometimes miss some candles worth of calculation
      // no idea why this happens but MT5 does have some weird bugs that I've encoutered over the years so I always do as much safety measures as possible
      double Buy  = iCustom(Handle,7,1);
      double Sell = iCustom(Handle,8,1);
      
      
      if(Buy != EMPTY_VALUE)
      {
         if(InpCloseTradeSignal && TradeInfo.Sells > 0) 
         {
            int count = CloseAllTrades(POSITION_TYPE_SELL);
            if(count > 0) Print("Closed ",count," Sell trades because a Buy signal was triggered.");
         }
         if(InpAllowedTradeDir >= 0)
         {
            if(TimeFilter())
            {
               if(TradeInfo.Total < InpMaxTrades)
               {
                  // Buy trades enter on ASK price so we fetch the price and calculate the tp and sl
                  // We send the tp and sl to the broker so we don't need to manage the trade
                  double op = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
                  double tp = op + InpTakeProfit*_Pip;
                  double sl = op - InpTakeProfit*_Pip;
                  double lots = GetLots(_Symbol,sl,op);
                  
                  TRADE.Buy(lots,_Symbol,op,sl,tp);
               }
               else if(InpPrintMaxTrades) Print("Not opening a Buy trade because the limit was reached. ",TradeInfo.Total,"/",InpMaxTrades);
            }
            else if(InpPrintTF) Print("Not opening a Buy trade because of TimeFilter.");
         }
      }
      
      if(Sell != EMPTY_VALUE)
      {
         if(InpCloseTradeSignal && TradeInfo.Buys > 0) 
         {
            int count = CloseAllTrades(POSITION_TYPE_BUY);
            if(count > 0) Print("Closed ",count," Buy trades because a Sell signal was triggered.");
         }
         if(InpAllowedTradeDir <= 0)
         {
            if(TimeFilter())
            {
               if(TradeInfo.Total < InpMaxTrades)
               {
                  double op = SymbolInfoDouble(_Symbol,SYMBOL_BID);
                  double tp = op - InpTakeProfit*_Pip;
                  double sl = op + InpTakeProfit*_Pip;
                  double lots = GetLots(_Symbol,sl,op);
                  
                  TRADE.Sell(lots,_Symbol,op,sl,tp);
               }
               else if(InpPrintMaxTrades) Print("Not opening a Sell trade because the limit was reached. ",TradeInfo.Total,"/",InpMaxTrades);
            }
            else if(InpPrintTF) Print("Not opening a Sell trade because of TimeFilter.");
         }
      }
   }
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CheckTrades()
{
   ZeroMemory(TradeInfo);
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol || PositionGetInteger(POSITION_MAGIC) != magicNumber) continue;
      
      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) TradeInfo.Buys++;
      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL) TradeInfo.Sells++;
   }
   TradeInfo.Total = TradeInfo.Buys + TradeInfo.Sells;
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int CloseAllTrades(int type=-1)
{
   int closed=0;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol || PositionGetInteger(POSITION_MAGIC) != magicNumber) continue;
      
      if(PositionGetInteger(POSITION_TYPE) == type || type == -1) if(TRADE.PositionClose(ticket)) closed++;
   }
   CheckTrades();
   return closed;
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
      Print(_Symbol, ": Error! Cannot get value from a custom indicator. (handle=", handle, " | error code=", GetLastError(), ")");
      return 0;
   }
   return buffer[0];
}

//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
// it will return true when trading is allowed and false when it's not
bool TimeFilter()
{
   if(!InpSessionEnabled) return true;
   datetime start_ = 0, end = 0, now = 0;
   bool pass = false;
   
   string temp_string[];
   StringSplit(InpSessionTime,StringGetCharacter(",",0),temp_string);
   if(ArraySize(temp_string)==0)
   {
      ArrayResize(temp_string,1);
      temp_string[0] = InpSessionTime;
   }
   
   now = TimeCurrent();
   for(int i=0;i<ArraySize(temp_string);i++)
   {
      string t_string[];
      StringSplit(temp_string[i],StringGetCharacter("-",0),t_string);
      
      if(ArraySize(t_string) >= 2)
      {
         start_ = TimeFromString(t_string[0]);
         end = TimeFromString(t_string[1]);
         if (end < start_) end = end + 86400;
   		if (now >= start_ && now < end) pass=true;
   		if(!pass)
   		{
   		   end = end - 86400;
   		   start_ = start_ - 86400;
   		   if (now >= start_ && now < end) pass=true;
   		}
   		if(pass) return true;
      }
   }
   return false;
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
datetime TimeFromString(string stamp)
{
	datetime t = TimeCurrent();
	MqlDateTime tm;
	TimeToStruct(t,tm);

	int stamplen = StringLen(stamp);

	if (stamplen < 9)
	{
		int thour    = tm.hour;
		int tminute  = tm.min;
		int tseconds = tm.sec;

		int hour   = (int)StringSubstr(stamp, 0, 2);
		int minute = (int)StringSubstr(stamp, 3, 2);
		int second = 0;

		if (stamplen > 5)
		{
			second = (int)StringSubstr(stamp, 6, 2);
		}

		datetime t1 = (datetime)(t - (thour-hour)*3600 - (tminute - minute)*60 - (tseconds-second));

		return t1;
	}

	return StringToTime(stamp);
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsNewCandle(int i=0,ENUM_TIMEFRAMES period=PERIOD_CURRENT)
{
	static datetime saved_candle_time[20];
	if(iTime(Symbol(),period,0)==saved_candle_time[i])
		return false;
	else
		saved_candle_time[i]=iTime(Symbol(),period,0);
	return true;
}

//+------------------------------------------------------------------+
//| Calculates risk size and position size. Sets object values.      |
//+------------------------------------------------------------------+
double GetLots(string symbol,double sl,double op)
{
   if(InpLotsType == LOTS_FIXED) return InpLots;
   double PositionSize = 0;
   double pre_unitcost = 0;
   double UnitCost;
   double UnitCost_reward = 0;
   double OutputPositionSize = 0;
   double AccSize =  AccountInfoDouble(ACCOUNT_EQUITY);
   double RiskMoney = RoundDown(AccSize * InpLots / 100, 2);
   
   string AccountCurrency = AccountInfoString(ACCOUNT_CURRENCY);
   string BaseCurrency = SymbolInfoString(symbol, SYMBOL_CURRENCY_BASE);
   ENUM_SYMBOL_CALC_MODE CalcMode = (ENUM_SYMBOL_CALC_MODE)SymbolInfoInteger(symbol, SYMBOL_TRADE_CALC_MODE);
   double TickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   double MinLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double MaxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   double LotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);

   double StopLoss = MathAbs(op - sl);
   if(sl==0) { Print("Failed to calculate risk! Stop loss is 0, using minimum lots to open trade"); return MinLot; }
   
   CalculateUnitCost(UnitCost, UnitCost_reward, symbol);
   
   // If account currency == pair's base currency, adjust UnitCost to future rate (SL). Works only for Forex pairs.
   if ((AccountCurrency == BaseCurrency) && ((CalcMode == SYMBOL_CALC_MODE_FOREX) || (CalcMode == SYMBOL_CALC_MODE_FOREX_NO_LEVERAGE)))
   {
      double current_rate = 1, future_rate = 1;
      if (sl < op)
      {
         current_rate = SymbolInfoDouble(symbol, SYMBOL_ASK);
         future_rate = current_rate - StopLoss;
      }
      else if (sl > op)
      {
         current_rate = SymbolInfoDouble(symbol, SYMBOL_BID);
         future_rate = current_rate + StopLoss;
      }
      if (future_rate == 0) future_rate = SymbolInfoDouble(symbol,SYMBOL_POINT); // Zero divide prevention.
      UnitCost *= (current_rate / future_rate);
   }
   
   if ((StopLoss != 0) && (UnitCost != 0) && (TickSize != 0))
   {
      PositionSize = RoundDown(RiskMoney / (StopLoss * UnitCost / TickSize), 2);
      OutputPositionSize = PositionSize;
   }      
   
   if (PositionSize < MinLot) OutputPositionSize = MinLot;
   else if (PositionSize > MaxLot) OutputPositionSize = MaxLot;
   double steps = 0;
   if (LotStep != 0) steps = OutputPositionSize / LotStep;
   if (MathAbs(MathRound(steps) - steps) < 0.00000001) steps = MathRound(steps);
   if (MathFloor(steps) < steps) OutputPositionSize = MathFloor(steps) * LotStep;
 
   return OutputPositionSize;   
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double RoundDown(const double value, const double digits)
{
   int norm = (int) MathPow(10, digits);
   return(MathFloor(value * norm) / norm);
}
//+-----------------------------------------------------------------------------------+
//| Calculates necessary adjustments for cases when ProfitCurrency != AccountCurrency.|
//| Optional parameter profit_currency for when calculating adjustment for positions  |
//| in other symbols (for Risk tab).                                                  |
//+-----------------------------------------------------------------------------------+
#define FOREX_SYMBOLS_ONLY 0
#define NONFOREX_SYMBOLS_ONLY 1
enum TRADE_DIRECTION
{
   Long,
   Short
};

enum PROFIT_LOSS
{
   Profit,
   Loss
};
//+-----------------------------------------------------------------------------------+
//| Calculates necessary adjustments for cases when GivenCurrency != AccountCurrency. |
//| Used in two cases: profit adjustment and margin adjustment.                       |
//+-----------------------------------------------------------------------------------+
double CalculateAdjustment(PROFIT_LOSS calc_mode, const string GivenCurrency, string &ReferencePair, bool &ReferencePairMode, string ProfitCurrency,string AccountCurrency)
{
   if (ReferencePair == NULL) FindReferencePair(GivenCurrency, ReferencePair, ReferencePairMode, AccountCurrency);
   if (ReferencePair == NULL)
   {
      // If ReferncePair wasn't found directly, an attempt should be made for an indirect calculation - using a combination of PRC/ACC (ACC/PRC) data and the current symbol's data.
      // This is useful for margin calculation only.
      if (ReferencePair == NULL) FindReferencePair(ProfitCurrency, ReferencePair, ReferencePairMode, AccountCurrency);
      if (ReferencePair != NULL)
      {
         // ReferencePair is a pair to convert account currency to symbol's profit currency.
         MqlTick tick;
         SymbolInfoTick(ReferencePair, tick);
         double ccc_indirect = GetCurrencyCorrectionCoefficient(Loss, ReferencePairMode, tick); // Loss because we need to convert our account currency first into reference currency and then into CFD base.
         SymbolInfoTick(Symbol(), tick);
         double ccc = GetCurrencyCorrectionCoefficient(Loss, true, tick); // Loss because we convert rference currency into CFD base. ref_mode = true because XXX is always the first symbol in XXXUSD-like CFD symbols.
         ReferencePair = NULL; // Reset to recalculate everything again next time.
         return(ccc_indirect * ccc); // Double conversion.
      }
      else // Everything has failed.
      {
         Print("Error! Cannot detect proper currency pair for adjustment calculation: ", GivenCurrency, ", ", AccountCurrency, ".");
         ReferencePair = Symbol();
         return(1);
      }
   }
   MqlTick tick;
   SymbolInfoTick(ReferencePair, tick);
   return(GetCurrencyCorrectionCoefficient(calc_mode, ReferencePairMode, tick));
}
//+---------------------------------------------------------------------------------+
//| Finds a reference currency pair and mode of adjustment based on two currencies. |
//+---------------------------------------------------------------------------------+
void FindReferencePair(const string GivenCurrency, string &ReferencePair, bool &ReferencePairMode,string AccountCurrency)
{
   ReferencePair = GetSymbolByCurrencies(GivenCurrency, AccountCurrency);
   ReferencePairMode = true;
   // Failed.
   if (ReferencePair == NULL)
   {
      // Reversing currencies.
      ReferencePair = GetSymbolByCurrencies(AccountCurrency, GivenCurrency);
      ReferencePairMode = false;
   }
}

//+---------------------------------------------------------------------------+
//| Returns a currency pair with specified base currency and profit currency. |
//+---------------------------------------------------------------------------+
string GetSymbolByCurrencies(string base_currency, string profit_currency)
{
   // Cycle through all symbols.
   for (int s = 0; s < SymbolsTotal(false); s++)
   {
      // Get symbol name by number.
      string symbolname = SymbolName(s, false);

      // Skip non-Forex pairs.
      if ((SymbolInfoInteger(symbolname, SYMBOL_TRADE_CALC_MODE) != SYMBOL_CALC_MODE_FOREX) && (SymbolInfoInteger(symbolname, SYMBOL_TRADE_CALC_MODE) != SYMBOL_CALC_MODE_FOREX_NO_LEVERAGE)) continue;

      // Get its base currency.
      string b_cur = SymbolInfoString(symbolname, SYMBOL_CURRENCY_BASE);

      // Get its profit currency.
      string p_cur = SymbolInfoString(symbolname, SYMBOL_CURRENCY_PROFIT);

      // If the currency pair matches both currencies, select it in Market Watch and return its name.
      if ((b_cur == base_currency) && (p_cur == profit_currency))
      {
         // Select if necessary.
         if (!(bool)SymbolInfoInteger(symbolname, SYMBOL_SELECT)) SymbolSelect(symbolname, true);
         
         return(symbolname);
      }
   }
   return(NULL);
}

//+------------------------------------------------------------------+
//| Get profit correction coefficient based on profit currency,      |
//| calculation mode (profit or loss), reference pair mode (reverse  |
//| or direct), and current prices.                                  |
//+------------------------------------------------------------------+
double GetCurrencyCorrectionCoefficient(PROFIT_LOSS calc_mode, bool ref_mode, MqlTick &tick)
{
   if ((tick.ask == 0) || (tick.bid == 0)) return(-1); // Data is not yet ready.
   if (calc_mode == Loss)
   {
      // Reverse quote.
      if (ref_mode)
      {
         // Using Buy price for reverse quote.
         return(tick.ask);
      }
      // Direct quote.
      else
      {
         // Using Sell price for direct quote.
         return(1 / tick.bid);
      }
   }
   else if (calc_mode == Profit)
   {
      // Reverse quote.
      if (ref_mode)
      {
         // Using Sell price for reverse quote.
         return(tick.bid);
      }
      // Direct quote.
      else
      {
         // Using Buy price for direct quote.
         return(1 / tick.ask);
      }
   }
   return(-1);
}
//+----------------------------------------------------------------------+
//| Calculates unit cost for loss and unit cost for reward calculations. |
//+----------------------------------------------------------------------+
void CalculateUnitCost(double &UnitCost_loss, double &UnitCost_profit,string symbol)
{
   ENUM_SYMBOL_CALC_MODE CalcMode = (ENUM_SYMBOL_CALC_MODE)SymbolInfoInteger(symbol, SYMBOL_TRADE_CALC_MODE);
   double TickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   double ContractSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE);
   string AccountCurrency = AccountInfoString(ACCOUNT_CURRENCY);
   string ProfitCurrency = SymbolInfoString(symbol, SYMBOL_CURRENCY_PROFIT);
   string ProfitConversionPair=NULL;
   bool ProfitConversionMode;
   // No-Forex.
   if ((CalcMode != SYMBOL_CALC_MODE_FOREX) && (CalcMode != SYMBOL_CALC_MODE_FOREX_NO_LEVERAGE))
   {
      if ((CalcMode == SYMBOL_CALC_MODE_FUTURES) || (CalcMode == SYMBOL_CALC_MODE_EXCH_FUTURES))
      {
         if (TickSize == 0) return; // Data not yet read, avoidning the division by zero error;
         UnitCost_loss = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE_LOSS) / TickSize;
         UnitCost_profit = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE_PROFIT) / TickSize;
      }
      else
      {
         UnitCost_loss = TickSize * ContractSize;
         UnitCost_profit = UnitCost_loss;
         // If profit currency is different from account currency.
         if (ProfitCurrency != AccountCurrency)
         {
            double CCC = CalculateAdjustment(Loss, ProfitCurrency, ProfitConversionPair, ProfitConversionMode, ProfitCurrency, AccountCurrency);
            // Adjust the unit cost.
            UnitCost_loss *= CCC;
            CCC = CalculateAdjustment(Profit, ProfitCurrency, ProfitConversionPair, ProfitConversionMode, ProfitCurrency, AccountCurrency);
            UnitCost_profit *= CCC;
         }       
      }
   }
   // With Forex instruments, tick value already equals 1 unit cost.
   else
   {
      UnitCost_loss = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_VALUE_LOSS);
      UnitCost_profit = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_VALUE_PROFIT);
   }
}

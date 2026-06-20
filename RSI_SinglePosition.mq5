//+------------------------------------------------------------------+
//|  RSI_SinglePosition.mq5                                          |
//|  Educational single-position RSI mean-reversion EA for MT5       |
//|  教学示例：单仓 RSI 超买超卖 EA(每次只一单,固定止盈止损)      |
//|                                                                  |
//|  Part of the QuantForge free MT5 EA library                      |
//|  完整免费源码库 / Full free library: https://luvstepwear.com/    |
//|  License: MIT. Research & education only. 风险自负,不承诺收益。  |
//+------------------------------------------------------------------+
#property copyright "QuantForge (luvstepwear.com)"
#property link      "https://luvstepwear.com/"
#property version   "1.00"
#property description "Educational single-position RSI EA: buy oversold / sell overbought, fixed TP/SL. Backtest first; no profit guaranteed."

#include <Trade/Trade.mqh>

input double InpLots        = 0.01;     // Lot size / 手数
input int    InpRSIPeriod   = 14;       // RSI period / RSI 周期
input int    InpOversold    = 30;       // Buy below this / 低于此值做多
input int    InpOverbought  = 70;       // Sell above this / 高于此值做空
input int    InpTakeProfit  = 400;      // TP in points / 止盈(点)
input int    InpStopLoss    = 300;      // SL in points / 止损(点)
input ulong  InpMagic       = 20260620; // Magic number / 魔术号

CTrade trade;
int    rsiHandle = INVALID_HANDLE;
double rsiBuf[];

int OnInit()
{
   rsiHandle = iRSI(_Symbol, _Period, InpRSIPeriod, PRICE_CLOSE);
   if(rsiHandle == INVALID_HANDLE) { Print("Failed to create RSI handle"); return(INIT_FAILED); }
   ArraySetAsSeries(rsiBuf, true);
   trade.SetExpertMagicNumber(InpMagic);
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   if(rsiHandle != INVALID_HANDLE) IndicatorRelease(rsiHandle);
}

// 本 EA 是否已有持仓(实现"单仓") / one position at a time
bool HasPosition()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         PositionGetInteger(POSITION_MAGIC)  == (long)InpMagic)
         return(true);
   }
   return(false);
}

void OnTick()
{
   // 每根新K线判断一次 / act once per new bar
   static datetime lastBar = 0;
   datetime curBar = (datetime)SeriesInfoInteger(_Symbol, _Period, SERIES_LASTBAR_DATE);
   if(curBar == lastBar) return;
   lastBar = curBar;

   if(HasPosition()) return;                       // 已有持仓则不再开
   if(CopyBuffer(rsiHandle, 0, 0, 2, rsiBuf) < 2) return;

   double rsi = rsiBuf[0];
   double point = _Point;

   if(rsi < InpOversold)            // 超卖 → 做多 / oversold -> buy
   {
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      trade.Buy(InpLots, _Symbol, ask, ask - InpStopLoss*point, ask + InpTakeProfit*point, "RSI sample");
   }
   else if(rsi > InpOverbought)     // 超买 → 做空 / overbought -> sell
   {
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      trade.Sell(InpLots, _Symbol, bid, bid + InpStopLoss*point, bid - InpTakeProfit*point, "RSI sample");
   }
}
//+------------------------------------------------------------------+

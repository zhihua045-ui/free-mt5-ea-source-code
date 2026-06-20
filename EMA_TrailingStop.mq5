//+------------------------------------------------------------------+
//|  EMA_TrailingStop.mq5                                            |
//|  Educational single-position EMA trend EA with trailing stop     |
//|  教学示例：单仓 EMA 趋势 + 追踪止损 EA                            |
//|                                                                  |
//|  Part of the QuantForge free MT5 EA library                      |
//|  完整免费源码库 / Full free library: https://luvstepwear.com/    |
//|  License: MIT. Research & education only. 风险自负,不承诺收益。  |
//+------------------------------------------------------------------+
#property copyright "QuantForge (luvstepwear.com)"
#property link      "https://luvstepwear.com/"
#property version   "1.00"
#property description "Educational single-position EMA EA with a trailing stop. Backtest first; no profit guaranteed."

#include <Trade/Trade.mqh>

input double InpLots        = 0.01;     // Lot size / 手数
input int    InpEmaPeriod   = 50;       // EMA period / EMA 周期
input int    InpStopLoss    = 300;      // Initial SL points / 初始止损(点)
input int    InpTrailStart  = 150;      // Profit before trailing / 启动追踪的盈利(点)
input int    InpTrailDist   = 200;      // Trailing distance / 追踪距离(点)
input ulong  InpMagic       = 20260621; // Magic number / 魔术号

CTrade trade;
int    emaHandle = INVALID_HANDLE;
double emaBuf[];

int OnInit()
{
   emaHandle = iMA(_Symbol, _Period, InpEmaPeriod, 0, MODE_EMA, PRICE_CLOSE);
   if(emaHandle == INVALID_HANDLE) { Print("Failed to create EMA handle"); return(INIT_FAILED); }
   ArraySetAsSeries(emaBuf, true);
   trade.SetExpertMagicNumber(InpMagic);
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   if(emaHandle != INVALID_HANDLE) IndicatorRelease(emaHandle);
}

// 返回本 EA 持仓的 ticket(没有则 0) / ticket of this EA's position, or 0
ulong MyPositionTicket()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         PositionGetInteger(POSITION_MAGIC)  == (long)InpMagic)
         return(ticket);
   }
   return(0);
}

// 追踪止损:盈利达到阈值后,把止损跟到 价格-追踪距离 / move SL once in profit
void ManageTrailing(ulong ticket)
{
   if(!PositionSelectByTicket(ticket)) return;
   long   type  = PositionGetInteger(POSITION_TYPE);
   double open  = PositionGetDouble(POSITION_PRICE_OPEN);
   double sl    = PositionGetDouble(POSITION_SL);
   double tp    = PositionGetDouble(POSITION_TP);
   double point = _Point;

   if(type == POSITION_TYPE_BUY)
   {
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(bid - open >= InpTrailStart*point)
      {
         double newSl = bid - InpTrailDist*point;
         if(newSl > sl) trade.PositionModify(ticket, newSl, tp);
      }
   }
   else if(type == POSITION_TYPE_SELL)
   {
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(open - ask >= InpTrailStart*point)
      {
         double newSl = ask + InpTrailDist*point;
         if(sl == 0 || newSl < sl) trade.PositionModify(ticket, newSl, tp);
      }
   }
}

void OnTick()
{
   ulong ticket = MyPositionTicket();

   // 有持仓:每个 tick 维护追踪止损 / manage trailing every tick
   if(ticket != 0) { ManageTrailing(ticket); return; }

   // 无持仓:每根新K线按 EMA 方向开一单 / open once per new bar by EMA
   static datetime lastBar = 0;
   datetime curBar = (datetime)SeriesInfoInteger(_Symbol, _Period, SERIES_LASTBAR_DATE);
   if(curBar == lastBar) return;
   lastBar = curBar;

   if(CopyBuffer(emaHandle, 0, 0, 2, emaBuf) < 2) return;
   double ema = emaBuf[0], point = _Point;
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   if(bid > ema)        // 趋势向上 → 做多 / uptrend -> buy
      trade.Buy(InpLots, _Symbol, ask, ask - InpStopLoss*point, 0, "EMA trail sample");
   else if(bid < ema)   // 趋势向下 → 做空 / downtrend -> sell
      trade.Sell(InpLots, _Symbol, bid, bid + InpStopLoss*point, 0, "EMA trail sample");
}
//+------------------------------------------------------------------+

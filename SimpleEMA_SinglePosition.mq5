//+------------------------------------------------------------------+
//|  SimpleEMA_SinglePosition.mq5                                    |
//|  Educational single-position EMA-trend EA for MetaTrader 5 (MT5) |
//|  教学示例：单仓 EMA 趋势 EA（每次只一单，固定止盈止损）          |
//|                                                                  |
//|  Part of the QuantForge free MT5 EA library                      |
//|  完整免费源码库 / Full free library: https://luvstepwear.com/    |
//|                                                                  |
//|  License: MIT.  For research & education only.                   |
//|  仅供研究与学习，不构成投资建议，不承诺收益，交易有风险自负盈亏。|
//+------------------------------------------------------------------+
#property copyright "QuantForge (luvstepwear.com)"
#property link      "https://luvstepwear.com/"
#property version   "1.00"
#property description "Educational single-position EMA trend EA. One position at a time, fixed TP/SL. Backtest before use; no profit is guaranteed."

#include <Trade/Trade.mqh>

//--- inputs / 可调参数
input double InpLots       = 0.01;      // Lot size / 手数
input int    InpEmaPeriod  = 50;        // EMA period / EMA 周期
input int    InpTakeProfit = 300;       // Take profit in points / 止盈(点)
input int    InpStopLoss   = 200;       // Stop loss in points / 止损(点)
input ulong  InpMagic      = 20260619;  // Magic number / 魔术号

CTrade  trade;
int     emaHandle = INVALID_HANDLE;
double  emaBuf[];

//+------------------------------------------------------------------+
int OnInit()
{
   emaHandle = iMA(_Symbol, _Period, InpEmaPeriod, 0, MODE_EMA, PRICE_CLOSE);
   if(emaHandle == INVALID_HANDLE)
   {
      Print("Failed to create EMA handle");
      return(INIT_FAILED);
   }
   ArraySetAsSeries(emaBuf, true);
   trade.SetExpertMagicNumber(InpMagic);
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(emaHandle != INVALID_HANDLE)
      IndicatorRelease(emaHandle);
}

//--- Does this EA already hold a position on this symbol?
//--- 本 EA 在该品种上是否已有持仓(实现"单仓")
bool HasPosition()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         PositionGetInteger(POSITION_MAGIC) == (long)InpMagic)
         return(true);
   }
   return(false);
}

//+------------------------------------------------------------------+
void OnTick()
{
   //--- act once per new bar / 每根新K线只判断一次
   static datetime lastBar = 0;
   datetime curBar = (datetime)SeriesInfoInteger(_Symbol, _Period, SERIES_LASTBAR_DATE);
   if(curBar == lastBar) return;
   lastBar = curBar;

   //--- single position: skip if already in a trade / 单仓:已有持仓则不再开
   if(HasPosition()) return;

   if(CopyBuffer(emaHandle, 0, 0, 2, emaBuf) < 2) return;

   double ema = emaBuf[0];
   double point = _Point;
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   if(bid > ema)        // price above EMA -> long / 价格在 EMA 上方做多
   {
      double tp = ask + InpTakeProfit * point;
      double sl = ask - InpStopLoss   * point;
      trade.Buy(InpLots, _Symbol, ask, sl, tp, "QuantForge sample");
   }
   else if(bid < ema)   // price below EMA -> short / 价格在 EMA 下方做空
   {
      double tp = bid - InpTakeProfit * point;
      double sl = bid + InpStopLoss   * point;
      trade.Sell(InpLots, _Symbol, bid, sl, tp, "QuantForge sample");
   }
}
//+------------------------------------------------------------------+

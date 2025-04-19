//+------------------------------------------------------------------+
//|                                    parakh3.mq4                   |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property link      ""
#property version   "1.00"
#property strict

// Input Parameters
input double LotSize = 0.1;
input double ATR_Period = 14;
input double Multiplier_SL = 1.5;
input double Multiplier_TP = 2.0;
input int EMA_Long = 50;
input int EMA_Medium = 21;
input int EMA_Short = 9;
input bool AllowBuyTrades = true;
input bool AllowSellTrades = true;

// Global variables
int ticket;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("Parakh3 EMA Crossover Initialized");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("Parakh3 EMA Crossover Deinitialized");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Calculate ATR
   double atr = iATR(NULL, 0, ATR_Period, 1);
   
   // Calculate EMAs
   double ema_long = iMA(NULL, 0, EMA_Long, 0, MODE_EMA, PRICE_CLOSE, 1);
   double ema_medium = iMA(NULL, 0, EMA_Medium, 0, MODE_EMA, PRICE_CLOSE, 1);
   double ema_short = iMA(NULL, 0, EMA_Short, 0, MODE_EMA, PRICE_CLOSE, 1);
   
   // Previous values for crossover detection
   double ema_medium_prev = iMA(NULL, 0, EMA_Medium, 0, MODE_EMA, PRICE_CLOSE, 2);
   double ema_short_prev = iMA(NULL, 0, EMA_Short, 0, MODE_EMA, PRICE_CLOSE, 2);
   
   // Check for buy conditions
   bool buySignal = false;
   if(AllowBuyTrades && OrdersTotal() == 0)
   {
      // 9 EMA crossing above 21 EMA
      if(ema_short_prev <= ema_medium_prev && ema_short > ema_medium)
      {
         // Both EMAs above 50 EMA
         if(ema_short > ema_long && ema_medium > ema_long)
         {
            buySignal = true;
         }
      }
   }
   
   // Check for sell conditions
   bool sellSignal = false;
   if(AllowSellTrades && OrdersTotal() == 0)
   {
      // 9 EMA crossing below 21 EMA
      if(ema_short_prev >= ema_medium_prev && ema_short < ema_medium)
      {
         // Both EMAs below 50 EMA
         if(ema_short < ema_long && ema_medium < ema_long)
         {
            sellSignal = true;
         }
      }
   }
   
   // Execute buy order
   if(buySignal)
   {
      double sl = NormalizeDouble(Ask - Multiplier_SL * atr, Digits);
      double tp = NormalizeDouble(Ask + Multiplier_TP * atr, Digits);
      
      ticket = OrderSend(Symbol(), OP_BUY, LotSize, Ask, 3, sl, tp, "Parakh3 Buy", 0, 0, Blue);
      if(ticket < 0)
         Print("Buy order failed with error #", GetLastError());
      else
         Print("Buy order executed - SL: ", sl, " TP: ", tp);
   }
   
   // Execute sell order
   if(sellSignal)
   {
      double sl = NormalizeDouble(Bid + Multiplier_SL * atr, Digits);
      double tp = NormalizeDouble(Bid - Multiplier_TP * atr, Digits);
      
      ticket = OrderSend(Symbol(), OP_SELL, LotSize, Bid, 3, sl, tp, "Parakh3 Sell", 0, 0, Red);
      if(ticket < 0)
         Print("Sell order failed with error #", GetLastError());
      else
         Print("Sell order executed - SL: ", sl, " TP: ", tp);
   }
}
//+------------------------------------------------------------------+
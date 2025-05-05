//+------------------------------------------------------------------+
//|                                             Orion Gold Scalper.mq4 |
//|                                              Copyright 2025, User |
//|                                                                   |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, User"
#property link      ""
#property version   "1.00"
#property strict

// EA Settings
extern string    EA_Settings     = "----- EA Settings -----";
extern int       AccountNumber   = 0;               // Account number (0 = no check)
extern double    LotSize         = 0.01;            // Fixed lot size for each trade
extern int       MaxTrades       = 200;             // Maximum number of trades
extern double    MaxDrawdown     = 100;             // Maximum drawdown (%)
extern double    GridStep        = 2.0;             // Price distance between grid positions (points)
extern double    TakeProfit      = 100.0;           // Take profit for each position (points)
extern double    BasketTP        = 20.0;            // Basket take profit in USD
extern int       MagicNumber     = 12345;           // Magic number for identification
extern bool      AutoInitialTrade = true;           // Automatically open first trade on EA start
extern bool      TradeBuys       = true;            // Enable buy positions
extern bool      TradeSells      = true;            // Enable sell positions

// Global Variables
string   SymbolToTrade = "XAUUSD";                  // Symbol to trade
double   AccountBalance;                            // Account balance
double   AccountEquity;                             // Account equity
double   FloatingProfit;                            // Current floating profit
double   ClosedProfit;                              // Closed profit
double   CombinedProfit;                            // Combined profit (Floating + Closed)
bool     IsNewCandle;                               // Flag for new candle
double   LastPrice;                                 // Last price for tracking
double   NextBuyGridLevel;                          // Next price level for buy grid trade
double   NextSellGridLevel;                         // Next price level for sell grid trade
double   FixedBuyTargetPrice;                       // Fixed target price for all buy trades
double   FixedSellTargetPrice;                      // Fixed target price for all sell trades
double   PointMultiplier;                           // Point multiplier for Gold (typically 10)

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Check for valid account number if set
   if(AccountNumber > 0 && AccountInfoInteger(ACCOUNT_LOGIN) != AccountNumber)
   {
      Print("Invalid account number!");
      return INIT_FAILED;
   }
   
   // Set the symbol to the current chart symbol if not using XAUUSD
   if(StringCompare(Symbol(), "XAUUSD") == 0) {
      SymbolToTrade = "XAUUSD";
   }
   else {
      SymbolToTrade = Symbol();
      Print("Trading on symbol: ", SymbolToTrade);
   }
   
   // Initialize variables
   AccountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   AccountEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   FloatingProfit = 0;
   ClosedProfit = 0;
   CombinedProfit = 0;
   LastPrice = SymbolInfoDouble(SymbolToTrade, SYMBOL_ASK);
   
   // Set point multiplier based on digits
   if(Digits >= 3)
      PointMultiplier = 10.0;
   else
      PointMultiplier = 1.0;
      
   // Special case for Gold which has 3 digits but needs special handling
   if(StringFind(SymbolToTrade, "XAU") >= 0)
      PointMultiplier = 10.0;
   
   Print("Symbol: ", SymbolToTrade, ", Digits: ", Digits, ", Point: ", Point(), ", PointMultiplier: ", PointMultiplier);
   
   // Initialize grid levels for buy and sell
   NextBuyGridLevel = NormalizeDouble(LastPrice - GridStep * Point() * PointMultiplier, Digits);
   NextSellGridLevel = NormalizeDouble(LastPrice + GridStep * Point() * PointMultiplier, Digits);
   
   // Initialize target prices for buy and sell
   FixedBuyTargetPrice = NormalizeDouble(LastPrice + TakeProfit * Point() * PointMultiplier, Digits);
   FixedSellTargetPrice = NormalizeDouble(LastPrice - TakeProfit * Point() * PointMultiplier, Digits);
   
   Print("Initial Price: ", LastPrice);
   Print("Next Buy Grid Level: ", NextBuyGridLevel);
   Print("Next Sell Grid Level: ", NextSellGridLevel);
   Print("Initial Buy Target Price: ", FixedBuyTargetPrice);
   Print("Initial Sell Target Price: ", FixedSellTargetPrice);
   
   // Create screen labels
   CreateLabels();
   
   // Open initial trades if enabled
   if(AutoInitialTrade) {
      if(TradeBuys && CountTrades(OP_BUY) == 0) {
         Print("Opening initial buy trade on startup");
         OpenBuyOrder();
      }
      if(TradeSells && CountTrades(OP_SELL) == 0) {
         Print("Opening initial sell trade on startup");
         OpenSellOrder();
      }
   }
   
   // Success
   Print("Orion Gold Scalper - ACTIVE");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Delete all objects
   ObjectsDeleteAll(0, "EA_Label_");
   
   Print("Orion Gold Scalper - STOPPED");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Check for new candle
   IsNewCandle = IsNewBar();
   
   // Update account stats
   UpdateStats();
   
   // Update screen info
   if(IsNewCandle) UpdateScreenInfo();
   
   // Check for basket take profit
   if(CheckBasketTP()) return;
   
   // Check for maximum trades
   if(CountTrades() >= MaxTrades) return;
   
   // Check for maximum drawdown
   if(CheckDrawdown()) return;
   
   // Get current price
   double currentAsk = SymbolInfoDouble(SymbolToTrade, SYMBOL_ASK);
   double currentBid = SymbolInfoDouble(SymbolToTrade, SYMBOL_BID);
   
   // Check if we need to open a new buy grid position
   if(TradeBuys && currentBid <= NextBuyGridLevel)
   {
      // Open a new buy position
      if(OpenBuyOrder())
      {
         // Update the next grid level
         NextBuyGridLevel = NormalizeDouble(currentBid - GridStep * Point() * PointMultiplier, Digits);
         Print("New buy grid level set: ", NextBuyGridLevel);
      }
   }
   
   // Check if we need to open a new sell grid position
   if(TradeSells && currentAsk >= NextSellGridLevel)
   {
      // Open a new sell position
      if(OpenSellOrder())
      {
         // Update the next grid level
         NextSellGridLevel = NormalizeDouble(currentAsk + GridStep * Point() * PointMultiplier, Digits);
         Print("New sell grid level set: ", NextSellGridLevel);
      }
   }
   
   // Initial trades if none exist
   if(TradeBuys && CountTrades(OP_BUY) == 0)
   {
      Print("No buy trades found. Opening initial buy trade at: ", currentAsk);
      OpenBuyOrder();
      NextBuyGridLevel = NormalizeDouble(currentBid - GridStep * Point() * PointMultiplier, Digits);
      Print("Next buy grid level after initial trade: ", NextBuyGridLevel);
   }
   
   if(TradeSells && CountTrades(OP_SELL) == 0)
   {
      Print("No sell trades found. Opening initial sell trade at: ", currentBid);
      OpenSellOrder();
      NextSellGridLevel = NormalizeDouble(currentAsk + GridStep * Point() * PointMultiplier, Digits);
      Print("Next sell grid level after initial trade: ", NextSellGridLevel);
   }
   
   // Update fixed target prices for all trades if there are open trades
   if(CountTrades() > 0)
   {
      // Update target prices for all trades
      UpdateTargetPrices();
   }
}

//+------------------------------------------------------------------+
//| Check for a new bar                                              |
//+------------------------------------------------------------------+
bool IsNewBar()
{
   static datetime lastBarTime = 0;
   datetime currentBarTime = iTime(SymbolToTrade, PERIOD_H1, 0);
   
   if(lastBarTime != currentBarTime)
   {
      lastBarTime = currentBarTime;
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Update account statistics                                        |
//+------------------------------------------------------------------+
void UpdateStats()
{
   // Update account info
   AccountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   AccountEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   
   // Calculate floating profit
   FloatingProfit = 0;
   
   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderSymbol() == SymbolToTrade && OrderMagicNumber() == MagicNumber)
         {
            FloatingProfit += OrderProfit() + OrderSwap() + OrderCommission();
         }
      }
   }
   
   // Calculate closed profit (simplified - would need history access for accurate tracking)
   ClosedProfit = AccountBalance - AccountInfoDouble(ACCOUNT_CREDIT);
   
   // Combined profit
   CombinedProfit = FloatingProfit + ClosedProfit;
}

//+------------------------------------------------------------------+
//| Count current trades                                             |
//+------------------------------------------------------------------+
int CountTrades(int orderType = -1)
{
   int count = 0;
   
   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderSymbol() == SymbolToTrade && OrderMagicNumber() == MagicNumber)
         {
            if(orderType == -1 || OrderType() == orderType)
            {
               count++;
            }
         }
      }
   }
   
   return count;
}

//+------------------------------------------------------------------+
//| Check drawdown against maximum allowed                           |
//+------------------------------------------------------------------+
bool CheckDrawdown()
{
   double drawdownPercent = (1 - AccountEquity / AccountBalance) * 100;
   
   if(drawdownPercent >= MaxDrawdown)
   {
      Print("Maximum drawdown reached: ", drawdownPercent, "%");
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Check basket take profit                                         |
//+------------------------------------------------------------------+
bool CheckBasketTP()
{
   // Check if floating profit exceeds basket take profit
   if(FloatingProfit >= BasketTP && CountTrades() > 0)
   {
      Print("Basket take profit reached: $", FloatingProfit, " >= $", BasketTP);
      CloseAllTrades();
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Close all trades                                                 |
//+------------------------------------------------------------------+
void CloseAllTrades()
{
   // Close all trades for this symbol
   Print("Closing all trades due to basket take profit...");
   
   // First close all buy positions
   int total = OrdersTotal();
   for(int i = total - 1; i >= 0; i--)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderSymbol() == SymbolToTrade && OrderMagicNumber() == MagicNumber)
         {
            if(OrderType() == OP_BUY)
            {
               double closingPrice = SymbolInfoDouble(SymbolToTrade, SYMBOL_BID);
               if(!OrderClose(OrderTicket(), OrderLots(), closingPrice, 50, Green))
               {
                  int error = GetLastError();
                  Print("Error closing buy order #", OrderTicket(), ": ", error, " - ", ErrorDescription(error));
               }
               else
               {
                  Print("Successfully closed buy order #", OrderTicket());
               }
            }
         }
      }
   }
   
   // Then close all sell positions
   total = OrdersTotal();
   for(int i = total - 1; i >= 0; i--)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderSymbol() == SymbolToTrade && OrderMagicNumber() == MagicNumber)
         {
            if(OrderType() == OP_SELL)
            {
               double closingPrice = SymbolInfoDouble(SymbolToTrade, SYMBOL_ASK);
               if(!OrderClose(OrderTicket(), OrderLots(), closingPrice, 50, Red))
               {
                  int error = GetLastError();
                  Print("Error closing sell order #", OrderTicket(), ": ", error, " - ", ErrorDescription(error));
               }
               else
               {
                  Print("Successfully closed sell order #", OrderTicket());
               }
            }
         }
      }
   }
   
   // Reset grid levels after closing all trades
   double currentAsk = SymbolInfoDouble(SymbolToTrade, SYMBOL_ASK);
   double currentBid = SymbolInfoDouble(SymbolToTrade, SYMBOL_BID);
   
   NextBuyGridLevel = NormalizeDouble(currentBid - GridStep * Point() * PointMultiplier, Digits);
   NextSellGridLevel = NormalizeDouble(currentAsk + GridStep * Point() * PointMultiplier, Digits);
   
   Print("Basket take profit executed. All trades closed. New grid levels set.");
}

//+------------------------------------------------------------------+
//| Open a buy order                                                |
//+------------------------------------------------------------------+
bool OpenBuyOrder()
{
   double sl = 0; // We don't use stop loss in this EA
   
   // Set target price based on current price
   double ask = SymbolInfoDouble(SymbolToTrade, SYMBOL_ASK);
   
   // Calculate target price (important for backtesting)
   double targetPrice = NormalizeDouble(ask + TakeProfit * Point() * PointMultiplier, Digits);
   FixedBuyTargetPrice = targetPrice; // Update the global target
   
   Print("Opening BUY order at ", ask, " with target: ", targetPrice);
   
   // Open the buy order
   int ticket = OrderSend(SymbolToTrade, OP_BUY, LotSize, ask, 50, sl, targetPrice, "Orion Gold Scalper", MagicNumber, 0, Green);
   
   if(ticket < 0)
   {
      int error = GetLastError();
      Print("OrderSend error: ", error, " - ", ErrorDescription(error));
      Print("Symbol: ", SymbolToTrade, ", Bid: ", SymbolInfoDouble(SymbolToTrade, SYMBOL_BID), 
            ", Ask: ", ask, ", Lots: ", LotSize, ", TP: ", targetPrice);
      return false;
   }
   
   Print("Buy order opened successfully, ticket: ", ticket);
   return true;
}

//+------------------------------------------------------------------+
//| Open a sell order                                                |
//+------------------------------------------------------------------+
bool OpenSellOrder()
{
   double sl = 0; // We don't use stop loss in this EA
   
   // Set target price based on current price
   double bid = SymbolInfoDouble(SymbolToTrade, SYMBOL_BID);
   
   // Calculate target price (important for backtesting)
   double targetPrice = NormalizeDouble(bid - TakeProfit * Point() * PointMultiplier, Digits);
   FixedSellTargetPrice = targetPrice; // Update the global target
   
   Print("Opening SELL order at ", bid, " with target: ", targetPrice);
   
   // Open the sell order
   int ticket = OrderSend(SymbolToTrade, OP_SELL, LotSize, bid, 50, sl, targetPrice, "Orion Gold Scalper", MagicNumber, 0, Red);
   
   if(ticket < 0)
   {
      int error = GetLastError();
      Print("OrderSend error: ", error, " - ", ErrorDescription(error));
      Print("Symbol: ", SymbolToTrade, ", Bid: ", bid, 
            ", Ask: ", SymbolInfoDouble(SymbolToTrade, SYMBOL_ASK), ", Lots: ", LotSize, ", TP: ", targetPrice);
      return false;
   }
   
   Print("Sell order opened successfully, ticket: ", ticket);
   return true;
}

//+------------------------------------------------------------------+
//| Update the take profit for all open trades                       |
//+------------------------------------------------------------------+
void UpdateTargetPrices()
{
   // Get current prices
   double ask = SymbolInfoDouble(SymbolToTrade, SYMBOL_ASK);
   double bid = SymbolInfoDouble(SymbolToTrade, SYMBOL_BID);
   
   // Calculate new target prices
   double newBuyTargetPrice = NormalizeDouble(ask + TakeProfit * Point() * PointMultiplier, Digits);
   double newSellTargetPrice = NormalizeDouble(bid - TakeProfit * Point() * PointMultiplier, Digits);
   
   // Update buy target prices if significant change
   if(MathAbs(FixedBuyTargetPrice - newBuyTargetPrice) > Point())
   {
      Print("Updating fixed buy target price from ", FixedBuyTargetPrice, " to ", newBuyTargetPrice);
      
      // Update fixed target price
      FixedBuyTargetPrice = newBuyTargetPrice;
      
      // Update all open buy trades to have this target
      for(int i = 0; i < OrdersTotal(); i++)
      {
         if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         {
            if(OrderSymbol() == SymbolToTrade && OrderMagicNumber() == MagicNumber && OrderType() == OP_BUY)
            {
               // Only modify if the take profit is different
               if(MathAbs(OrderTakeProfit() - FixedBuyTargetPrice) > Point())
               {
                  Print("Modifying buy order #", OrderTicket(), " TP from ", OrderTakeProfit(), " to ", FixedBuyTargetPrice);
                  
                  // Update the take profit
                  if(!OrderModify(OrderTicket(), OrderOpenPrice(), OrderStopLoss(), FixedBuyTargetPrice, 0, Green))
                  {
                     int error = GetLastError();
                     Print("OrderModify error for ticket #", OrderTicket(), ": ", error, " - ", ErrorDescription(error));
                  }
                  else
                  {
                     Print("Buy order #", OrderTicket(), " modified successfully");
                  }
               }
            }
         }
      }
   }
   
   // Update sell target prices if significant change
   if(MathAbs(FixedSellTargetPrice - newSellTargetPrice) > Point())
   {
      Print("Updating fixed sell target price from ", FixedSellTargetPrice, " to ", newSellTargetPrice);
      
      // Update fixed target price
      FixedSellTargetPrice = newSellTargetPrice;
      
      // Update all open sell trades to have this target
      for(int i = 0; i < OrdersTotal(); i++)
      {
         if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         {
            if(OrderSymbol() == SymbolToTrade && OrderMagicNumber() == MagicNumber && OrderType() == OP_SELL)
            {
               // Only modify if the take profit is different
               if(MathAbs(OrderTakeProfit() - FixedSellTargetPrice) > Point())
               {
                  Print("Modifying sell order #", OrderTicket(), " TP from ", OrderTakeProfit(), " to ", FixedSellTargetPrice);
                  
                  // Update the take profit
                  if(!OrderModify(OrderTicket(), OrderOpenPrice(), OrderStopLoss(), FixedSellTargetPrice, 0, Red))
                  {
                     int error = GetLastError();
                     Print("OrderModify error for ticket #", OrderTicket(), ": ", error, " - ", ErrorDescription(error));
                  }
                  else
                  {
                     Print("Sell order #", OrderTicket(), " modified successfully");
                  }
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Return error description                                         |
//+------------------------------------------------------------------+
string ErrorDescription(int error_code)
{
   string error_string;
   
   switch(error_code)
   {
      case 0:   error_string = "No error";                                                   break;
      case 1:   error_string = "No error, but the result is unknown";                        break;
      case 2:   error_string = "Common error";                                               break;
      case 3:   error_string = "Invalid trade parameters";                                   break;
      case 4:   error_string = "Trade server is busy";                                       break;
      case 5:   error_string = "Old version of the client terminal";                         break;
      case 6:   error_string = "No connection with trade server";                            break;
      case 7:   error_string = "Not enough rights";                                          break;
      case 8:   error_string = "Too frequent requests";                                      break;
      case 9:   error_string = "Malfunctional trade operation";                              break;
      case 64:  error_string = "Account disabled";                                           break;
      case 65:  error_string = "Invalid account";                                            break;
      case 128: error_string = "Trade timeout";                                              break;
      case 129: error_string = "Invalid price";                                              break;
      case 130: error_string = "Invalid stops";                                              break;
      case 131: error_string = "Invalid trade volume";                                       break;
      case 132: error_string = "Market is closed";                                           break;
      case 133: error_string = "Trade is disabled";                                          break;
      case 134: error_string = "Not enough money";                                           break;
      case 135: error_string = "Price changed";                                              break;
      case 136: error_string = "Off quotes";                                                 break;
      case 137: error_string = "Broker is busy";                                             break;
      case 138: error_string = "Requote";                                                    break;
      case 139: error_string = "Order is locked";                                            break;
      case 140: error_string = "Long positions only allowed";                                break;
      case 141: error_string = "Too many requests";                                          break;
      case 145: error_string = "Modification denied because order too close to market";      break;
      case 146: error_string = "Trade context is busy";                                      break;
      case 147: error_string = "Expirations are denied by broker";                           break;
      case 148: error_string = "Amount of open and pending orders has reached the limit";    break;
      case 4000: error_string = "No error";                                                  break;
      case 4001: error_string = "Wrong function pointer";                                    break;
      case 4002: error_string = "Array index is out of range";                               break;
      case 4003: error_string = "No memory for function call stack";                         break;
      case 4004: error_string = "Recursive stack overflow";                                  break;
      case 4005: error_string = "Not enough stack for parameter";                            break;
      case 4006: error_string = "No memory for parameter string";                            break;
      case 4007: error_string = "No memory for temp string";                                 break;
      case 4008: error_string = "Not initialized string";                                    break;
      case 4009: error_string = "Not initialized string in array";                           break;
      case 4010: error_string = "No memory for array string";                                break;
      case 4011: error_string = "Too long string";                                           break;
      case 4012: error_string = "Remainder from zero divide";                                break;
      case 4013: error_string = "Zero divide";                                               break;
      case 4014: error_string = "Unknown command";                                           break;
      case 4015: error_string = "Wrong jump";                                                break;
      case 4016: error_string = "Not initialized array";                                     break;
      case 4017: error_string = "DLL calls are not allowed";                                 break;
      case 4018: error_string = "Cannot load library";                                       break;
      case 4019: error_string = "Cannot call function";                                      break;
      case 4020: error_string = "Expert function calls are not allowed";                     break;
      case 4021: error_string = "Not enough memory for temp string returned from function";  break;
      case 4022: error_string = "System is busy";                                            break;
      case 4050: error_string = "Invalid function parameters count";                         break;
      case 4051: error_string = "Invalid function parameter value";                          break;
      case 4052: error_string = "String function internal error";                            break;
      case 4053: error_string = "Some array error";                                          break;
      case 4054: error_string = "Incorrect series array using";                              break;
      case 4055: error_string = "Custom indicator error";                                    break;
      case 4056: error_string = "Arrays are incompatible";                                   break;
      case 4057: error_string = "Global variables processing error";                         break;
      case 4058: error_string = "Global variable not found";                                 break;
      case 4059: error_string = "Function is not allowed in testing mode";                   break;
      case 4060: error_string = "Function is not confirmed";                                 break;
      case 4061: error_string = "Send mail error";                                           break;
      case 4062: error_string = "String parameter expected";                                 break;
      case 4063: error_string = "Integer parameter expected";                                break;
      case 4064: error_string = "Double parameter expected";                                 break;
      case 4065: error_string = "Array as parameter expected";                               break;
      case 4066: error_string = "Requested history data in update state";                    break;
      case 4099: error_string = "End of file";                                               break;
      case 4100: error_string = "Some file error";                                           break;
      case 4101: error_string = "Wrong file name";                                           break;
      case 4102: error_string = "Too many opened files";                                     break;
      case 4103: error_string = "Cannot open file";                                          break;
      case 4104: error_string = "Incompatible access to a file";                             break;
      case 4105: error_string = "No order selected";                                         break;
      case 4106: error_string = "Unknown symbol";                                            break;
      case 4107: error_string = "Invalid price parameter for trade function";                break;
      case 4108: error_string = "Invalid ticket";                                            break;
      case 4109: error_string = "Trade is not allowed in the expert properties";             break;
      case 4110: error_string = "Longs are not allowed in the expert properties";            break;
      case 4111: error_string = "Shorts are not allowed in the expert properties";           break;
      default:   error_string = "Unknown error";
   }
   
   return error_string;
}

//+------------------------------------------------------------------+
//| Create screen labels for statistics                              |
//+------------------------------------------------------------------+
void CreateLabels()
{
   // Title
   CreateLabel("EA_Label_Title", "ORION GOLD SCALPER - ACTIVE", 10, 10, Gold, 12, true);
   
   // Trading Settings Section
   CreateLabel("EA_Label_Settings_Title", "TRADING SETTINGS", 10, 40, White, 10, true);
   CreateLabel("EA_Label_Account", "Account Number: " + IntegerToString(AccountNumber), 10, 60, White, 10, false);
   CreateLabel("EA_Label_LotSize", "Lot Size: " + DoubleToString(LotSize, 2), 10, 80, White, 10, false);
   CreateLabel("EA_Label_Direction", "Direction: " + (TradeBuys ? "Buy" : "") + (TradeBuys && TradeSells ? " & " : "") + (TradeSells ? "Sell" : ""), 10, 100, White, 10, false);
   CreateLabel("EA_Label_BasketTP", "Basket TP: $" + DoubleToString(BasketTP, 2), 10, 120, White, 10, false);
   
   // Profit Statistics Section
   CreateLabel("EA_Label_Stats_Title", "PROFIT STATISTICS", 10, 150, White, 10, true);
   CreateLabel("EA_Label_Balance", "Balance: $0.00", 10, 170, White, 10, false);
   CreateLabel("EA_Label_Equity", "Equity: $0.00", 10, 190, White, 10, false);
   CreateLabel("EA_Label_Floating", "Floating Profit: $0.00", 10, 210, White, 10, false);
   CreateLabel("EA_Label_Closed", "Closed Profit: $0.00", 10, 230, White, 10, false);
   CreateLabel("EA_Label_Combined", "Combined Profit: $0.00", 10, 250, White, 10, false);
   
   // Risk Management Section
   CreateLabel("EA_Label_Risk_Title", "RISK MANAGEMENT", 10, 280, White, 10, true);
   CreateLabel("EA_Label_DrawDown", "Max Drawdown: " + DoubleToString(MaxDrawdown, 0) + "%", 10, 300, White, 10, false);
   CreateLabel("EA_Label_MaxTrades", "Max Trades: " + IntegerToString(MaxTrades), 10, 320, White, 10, false);
   CreateLabel("EA_Label_BuyTrades", "Buy Trades: 0", 10, 340, White, 10, false);
   CreateLabel("EA_Label_SellT
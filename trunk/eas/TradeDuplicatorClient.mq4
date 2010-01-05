//+------------------------------------------------------------------+
//|                                        TradeDuplicatorClient.mq4 |
//|                     Copyright © 2009, OpenThinking Software, LLC |
//|  Licensed under the Apache License, Version 2.0 (the "License")  |
//|  you may not use this file except in compliance with the License.|
//|  You may obtain a copy of the License at                         |
//|                                                                  |
//|               http://www.apache.org/licenses/LICENSE-2.0         |
//|                                                                  |
//|  Unless required by applicable law or agreed to in writing,      |
//|  software distributed under the License is distributed on an     |
//|  "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY          |
//|  KIND, either express or implied. See the License for the        |
//|  specific language governing permissions and limitations under   |
//|  the License.                                                    |
//|                              http://www.openthinkingsoftware.com |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2009 OpenThinking Software, LLC"
#property link      "http://www.openthinkingsoftware.com"

#import "TradeDuplicator.dll"

bool GetOrdersDetails(int orderCount, string orderSymbol, int& orderTicket[],  int& op[],
                      double& orderOpenPrice[], double& orderStoploss[],
                      double& orderTakeProfit[], double& orderLots[],
                      int returnedOrders[]);
bool ClearOrderTable();
bool GetOrderCount(int& orderCount[], string orderSymbol);
bool FinalizeOrderTable();
#import

#include <stdlib.mqh>
#include <stderror.mqh>

extern double SecondsBetweenPolling = 1;
extern int PipsAwayLimit = 20;
extern double LotMultiplier = 1;
extern int PipsDeviation = 20;
extern bool CleanStrays = true;

int    g_StoredOrderTicket[];             //    OrderTicket()
string g_StoredOrderSymbol[];             //    OrderSymbol()
int    g_StoredOrderType[];             //      OrderType()
double g_StoredOrderOpenPrice[];             //     OrderOpenPrice()
double g_StoredOrderLots[];             //     OrderLots()
double g_StoredOrderStopLoss[];             //     OrderStopLoss()
double g_StoredOrdeTakeProfit[];             //     OrderTakeProfit()

int    g_LocalOrderTicket[];             //    OrderTicket()
string g_LocalOrderSymbol[];             //    OrderSymbol()
int    g_LocalOrderType[];             //      OrderType()
double g_LocalOrderOpenPrice[];             //     OrderOpenPrice()
double g_LocalOrderLots[];             //     OrderLots()
double g_LocalOrderStopLoss[];             //     OrderStopLoss()
double g_LocalOrdeTakeProfit[];             //     OrderTakeProfit()

double dXPoint = 1;
int Slippage=10;

//+----------------------------------------------------------------------------+
//|  Custom indicator initialization function                                  |
//+----------------------------------------------------------------------------+
void init()
{
    if (!IsDllsAllowed())
    {
        Alert ("Please enable DLLs before using TradeDuplicatorClient. Go to Tools, Options, Expert Advisors and check Allow DLLs. Then press F7 and do the same on the Common tab. ");
    }

    if (!IsTradeAllowed())
    {
        Alert ("Please enable trading before using TradeDuplicatorClient. Go to Tools, Options, Expert Advisors and check Allow live trading. Then press F7 and do the same on the Common tab. ");

    }
    ResetOrderArray();
    if (CleanStrays == true)
        CloseStrayLocalOrders();
        
    if (Digits==3||Digits==5)
    {
        dXPoint=10;
        Slippage = Slippage * dXPoint;
    }

}

//+----------------------------------------------------------------------------+
//|  Custom indicator deinitialization function                                |
//+----------------------------------------------------------------------------+
void deinit()
{
}

//+----------------------------------------------------------------------------+
//|  Custom indicator iteration function                                       |
//+----------------------------------------------------------------------------+
void start()
{


    bool LoopFlag = true;
    int loopPoll = SecondsBetweenPolling * 1000;

    while (LoopFlag == true)
    {
        processTrades();

        if (SecondsBetweenPolling >= 1)
        {
            for (int i=0; i<SecondsBetweenPolling; i++)
            {
                Sleep(1000);
                if(IsStopped() == true) break;
            }
        }
        else
        {
            Sleep(loopPoll);
        }
        if(IsStopped() == true) break;
    }

}

void processTrades()
{
    double p=MarketInfo(Symbol(), MODE_POINT);

    int    d;
    int    i;
    int    in;


    int    ot;
    int    StoredOrderTicket[];             //    OrderTicket()
    int    StoredOrderType[];             //      OrderType()
    double StoredOrderOpenPrice[];             //     OrderOpenPrice()
    double StoredOrderStopLoss[];             //     OrderStopLoss()
    double StoredOrdeTakeProfit[];             //     OrderTakeProfit()
    double StoredOrderLots[];
    string StoredOrderSymbol[];
    string StoredOrderDateTime[];

    double closeprice;
    double newlots;
    int newCmd;
    double newPrice;
    bool okayToProcess = true;

    //First populate new array
    RetrieveOrders( StoredOrderTicket, StoredOrderType, StoredOrderOpenPrice,
                    StoredOrderLots, StoredOrderStopLoss, StoredOrdeTakeProfit);

    int    k=ArraySize(StoredOrderTicket);

    for (i=0; i<k; i++)
    {


        // Search for OrderTicket in old array
        in=ArraySearchInt(g_StoredOrderTicket, StoredOrderTicket[i]);

        // If not found trigger signal.
        if (in<0)
        {

            double pnow = 0.0;
            newlots = StoredOrderLots[i] * LotMultiplier;
 
            if (newlots < MarketInfo(Symbol(),MODE_MINLOT))
            {
                newlots = MarketInfo(Symbol(),MODE_MINLOT);
            }
            if (newlots > MarketInfo(Symbol(),MODE_MAXLOT))
            {
                newlots = MarketInfo(Symbol(),MODE_MAXLOT);
            }
 
 
            if (StoredOrderType[i] == OP_BUY)
            {
                pnow = NormalizeDouble(MarketInfo(Symbol(), MODE_ASK), MarketInfo(Symbol(), MODE_DIGITS)); // we are buying at Ask
            }
            else if (StoredOrderType[i] == OP_SELL)
            {
                pnow = NormalizeDouble(MarketInfo(Symbol(), MODE_BID), MarketInfo(Symbol(), MODE_DIGITS)); // we are buying at Ask
            }
            else
            {
                pnow = NormalizeDouble(StoredOrderOpenPrice[i], MarketInfo(Symbol(), MODE_DIGITS));
            }
 
 
            newCmd = StoredOrderType[i];
            newPrice = StoredOrderOpenPrice[i];
 
 
            if ((PipsDeviated(pnow, StoredOrderOpenPrice[i]) <= PipsDeviation)  && okayToProcess == true)
            {
 
 
                if (newCmd == OP_BUY || newCmd == OP_SELL)
                    BetterOrderSend2Step(Symbol(), newCmd, newlots, pnow,
                                   Slippage, StoredOrderStopLoss[i], StoredOrdeTakeProfit[i],
                                   "TradeDuplicator", StoredOrderTicket[i], 0, Blue);
                else
                {
                    BetterOrderSend2Step(Symbol(), newCmd, newlots, newPrice,
                                   Slippage, StoredOrderStopLoss[i], StoredOrdeTakeProfit[i],
                                   "TradeDuplicator", StoredOrderTicket[i], 0, Blue);
                }
            }
 
        }
        else
        {
 
            // Check to see if altered order
            if ((MathAbs(StoredOrderOpenPrice[i]-g_StoredOrderOpenPrice[in])>=p)
                    ||  (MathAbs(StoredOrderStopLoss[i]-g_StoredOrderStopLoss[in])>=p)
                    ||  (MathAbs(StoredOrdeTakeProfit[i]-g_StoredOrdeTakeProfit[in])>=p))
            {
 
                //Send modified order
                int modifyOrder = GetOrderByMagic(g_StoredOrderTicket[i]);
                if (modifyOrder > 0)
                {
                    if (OrderSelect(modifyOrder, SELECT_BY_TICKET, MODE_TRADES))
                        if (( OrderMagicNumber() == g_StoredOrderTicket[i] ))
                        {
                            if (OrderType() == OP_BUY || OrderType() == OP_SELL)
                                BetterOrderModify(OrderSymbol(), OrderTicket(), OrderOpenPrice(), StoredOrderStopLoss[i],
                                            StoredOrdeTakeProfit[i], 0,Blue);
                            else
                                BetterOrderModify(OrderSymbol(), OrderTicket(), StoredOrderOpenPrice[i], StoredOrderStopLoss[i],
                                            StoredOrdeTakeProfit[i], 0,Blue);
                        }
                }
 
            }
            //Check to see if partial Close
            if(StoredOrderLots[i] < g_StoredOrderLots[in])
            {
                int partialCloseOrder = GetOrderByMagic(g_StoredOrderTicket[i]);
                if (partialCloseOrder > 0)
                {
                    if (OrderSelect(partialCloseOrder, SELECT_BY_TICKET, MODE_TRADES))
 
                        if (( OrderMagicNumber() == StoredOrderTicket[i] ))
                        {
                            if ((OrderType() == OP_BUY))
                            {
                                BetterCloseBuy (OrderTicket(), g_StoredOrderLots[in] - StoredOrderLots[i], OrderSymbol());
                            }
                            else
                            {
                                BetterCloseSell (OrderTicket(), g_StoredOrderLots[in] - StoredOrderLots[i], OrderSymbol());
                            }
 
 
                        }
                }//for
 
            }
 
 
        }
    }
 
    k=ArraySize(g_StoredOrderTicket);
 
    for (i=0; i<k; i++)
    {
        if (ArraySearchInt(StoredOrderTicket, g_StoredOrderTicket[i])<0)
        {
            int closeOrder = GetOrderByMagic(g_StoredOrderTicket[i]);
            if (closeOrder > 0)
            {
                if (OrderSelect(closeOrder, SELECT_BY_TICKET, MODE_TRADES))
 
                {
 
                    if ((OrderType() == OP_BUY) ||
                            (OrderType() == OP_BUYLIMIT) ||
                            (OrderType() == OP_BUYSTOP))
                    {
                        if (OrderType() == OP_BUY)
                           BetterCloseBuy (OrderTicket(), OrderLots(), OrderSymbol());
                        else
                           OrderDelete(OrderTicket());
                    }
                    else
                    {
                        if (OrderType() == OP_SELL)
                           BetterCloseSell (OrderTicket(), OrderLots(), OrderSymbol());
                        else
                           OrderDelete(OrderTicket());
                    }
                 
                }
            }
            else
            {
 
                Print("Can't find an order with a number of ", g_StoredOrderTicket[i]);
 
            }
            //
 
 
 
        }
    }
 
    k = ArraySize(StoredOrderTicket);
    // Copy saved array for next loop
    ArrayResize(g_StoredOrderTicket, k);
    ArrayResize(g_StoredOrderType, k);
    ArrayResize(g_StoredOrderOpenPrice, k);
    ArrayResize(g_StoredOrderStopLoss, k);
    ArrayResize(g_StoredOrdeTakeProfit, k);
    ArrayResize(g_StoredOrderSymbol, k);
    ArrayResize(g_StoredOrderLots, k);
 
    if (k > 0)
    {
        ArrayCopy(g_StoredOrderTicket, StoredOrderTicket);
        ArrayCopy(g_StoredOrderType, StoredOrderType);
        ArrayCopy(g_StoredOrderOpenPrice, StoredOrderOpenPrice);
        ArrayCopy(g_StoredOrderStopLoss, StoredOrderStopLoss);
        ArrayCopy(g_StoredOrdeTakeProfit, StoredOrdeTakeProfit);
        ArrayCopy(g_StoredOrderLots, StoredOrderLots);
    }
 
}
 
int ArraySearchInt(int& m[], int e)
{
 
 
    if (ArraySize(m) == 0)
        return (-1);
    
    int iSizeM = ArraySize(m);
    for (int i=0; i<iSizeM; i++)
    {
        if (m[i]==e) return(i);
    }
 
    return(-1);
 
}
 
 
//+----------------------------------------------------------------------------+
//|  Clearing up the memory for orders                                         |
//+----------------------------------------------------------------------------+
void ResetOrderArray()
{
 
    RetrieveOrders( g_StoredOrderTicket, g_StoredOrderType, g_StoredOrderOpenPrice,
                    g_StoredOrderLots, g_StoredOrderStopLoss, g_StoredOrdeTakeProfit);
 
}
 
 
 
 
int databaseOrderCount()
{
    int    ordercount[1] = {0};
    bool goodCallGetOrderCount = false;
    while (goodCallGetOrderCount == 0)
    {
        goodCallGetOrderCount =  GetOrderCount(ordercount, StringSubstr(Symbol(), 0, 6));
 
    }
 
    return (ordercount[0]);
}
 
 
 
double MathRandRange(double x, double y)
{
    //MathSrand(TimeLocal());
    return(x+MathMod(MathRand(),MathAbs(x-y)));
}
 
void CloseStrayLocalOrders ()
{
 
    //First - populate magic number array
    int k = OrdersTotal();
    double closeprice;
    int LocalOrderTickets[];
 
 
    ArrayResize(LocalOrderTickets, k);
 
    for (int i=0; i<k; i++)
    {
        if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
        if (ArraySearchInt(g_StoredOrderTicket, OrderMagicNumber())<0)
        {
            if ((OrderType() == OP_BUY) ||
                    (OrderType() == OP_BUYLIMIT) ||
                    (OrderType() == OP_BUYSTOP))
            {
                closeprice = NormalizeDouble(MarketInfo(Symbol(),MODE_BID),MarketInfo(Symbol(),MODE_DIGITS));
            }
            else
            {
                closeprice = NormalizeDouble(MarketInfo(Symbol(),MODE_ASK),MarketInfo(Symbol(),MODE_DIGITS));
            }
            if ((OrderType() == OP_BUY) || (OrderType() == OP_SELL))
            {
                OrderClose(OrderTicket(), OrderLots(), closeprice,
                           Slippage, Red );
 
            }
            else
            {
                OrderDelete(OrderTicket());
 
            }
        }
    }
 
 
 
}
void RetrieveOrders( int& aStoredOrderTicket[], int& aStoredOrderType[], double& aStoredOrderOpenPrice[],
                     double& aStoredOrderLots[], double& aStoredOrderStopLoss[], double& aStoredOrdeTakeProfit[])
{
    bool sameCount = false;
 
    while (sameCount == false)
    {
        int i, k=databaseOrderCount();
 
        if (k > 0)
        {
            bool goodResponse = false;
            int returnedOrderCount[1] = {0};
            ArrayResize(aStoredOrderTicket, k);
            ArrayResize(aStoredOrderType, k);
            ArrayResize(aStoredOrderOpenPrice, k);
            ArrayResize(aStoredOrderStopLoss, k);
            ArrayResize(aStoredOrdeTakeProfit, k);
            ArrayResize(aStoredOrderLots, k);
 
            ArrayInitialize(aStoredOrderOpenPrice, MathRandRange(1, 255));
            ArrayInitialize(aStoredOrderType, MathRandRange(1, 255));
            ArrayInitialize(aStoredOrderTicket, MathRandRange(1, 255));
            ArrayInitialize(aStoredOrderStopLoss, MathRandRange(1, 255));
            ArrayInitialize(aStoredOrdeTakeProfit, MathRandRange(1, 255));
            ArrayInitialize(aStoredOrderLots, MathRandRange(1, 255));
 
            while(goodResponse == false)
            {
                goodResponse = GetOrdersDetails(k, StringSubstr(Symbol(), 0, 6), aStoredOrderTicket,  aStoredOrderType,
                                                aStoredOrderOpenPrice, aStoredOrderStopLoss,
                                                aStoredOrdeTakeProfit, aStoredOrderLots,
                                                returnedOrderCount);
            }
 
 
 
 
 
            if (returnedOrderCount[0] == ArraySize(aStoredOrdeTakeProfit))
                sameCount = true;
        }
        else
        {
            sameCount = true;
            ArrayResize(aStoredOrderTicket, 0);
            ArrayResize(aStoredOrderType, 0);
            ArrayResize(aStoredOrderOpenPrice, 0);
            ArrayResize(aStoredOrderStopLoss, 0);
            ArrayResize(aStoredOrdeTakeProfit, 0);
            ArrayResize(aStoredOrderLots, 0);
        }
    }
 
 
}
 
 
int PipsDeviated(double price1, double price2)
{
 
    int pipsSpread = MathAbs(price1 - price2) / MarketInfo(Symbol(), MODE_DIGITS);
    return (pipsSpread);
}
 
int GetOrderByMagic(int magic)
{
    int cnt = 0, checkSum=0;
 
    bool okayProcess = false;
    bool badSelect = false;
 
    while (okayProcess == false)
    {
        cnt = OrdersTotal();
 
        for (int i=0; i<cnt; i++)
        {
            if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
            {
                checkSum++;
                if (OrderMagicNumber() == magic) return (OrderTicket());
            }
            else
            {
                badSelect = true;
            }
 
        }
 
        if (cnt == OrdersTotal() && checkSum == cnt && badSelect == false)
            okayProcess = true;
        else
            Sleep(1000);
    }
 
    return (-1);
}
 

 
int BetterOrderSend2Step(string symbol, int cmd, double volume, double price,
                         int slippage, double stoploss, double takeprofit,
                         string comment, int magic, datetime expiration = 0,
                         color arrow_color = CLR_NONE)
{
 
 
    // ------------------------------------------------
    // Check basic conditions see if trade is possible.
    // ------------------------------------------------
    if (!IsConnected())
    {
        return(-1);
    }
 
    if (IsStopped())
    {
        return(-1);
    }
 
    int cnt = 0;
 
    while (!IsTradeAllowed() && cnt < 10)
    {
        SleepRandomTime(4.0, 25.0);
        cnt++;
    }
 
    if (!IsTradeAllowed())
    {
        return(-1);
    }
 
    // Normalize all price / stoploss / takeprofit to the proper # of digits.
    int digits = MarketInfo(symbol, MODE_DIGITS);
 
    //First - ensure price is right
 
    if (cmd == OP_BUY)
    {
        RefreshRates();
        price = MarketInfo(symbol,MODE_ASK);
    }
 
    if (cmd == OP_SELL)
    {
        RefreshRates();
        price = MarketInfo(symbol,MODE_BID);
    }
 
    if (digits > 0)
    {
        price = NormalizeDouble(price, digits);
        stoploss = NormalizeDouble(stoploss, digits);
        takeprofit = NormalizeDouble(takeprofit, digits);
    }
 
 
    int err = GetLastError(); // clear the global variable.
    err = 0;
 
    bool exit_loop = false;
 
    // limit/stop order.
    int ticket = -1;
 
    if ((cmd == OP_BUYSTOP) || (cmd == OP_SELLSTOP) || (cmd == OP_BUYLIMIT) || (cmd == OP_SELLLIMIT))
    {
        cnt = 0;
        while (!exit_loop)
        {
            if (IsTradeAllowed())
            {
                ticket = OrderSend(symbol, cmd, volume, price, slippage, 0.0,
                                   0.0, comment, magic, expiration, arrow_color);
                err = GetLastError();
            }
            else
            {
                cnt++;
            }
 
            switch (err)
            {
            case ERR_NO_ERROR:
                exit_loop = true;
                break;
 
                // retryable errors
            case ERR_SERVER_BUSY:
            case ERR_NO_CONNECTION:
            case ERR_INVALID_PRICE:
            case ERR_OFF_QUOTES:
            case ERR_BROKER_BUSY:
            case ERR_TRADE_CONTEXT_BUSY:
                cnt++;
                break;
 
            case ERR_PRICE_CHANGED:
            case ERR_REQUOTE:
                RefreshRates();
                continue;	// we can apparently retry immediately according to MT docs.
 
            case ERR_INVALID_STOPS:
                double servers_min_stop = MarketInfo(symbol, MODE_STOPLEVEL) * MarketInfo(symbol, MODE_POINT);
                if (cmd == OP_BUYSTOP || cmd == OP_BUYLIMIT)
                {
                    if (MathAbs(Ask - price) <= servers_min_stop)
                    {
 
                        if (price < Ask)
                            price = Ask - servers_min_stop;
                        else if (price > Ask)
                            price = Ask + servers_min_stop;
                        else
                            Print("Non-retryable error - Price is Set same as Ask, cannot continue.");
 
                    }
 
                }
                else if (cmd == OP_SELLSTOP || cmd == OP_SELLLIMIT)
                {
                    // If we are too close to put in a limit/stop order so go to market.
                    if (MathAbs(Bid - price) <= servers_min_stop)
                    {
 
                        if (price < Bid)
                            price = Bid - servers_min_stop;
                        else if (price > Bid)
                            price = Bid + servers_min_stop;
                        else
                            Print("Non-retryable error - Price is Set same as Bid, cannot continue.");
 
                    }
                }
                break;
 
            default:
                // an apparently serious error.
                exit_loop = true;
                break;
 
            }  // end switch
 
            if (cnt > 10)
                exit_loop = true;
 
            if (exit_loop)
            {
                if (err != ERR_NO_ERROR)
                {
                    Print("Non-retryable error: " + ErrorDescription(err));
                }
                if (cnt > 10)
                {
                    Print("Retry attempts maxed at " + 10);
                }
            }
 
            if (!exit_loop)
            {
                Print("Retryable error (" + cnt + "/" + 10 +
                      "): " + ErrorDescription(err));
                SleepRandomTime(30, 45);
                RefreshRates();
            }
        }
 
        // We have now exited from loop.
        if (err == ERR_NO_ERROR)
        {
            Print("Apparently successful " + OrderType2String(cmd) + " order placed, details follow.");
            OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES);
            OrderPrint();
        }
 
    }  // end
 
    // we now have a market order.
    err = GetLastError(); // so we clear the global variable.
    err = 0;
    ticket = -1;
    exit_loop = false;
 
    if ((cmd == OP_BUY) || (cmd == OP_SELL))
    {
        cnt = 0;
        while (!exit_loop)
        {
            if (IsTradeAllowed())
            {
                ticket = OrderSend(symbol, cmd, volume, price, slippage,
                                   0.0, 0.0, comment, magic,
                                   expiration, arrow_color);
                err = GetLastError();
            }
            else
            {
                cnt++;
            }
            switch (err)
            {
            case ERR_NO_ERROR:
                exit_loop = true;
                break;
 
            case ERR_SERVER_BUSY:
            case ERR_NO_CONNECTION:
            case ERR_OFF_QUOTES:
            case ERR_BROKER_BUSY:
            case ERR_TRADE_CONTEXT_BUSY:
                cnt++; // a retryable error
                break;
 
            case ERR_PRICE_CHANGED:
            case ERR_REQUOTE:
                RefreshRates();
                cnt++;
                break; // we can apparently retry immediately according to MT docs.
 
            case ERR_INVALID_PRICE:
                if (cmd == OP_BUY)
                {
                    RefreshRates();
                    price = MarketInfo(symbol,MODE_ASK);
                }
 
                if (cmd == OP_SELL)
                {
                    RefreshRates();
                    price = MarketInfo(symbol,MODE_BID);
                }
                cnt++; // a retryable error
                break;
 
            default:
                // an apparently serious, unretryable error.
                exit_loop = true;
                break;
 
            }  // end switch
 
            if (cnt > 10)
                exit_loop = true;
 
            if (!exit_loop)
            {
                Print("Retryable error (" + cnt + "/" +
                      10 + "): " + ErrorDescription(err));
                SleepRandomTime(20.5, 40);
                RefreshRates();
            }
 
            if (exit_loop)
            {
                if (err != ERR_NO_ERROR)
                {
                    Print("non-retryable error: " + ErrorDescription(err));
                }
                if (cnt > 10)
                {
                    Print("retry attempts maxed at " + 10);
                }
            }
        }
 
        // we have now exited from loop.
        if (err == ERR_NO_ERROR)
        {
            Print("Ticket #" + ticket + ": Apparently successful " + OrderType2String(cmd) + " order placed, details follow.");
            OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES);
            OrderPrint();
        }
        else
        {
            Print("failed to execute OP_BUY/OP_SELL, after " + cnt + " retries");
            Print("failed trade: " + OrderType2String(cmd) + " " + symbol +
                  "@" + price + " tp@" + takeprofit + " sl@" + stoploss);
            Print("last error: " + ErrorDescription(err));
            return(-1);
        }
    }
 
 
    if (ticket > 0 && (stoploss != 0 || takeprofit != 0))
    {
        OrderSelect(ticket, SELECT_BY_TICKET);
        bool b_modify = BetterOrderModifySymbol(symbol, cmd, ticket, OrderOpenPrice(),
                                                stoploss, takeprofit, 0, arrow_color);
    }
 
    return (ticket);
}
 
 
 
string OrderType2String(int type)
{
    if (type == OP_BUY) 		return("BUY");
    if (type == OP_SELL) 		return("SELL");
    if (type == OP_BUYSTOP) 	return("BUY STOP");
    if (type == OP_SELLSTOP)	return("SELL STOP");
    if (type == OP_BUYLIMIT) 	return("BUY LIMIT");
    if (type == OP_SELLLIMIT)	return("SELL LIMIT");
}
 
 
bool BetterOrderModify(string symbol, int cmd, int ticket, double price, double stoploss,
                       double takeprofit, datetime expiration,
                       color arrow_color = CLR_NONE)
{
 

    if (!IsConnected())
    {
        return(false);
    }
 
    if (IsStopped())
    {
        return(false);
    }
 
    int cnt = 0;
    while (!IsTradeAllowed() && cnt < 5)
    {
        SleepRandomTime(4.0, 25.0);
        cnt++;
    }
    if (!IsTradeAllowed())
    {
        return(false);
    }
 
    int err = GetLastError();
    err = 0;
    bool exit_loop = false;
    cnt = 0;
    bool result = false;
 
    int digits = MarketInfo(symbol, MODE_DIGITS);
 
    //First - ensure price is right
 
    if (cmd == OP_BUY)
    {
        RefreshRates();
        price = MarketInfo(symbol,MODE_ASK);
    }
 
    if (cmd == OP_SELL)
    {
        RefreshRates();
        price = MarketInfo(symbol,MODE_BID);
    }
 
    if (digits > 0)
    {
        price = NormalizeDouble(price, digits);
        stoploss = NormalizeDouble(stoploss, digits);
        takeprofit = NormalizeDouble(takeprofit, digits);
    }
    if (stoploss != 0)
        EnsureValidSL(symbol, price, stoploss);
    if (takeprofit != 0)
        EnsureValidTP(symbol, price, takeprofit);
 
    while (!exit_loop)
    {
        if (IsTradeAllowed())
        {
            result = OrderModify(ticket, price, stoploss,
                                 takeprofit, expiration, arrow_color);
            err = GetLastError();
        }
        else
            cnt++;
 
        if (result == true)
            exit_loop = true;
 
        switch (err)
        {
        case ERR_NO_ERROR:
            exit_loop = true;
            break;
 
        case ERR_NO_RESULT:
            exit_loop = true;
            break;
 
        case ERR_SERVER_BUSY:
        case ERR_NO_CONNECTION:
        case ERR_INVALID_PRICE:
        case ERR_OFF_QUOTES:
        case ERR_BROKER_BUSY:
        case ERR_TRADE_CONTEXT_BUSY:
        case ERR_TRADE_TIMEOUT:
            cnt++;
            break;
 
        case ERR_INVALID_STOPS:
            cnt++;
            RefreshRates();
            if (cmd == OP_BUY)
            {
                price = MarketInfo(symbol,MODE_ASK);
            }
 
            if (cmd == OP_SELL)
            {
                price = MarketInfo(symbol,MODE_BID);
            }
            if (stoploss != 0)
                EnsureValidSL(symbol, price, stoploss);
            if (takeprofit != 0)
                EnsureValidTP(symbol, price, takeprofit);
            break;
 
        case ERR_PRICE_CHANGED:
        case ERR_REQUOTE:
            RefreshRates();
            break;
 
        default:
            exit_loop = true;
            break;
 
        }
 
        if (cnt > 5)
            exit_loop = true;
 
        if (!exit_loop)
        {
            SleepRandomTime(4.0, 25.0);
            RefreshRates();
        }
 
    }
 
    // we have now exited from loop.
    if ((result == true) || (err == ERR_NO_ERROR))
    {
        OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES);
        return(true); // SUCCESS!
    }
 
    if (err == ERR_NO_RESULT)
    {
        return(true);
    }
 
 
 
    return(false);
}
 
 
bool BetterOrderModifySymbol(string symbol, int cmd, int ticket, double price,
                             double stoploss, double takeprofit,
                             datetime expiration, color arrow_color = CLR_NONE)
{
    int digits = MarketInfo(symbol, MODE_DIGITS);

    //First - ensure price is right
 
    if (cmd == OP_BUY)
    {
        RefreshRates();
        price = MarketInfo(symbol,MODE_ASK);
    }
 
    if (cmd == OP_SELL)
    {
        RefreshRates();
        price = MarketInfo(symbol,MODE_BID);
    }
 
    if (digits > 0)
    {
        price = NormalizeDouble(price, digits);
        stoploss = NormalizeDouble(stoploss, digits);
        takeprofit = NormalizeDouble(takeprofit, digits);
    }
 
    if (stoploss != 0)
        EnsureValidSL(symbol, price, stoploss);
    if (takeprofit != 0)
        EnsureValidTP(symbol, price, takeprofit);
   

    
    return(BetterOrderModify(symbol, cmd, ticket, price, stoploss,
                             takeprofit, expiration, arrow_color));

}
 
void EnsureValidSL(string symbol, double price, double& sl)
{
 
    if (sl == 0)
        return;
 
    double servers_min_stop = (MarketInfo(symbol, MODE_STOPLEVEL)*dXPoint) * MarketInfo(symbol, MODE_POINT);
 
    if (MathAbs(price - sl) <= servers_min_stop)
    {
 
        if (price > sl)
            sl = price - servers_min_stop;
 
        else if (price < sl)
            sl = price + servers_min_stop;
 
 
 
        sl = NormalizeDouble(sl, MarketInfo(symbol, MODE_DIGITS));
    }
}
 
 
 
void EnsureValidTP(string symbol, double price, double& tp)
{
 
    if (tp == 0)
        return;
 
    double servers_min_stop = (MarketInfo(symbol, MODE_STOPLEVEL)*dXPoint) * MarketInfo(symbol, MODE_POINT);
   
    if (MathAbs(price - tp) <= servers_min_stop)
    {
        if (price < tp)
            tp = price + servers_min_stop;
 
        else if (price > tp)
            tp = price - servers_min_stop;
 
        tp = NormalizeDouble(tp, MarketInfo(symbol, MODE_DIGITS));
    }
}
 
void SleepRandomTime(double mean_time, double max_time)
{
    if (IsTesting())
        return;
 
    double tenths = MathCeil(mean_time / 0.1);
    if (tenths <= 0)
        return;
 
    int maxtenths = MathRound(max_time / 0.1);
    double p = 1.0 - 1.0 / tenths;
 
    Sleep(100);
 
    for (int i = 0; i < maxtenths; i++)
    {
        if (MathRand() > p*32768)
            break;
 
        Sleep(100);
    }
}
 
bool BetterCloseBuy (int ticket, double lots, string symbol)
{
 
    int loopcount=0;
    int gle;
    bool ret;
    double bid;
 
    while(loopcount<10)
    {
        bid=MarketInfo(symbol,MODE_BID);
 
        ret=OrderClose(ticket,lots,bid,Slippage,White);
        gle=GetLastError();
 
        if(gle==0)
        {
            loopcount=11;
        }
        else
        {
            RefreshRates();
            Sleep(500);
        }
 
 
        loopcount++;
 
    }//while
 
    return(ret);
 
}
 
bool BetterCloseSell (int ticket, double lots, string symbol)
{
 
    int loopcount=0;
    int gle;
    double bid;
    bool ret;
 
    while(loopcount<10)
    {
        bid=MarketInfo(symbol,MODE_ASK);
 
        ret=OrderClose(ticket,lots,bid,Slippage,White);
        gle=GetLastError();
 
        if(gle==0)
        {
            loopcount=11;
            break;
 
        }
        else
        {
            RefreshRates();
            Sleep(500);
        }
 
 
        loopcount++;
 
 
    }//while
 
    return(ret);
}

 
 
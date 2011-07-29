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
#property copyright "Copyright © 2010 OpenThinking Software, LLC"
#property link      "http://www.openthinkingsoftware.com"

#import "MT4TradeDuplicator.dll"


int GetOrdersDetails(int orderCount, string chartSymbol, int acctNumber, int& orderTicket[],  int& op[],
                      double& orderOpenPrice[], double& orderStoploss[],
                      double& orderTakeProfit[], double& orderLots[], string& orderSymbol[],
                      string& orderComment[], int returnedOrders[]);
int GetOrdersDetailsNoSymbol(int orderCount, int acctNumber, int& orderTicket[],  int& op[],
                      double& orderOpenPrice[], double& orderStoploss[],
                      double& orderTakeProfit[], double& orderLots[], string& orderSymbol[],
                      string& orderComment[], int returnedOrders[]);
   
bool ClearOrderTable();
bool GetOrderCount(int& orderCount[], string orderSymbol, int acctNumber);
bool GetOrderCountNoSymbol(int& orderCount[], int acctNumber);
bool FinalizeOrderTable();
int ConvertChar(string val);
#import

#include <stdlib.mqh>
#include <stderror.mqh>

extern double SecondsBetweenPolling = 1;
extern int PipsAwayLimit = 20;
extern double LotMultiplier = 1;
extern int PipsDeviation = 20;
extern bool CleanStrays = true;
extern bool LockToChartSymbol = false;
extern int AccountFilter = 0;
extern bool ReverseTrades = false;
int    g_StoredOrderTicket[];             //    OrderTicket()
string g_StoredOrderSymbol[];             //    OrderSymbol()
string g_StoredOrderComment[];             //    OrderSymbol()
int    g_StoredOrderType[];             //      OrderType()
double g_StoredOrderOpenPrice[];             //     OrderOpenPrice()
double g_StoredOrderLots[];             //     OrderLots()
double g_StoredOrderStopLoss[];             //     OrderStopLoss()
double g_StoredOrdeTakeProfit[];             //     OrderTakeProfit()
datetime g_StoredOrderOpenTime[];

int OriginalOrderTicketsKeys[];
int OriginalOrderTicketsValues[];
int OriginalOrderTicketsSize = 0;

int    g_LocalOrderTicket[];             //    OrderTicket()
string g_LocalOrderSymbol[];             //    OrderSymbol()
string g_LocalOrderComments[];             //    OrderSymbol()
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
    LoadOriginalOrderTickets();
        
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
    Print ("In start()");

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
    string StoredOrderComment[];
	 datetime StoredOrderOpenTime[];
    int k;
    double closeprice;
    double newlots;
    int newCmd;
    double newPrice;
    bool okayToProcess = true;

    //First populate new array
    RetrieveOrders( StoredOrderTicket, StoredOrderType, StoredOrderOpenPrice,
                    StoredOrderLots, StoredOrderStopLoss, StoredOrdeTakeProfit, StoredOrderComment, StoredOrderSymbol);

    k=ArraySize(g_StoredOrderTicket);
    double p;
    
    //Let's first search thru for any closes
    
    for (i=0; i<k; i++)
    {
        if (ArraySearchInt(StoredOrderTicket, g_StoredOrderTicket[i])<0)
        {
            ot=g_StoredOrderType[i];
            
            //Send closed / delete

            //Send close if market else send delete
            if ((ot == OP_BUY) || (ot == OP_SELL))
            {
                  int tradeidx = ArraySearchTimeDoubleString(StoredOrderOpenTime, StoredOrderOpenPrice, StoredOrderSymbol,
                                                             g_StoredOrderOpenTime[i], g_StoredOrderOpenPrice[i], g_StoredOrderSymbol[i]);

                  Print("tradeidx: ", tradeidx, " curlots: ", StoredOrderLots[tradeidx], " origorderlots: ", g_StoredOrderLots[i]);
                
                  if ((tradeidx != -1 && StoredOrderLots[tradeidx] <= g_StoredOrderLots[i]) || // partially closed, still open
                      (GetOriginalOrderTicket(g_StoredOrderTicket[i]) != -1)) {  // final partial close, no remaining open trades
                    double closed_lots;
                    int orig_order_ticket;
                    
                    if (tradeidx != -1)  // still open, take difference of lots sizes
                      closed_lots = g_StoredOrderLots[i] - StoredOrderLots[tradeidx];
                    else
                      closed_lots = g_StoredOrderLots[i];

                    if (GetOriginalOrderTicket(g_StoredOrderTicket[i]) < 0)  // haven't stored orig yet, meaning this is the orig trade
                      orig_order_ticket = g_StoredOrderTicket[i];
                    else { // already stored original, meaning this wasn't the original trade
                      orig_order_ticket = GetOriginalOrderTicket(g_StoredOrderTicket[i]);
                      DeleteOriginalOrderTicket(g_StoredOrderTicket[i]);  // old trade is gone, no longer need to link it
                    }

                    // link the new trade with the order id of the original trade, unless this is the final partial close
                    if (tradeidx != -1)
                      SetOriginalOrderTicket(StoredOrderTicket[tradeidx], orig_order_ticket);

                    SendCloseOrder(orig_order_ticket, closed_lots, g_StoredOrderLots[i], g_StoredOrderSymbol[i]);
                  } else { // full close
                    SendCloseOrder(g_StoredOrderTicket[i], g_StoredOrderLots[i], g_StoredOrderLots[i], g_StoredOrderSymbol[i]);
                  }
            }                
            else
                SendDeleteOrder(g_StoredOrderTicket[i], g_StoredOrderSymbol[i]);
               

        }
    }




    k=ArraySize(StoredOrderTicket);
   
    for (i=0; i<k; i++)
    {

        p=MarketInfo(StoredOrderSymbol[i], MODE_POINT);
        // Search for OrderTicket in old array
        in=ArraySearchInt(g_StoredOrderTicket, StoredOrderTicket[i]);

        // If not found trigger signal.
        if (in<0)
        {

            double pnow = 0.0;
            newlots = StoredOrderLots[i] * LotMultiplier;
 
            if (newlots < MarketInfo(StoredOrderSymbol[i],MODE_MINLOT))
            {
                newlots = MarketInfo(StoredOrderSymbol[i],MODE_MINLOT);
            }
            if (newlots > MarketInfo(StoredOrderSymbol[i],MODE_MAXLOT))
            {
                newlots = MarketInfo(StoredOrderSymbol[i],MODE_MAXLOT);
            }
 
 
            if (StoredOrderType[i] == OP_BUY)
            {
                pnow = NormalizeDouble(MarketInfo(StoredOrderSymbol[i], MODE_ASK), MarketInfo(StoredOrderSymbol[i], MODE_DIGITS)); // we are buying at Ask
            }
            else if (StoredOrderType[i] == OP_SELL)
            {
                pnow = NormalizeDouble(MarketInfo(StoredOrderSymbol[i], MODE_BID), MarketInfo(StoredOrderSymbol[i], MODE_DIGITS)); // we are buying at Ask
            }
            else
            {
                pnow = NormalizeDouble(StoredOrderOpenPrice[i], MarketInfo(StoredOrderSymbol[i], MODE_DIGITS));
            }
 
 
            newCmd = StoredOrderType[i];
            newPrice = StoredOrderOpenPrice[i];
 
 
            if ((PipsDeviated(pnow, StoredOrderOpenPrice[i]) <= PipsDeviation)  && okayToProcess == true)
            {
 

                if (newCmd == OP_BUY || newCmd == OP_SELL)
                    BetterOrderSend2Step(StoredOrderSymbol[i], newCmd, newlots, pnow,
                                   Slippage, StoredOrderStopLoss[i], StoredOrdeTakeProfit[i],
                                   StoredOrderComment[i], StoredOrderTicket[i], 0, Blue);
                else
                {
                    BetterOrderSend2Step(StoredOrderSymbol[i], newCmd, newlots, newPrice,
                                   Slippage, StoredOrderStopLoss[i], StoredOrdeTakeProfit[i],
                                   StoredOrderComment[i], StoredOrderTicket[i], 0, Blue);
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
                                BetterOrderModify(OrderSymbol(), OrderTicket(), OrderType(), OrderOpenPrice(), StoredOrderStopLoss[i],
                                            StoredOrdeTakeProfit[i], 0,Blue);
                            else
                                BetterOrderModify(OrderSymbol(), OrderTicket(), OrderType(), StoredOrderOpenPrice[i], StoredOrderStopLoss[i],
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
    ArrayResize(g_StoredOrderSymbol, k);
    ArrayResize(g_StoredOrderType, k);
    ArrayResize(g_StoredOrderOpenPrice, k);
    ArrayResize(g_StoredOrderStopLoss, k);
    ArrayResize(g_StoredOrdeTakeProfit, k);
    ArrayResize(g_StoredOrderLots, k);
    ArrayResize(g_StoredOrderOpenTime, k);

    if (k > 0)
    {
        ArrayCopy(g_StoredOrderTicket, StoredOrderTicket);
        ArrayCopy(g_StoredOrderSymbol, StoredOrderSymbol);
        ArrayCopy(g_StoredOrderType, StoredOrderType);
        ArrayCopy(g_StoredOrderOpenPrice, StoredOrderOpenPrice);
        ArrayCopy(g_StoredOrderStopLoss, StoredOrderStopLoss);
        ArrayCopy(g_StoredOrdeTakeProfit, StoredOrdeTakeProfit);
        ArrayCopy(g_StoredOrderLots, StoredOrderLots);
        ArrayCopy(g_StoredOrderOpenTime, StoredOrderOpenTime);   

    }
   
    DumpOriginalOrderTickets();
}
 
 
//+----------------------------------------------------------------------------+
//|  Clearing up the memory for orders                                         |
//+----------------------------------------------------------------------------+
void ResetOrderArray()
{
 
    RetrieveOrders( g_StoredOrderTicket, g_StoredOrderType, g_StoredOrderOpenPrice,
                    g_StoredOrderLots, g_StoredOrderStopLoss, g_StoredOrdeTakeProfit, g_StoredOrderComment, g_StoredOrderSymbol);
 
}
 
 
void SendCloseOrder(int orderTicket, double orderLots, double origLots, string orderSymbol)
{
            int closeOrder = GetOrderByMagic(orderTicket);
            if (closeOrder > 0)
            {
                if (OrderSelect(closeOrder, SELECT_BY_TICKET, MODE_TRADES))
 
                {
                    
                    double lotMultiplier = orderLots / origLots;
                    double orderTotalLots = OrderLots()+GetTTLots(OrderOpenTime(),StringSubstr(OrderComment(),5,5));
                    double closeVolume = orderTotalLots * lotMultiplier;
                     
                    if ((OrderType() == OP_BUY) ||
                            (OrderType() == OP_BUYLIMIT) ||
                            (OrderType() == OP_BUYSTOP))
                    {
                        if (OrderType() == OP_BUY)
                           BetterCloseBuy (OrderTicket(), closeVolume, OrderSymbol());
                        else
                           OrderDelete(OrderTicket());
                    }
                    else
                    {
                        if (OrderType() == OP_SELL)
                           BetterCloseSell (OrderTicket(), closeVolume, OrderSymbol());
                        else
                           OrderDelete(OrderTicket());
                    }
                 
                }
            }
            else
            {
 
                Print("Can't find an order with a number of ", orderTicket);
 
            }

}

void SendDeleteOrder(int orderTicket, string orderSymbol)
{
            int closeOrder = GetOrderByMagic(orderTicket);
            if (closeOrder > 0)
            {
                if (OrderSelect(closeOrder, SELECT_BY_TICKET, MODE_TRADES))
 
                {
                    
                   
                    OrderDelete(OrderTicket());
                   
                 
                }
            }
            else
            {
 
                Print("Can't find an order with a number of ", orderTicket);
 
            }

}
int databaseOrderCount()
{
    int    ordercount[1] = {0};
    bool goodCallGetOrderCount = false;
    while (goodCallGetOrderCount == 0)
    {
        if (LockToChartSymbol == true)
         goodCallGetOrderCount =  GetOrderCount(ordercount, StringSubstr(Symbol(), 0, 6), 0);
        else
         goodCallGetOrderCount =  GetOrderCountNoSymbol(ordercount, 0);
 
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
    /*int k = OrdersTotal();
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
            
            if ((LockToChartSymbol == true && OrderSymbol() == Symbol()) ||
                (LockToChartSymbol == false))
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
 
  */
 
}
void RetrieveOrders( int& aStoredOrderTicket[], int& aStoredOrderType[], double& aStoredOrderOpenPrice[],
                     double& aStoredOrderLots[], double& aStoredOrderStopLoss[], double& aStoredOrdeTakeProfit[],
                     string& aStoredOrderComment[], string& aStoredOrderSymbol[])
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
            ArrayResize(aStoredOrderComment, k);
            ArrayResize(aStoredOrderSymbol, k);
            
            ArrayInitialize(aStoredOrderOpenPrice, MathRandRange(1, 255));
            ArrayInitialize(aStoredOrderType, MathRandRange(1, 255));
            ArrayInitialize(aStoredOrderTicket, MathRandRange(1, 255));
            ArrayInitialize(aStoredOrderStopLoss, MathRandRange(1, 255));
            ArrayInitialize(aStoredOrdeTakeProfit, MathRandRange(1, 255));
            ArrayInitialize(aStoredOrderLots, MathRandRange(1, 255));
            
            Print ("ConvertChar", ConvertChar("a"));
            Print ("StringGetChar", StringGetChar("a", 0));
            //Init comments
            
            for (int i2=0; i2<k; i2++)
            {
               aStoredOrderComment[i2] = "11111111111111111111111111111111111111111111111111111111" + i2;
            }
            
            
            
            for (i2=0; i2<k; i2++)
            {
               aStoredOrderSymbol[i2] = "111111122222321111111111111111111111111111111111111111111" + i2;
            }
            
            for (i2=0; i2<k; i2++)
            {
               Print("aStoredOrderComment[" + i2 + "]", aStoredOrderComment[i2]);
               Print("aStoredOrderSymbol[" + i2 + "]", aStoredOrderSymbol[i2]);
            }
            while(goodResponse == 0)
            {
                if (LockToChartSymbol == true)
                  goodResponse = GetOrdersDetails(k, StringSubstr(Symbol(), 0, 6), AccountFilter, aStoredOrderTicket,  aStoredOrderType,
                                                aStoredOrderOpenPrice, aStoredOrderStopLoss,
                                                aStoredOrdeTakeProfit, aStoredOrderLots, aStoredOrderSymbol, aStoredOrderComment,
                                                returnedOrderCount);
                else
                  goodResponse = GetOrdersDetailsNoSymbol(k, AccountFilter, aStoredOrderTicket,  aStoredOrderType,
                                                aStoredOrderOpenPrice, aStoredOrderStopLoss,
                                                aStoredOrdeTakeProfit, aStoredOrderLots, aStoredOrderSymbol, aStoredOrderComment,
                                                returnedOrderCount);
            }

            for (i2=0; i2<k; i2++)
            {
               Print("aStoredOrderComment[" + i2 + "]", aStoredOrderComment[i2]);
               Print("aStoredOrderSymbol[" + i2 + "]", aStoredOrderSymbol[i2]);
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

double GetTTLots(int time, string text){
   double tt=0;
   int tot2=OrdersHistoryTotal();
      for(  int k=tot2-1;k>=0;k--) 
      { 
         if(OrderSelect(k, SELECT_BY_POS, MODE_HISTORY))
         {
            if (StringSubstr(OrderComment(),3,5)==text)
             if (OrderOpenTime()>time-10 && OrderOpenTime()<time+10 && OrderCloseTime()!=0){
               tt +=OrderLots();
            }
         }
      }
   return(tt);
}

int GetOriginalOrderTicket(int key) {
  for (int i = 0; i < OriginalOrderTicketsSize; i++)
    if (OriginalOrderTicketsKeys[i] == key)
      return(OriginalOrderTicketsValues[i]);
  return(-1);
}

void SetOriginalOrderTicket(int key, int value) {
  for (int i = 0; i < OriginalOrderTicketsSize; i++) {
    if (OriginalOrderTicketsKeys[i] == -1) {
      OriginalOrderTicketsKeys[i] = key;
      OriginalOrderTicketsValues[i] = value;
      return;
    }
  }

  // no free space, make some
  OriginalOrderTicketsSize += 1;
  ArrayResize(OriginalOrderTicketsKeys, OriginalOrderTicketsSize);
  ArrayResize(OriginalOrderTicketsValues, OriginalOrderTicketsSize);
  OriginalOrderTicketsKeys[OriginalOrderTicketsSize-1] = key;
  OriginalOrderTicketsValues[OriginalOrderTicketsSize-1] = value;
}

int DeleteOriginalOrderTicket(int key) {
  for (int i = 0; i < OriginalOrderTicketsSize; i++)
    if (OriginalOrderTicketsKeys[i] == key)
      OriginalOrderTicketsKeys[i] = -1;
}

void DumpOriginalOrderTickets() {
   int f = FileOpen("original_order_tickets_" + AccountNumber() + ".csv", FILE_WRITE|FILE_CSV);
   if (f < 0) {
      Print("ERROR PERSISTING ORIGINAL ORDER TICKETS TO FILE!  PARTIAL CLOSES MAY NOT WORK CORRECTLY");
      return;
   }

   FileWrite(f, OriginalOrderTicketsSize);
   for (int i = 0; i < OriginalOrderTicketsSize; i++)
      FileWrite(f, OriginalOrderTicketsKeys[i], OriginalOrderTicketsValues[i]);

   FileClose(f);
}

void LoadOriginalOrderTickets() {
   int f = FileOpen("original_order_tickets_" + AccountNumber() + ".csv", FILE_READ|FILE_CSV);
   if (f < 0) {
      Print("ERROR LOADING ORIGINAL ORDER TICKETS FILE!  PARTIAL CLOSES MAY NOT WORK CORRECTLY");
      Print("DISREGARD THIS ERROR IF THIS IS THE FIRST TIME RUNNING THIS EXPERT ADVISOR");
      return;
   }
   
   OriginalOrderTicketsSize = StrToInteger(FileReadString(f));
   ArrayResize(OriginalOrderTicketsKeys, OriginalOrderTicketsSize);
   ArrayResize(OriginalOrderTicketsValues, OriginalOrderTicketsSize);
   for (int i = 0; i < OriginalOrderTicketsSize; i++) {
      OriginalOrderTicketsKeys[i] = StrToInteger(FileReadString(f));
      OriginalOrderTicketsValues[i] = StrToInteger(FileReadString(f));
   }
   
   FileClose(f);
}

int ArraySearchDouble(double a[], double e) { for (int i = 0; i < ArraySize(a); i++)  if (a[i] == e) return(i); return(-1); }
int ArraySearchTime(datetime a[], datetime e) { for (int i = 0; i < ArraySize(a); i++)  if (a[i] == e) return(i); return(-1); }
int ArraySearchString(string a[], string e) { for (int i = 0; i < ArraySize(a); i++)  if (a[i] == e) return(i); return(-1); }
int ArraySearchInt(int a[], int e) { for (int i = 0; i < ArraySize(a); i++)  if (a[i] == e) return(i); return(-1); }

int ArraySearchTimeDoubleString(datetime ta[], double da[], string sa[], datetime t, double d, string s) {
  for (int i = 0; i < ArraySize(ta); i++)
    if (ta[i] == t && da[i] == d && sa[i] == s) return(i);

  return(-1);
}
 


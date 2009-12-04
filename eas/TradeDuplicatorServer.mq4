//+------------------------------------------------------------------+
//|                                                 TradeMonitor.mq4 |
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

#property copyright "Copyright © 2009, OpenThinking Software, LLC"
#property link      "http://www.openthinkingsoftware.com"

#import "TradeDuplicator.dll"

bool GetOrderDetails(int orderCount, int& orderTicket[], string orderSymbol, int& op[],
                     double& orderOpenPrice[], double& orderStoploss[],
                     double& orderTakeProfit[], double& orderLots[],
                     string orderOpenTime);
bool ClearOrderTable();
bool GetOrderCount(int& orderCount[]);
bool StoreNewOrder(int orderTicket, string orderSymbol, int op,
                   double orderOpenPrice, double orderStoploss,
                   double orderTakeProfit, double orderLots,
                   string orderOpenTime);
bool FinalizeOrderTable();
#import



int debugFlag = 0;


//+----------------------------------------------------------------------------+
//|  Custom indicator initialization function                                  |
//+----------------------------------------------------------------------------+
void init()
{
    if (!IsDllsAllowed())
    {
        Alert ("Please enable DLLs before using TradeDuplicatorServer. Go to Tools, Options, Expert Advisors and check Allow DLLs. Then press F7 and do the same on the Common tab. ");
    }
    PopulateOrders();
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
 while (LoopFlag == true)
 {
    processTrades();
    Sleep(500);
 }

}

void processTrades()
{
   PopulateOrders();
}

void PopulateOrders()
{
    
    ClearOrderTable();
    
    int i, k=OrdersTotal();

    for (i=0; i<k; i++)
    {
        if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
        {
            
            StoreNewOrder(OrderTicket(), StringSubstr(OrderSymbol(), 0, 6), OrderType(),
                   OrderOpenPrice(), OrderStopLoss(),
                   OrderTakeProfit(), OrderLots(),
                   TimeToStr(OrderOpenTime()));
        }
    }
    
    FinalizeOrderTable();
    
}



//+------------------------------------------------------------------+
//| Copyright 2009 OpenThinking Systems, LLC
//|
//|  Licensed under the Apache License, Version 2.0 (the "License");
//|  you may not use this file except in compliance with the License.
//|  You may obtain a copy of the License at
//|
//|               http://www.apache.org/licenses/LICENSE-2.0
//|
//|  Unless required by applicable law or agreed to in writing,
//|  software distributed under the License is distributed on an
//|  "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
//|  KIND, either express or implied. See the License for the
//|  specific language governing permissions and limitations under
//|  the License.
//+------------------------------------------------------------------+

#ifndef _DLL_H_
#define _DLL_H_

#define _UNICODE 1
#define UNICODE 1
#define WIN32_LEAN_AND_MEAN

#include <windows.h>

#include "sqlliteutils.h"
#include <string>
#include <time.h>

enum TradeOperation
{
    OP_BUY = 0,
    OP_SELL = 1,
    OP_BUYLIMIT = 2,
    OP_SELLLIMIT = 3,
    OP_BUYSTOP = 4,
    OP_SELLSTOP = 5
};

struct MqlStr
{
    int	len;
    char *string;
};



#if BUILDING_DLL
# define DLLIMPORT __declspec (dllexport)
#else /* Not BUILDING_DLL */
# define DLLIMPORT __declspec (dllimport)
#endif /* Not BUILDING_DLL */

#define MT4_EXPFUNC __declspec(dllexport)


#define export extern "C" __declspec( dllexport )


void __stdcall	        InitStorage(const char* path)
{
    try
    {
        std::string databasePath = "";
        databasePath = std::string(path);
        databasePath += "\\tradedup.db";
        sd::sqlite database(databasePath);
        database << "create table if not exists tempTrades (orderid int, ordersymbol text, ordertype int, orderopenprice double, orderstoploss double, ordertakeprofit double, orderlots double, orderopentime text )";
        database << "create table if not exists activeTrades (orderid int, ordersymbol text, ordertype int, orderopenprice double, orderstoploss double, ordertakeprofit double, orderlots double, orderopentime text )";

    }
    catch (sd::db_error& err)
    {
        // do something with error

        //FILELog::ReportingLevel() = FILELog::FromString("ERROR");
        //FILE_LOG(logDEBUG) << "Error on sqlitedb create table: " << err.what_;
    }

}

const char *tmpDir()
{
    char *dirname;
    dirname = std::getenv("TMP");
    if(NULL == dirname)
        dirname = std::getenv("TMPDIR");
    if(NULL == dirname)
        dirname = std::getenv("TEMP");
    if(NULL == dirname)
    {
        //assert(false); // no temp directory found
        strcpy(dirname,"C:\\");
    }


    return dirname;
}

#ifdef __cplusplus
extern "C"
{
#endif



    MT4_EXPFUNC BOOL __stdcall	  StoreNewOrder(const int orderTicket, const char *orderSymbol, TradeOperation op,
            const double orderOpenPrice, const double orderStoploss,
            const double orderTakeProfit, const double orderLots,
            const char *orderOpenTime)

    {


        BOOL retValue = 0;

        InitStorage(tmpDir());


        try
        {
            std::string databasePath = "";
            databasePath = tmpDir();
            databasePath += "\\tradedup.db";



            sd::sqlite database(databasePath);   // open the db with the table already created
            sd::sql insert_query(database);   // build an sql query
            insert_query << "insert into tempTrades (orderid , ordersymbol, ordertype, orderopenprice, orderstoploss, ordertakeprofit, orderlots, orderopentime) VALUES(?, ?, ?, ?, ?, ?, ?, ?)";

            //database << "begin transaction";// create a transaction for speed

            // insert data (sdsqlite will auto-detect data type and execute query)
            insert_query << orderTicket << orderSymbol << op << orderOpenPrice << orderStoploss
            << orderTakeProfit << orderLots << orderOpenTime;

            //insert_query.step();

            //database << "commit transaction";// complete transaction
            retValue = 1;

        }
        catch (sd::db_error& err)
        {
            // do something with error

        }



        return retValue;
    }


    MT4_EXPFUNC BOOL	__stdcall	GetOrderCount(int orderCount[], const char* orderSymbol)
    {
        BOOL retValue = 0;

        InitStorage(tmpDir());


        try
        {
            std::string databasePath = "";

            databasePath = tmpDir();
            databasePath += "\\tradedup.db";
            sd::sqlite database(databasePath);   // open the db with the table already created
            sd::sql selquery(database);
            std::string squery = "select count(*) from activeTrades where ordersymbol = '";
            squery += orderSymbol;
            squery += "'";

            selquery << squery;

            while (selquery.step())
            {
                selquery >>   orderCount[0];
                //MessageBox(GetActiveWindow(),L"D",L"Request",MB_OK);
            }
            //MessageBox(GetActiveWindow(),L"D",L"Request",MB_OK);
            retValue = 1;


        }
        catch (sd::db_error& err)
        {

        }

        return retValue;
    }



    MT4_EXPFUNC BOOL	__stdcall	GetOrdersDetails(const int orderCount, const char* orderSymbol, int orderTicket[], int op[],
            double orderOpenPrice[], double orderStoploss[],
            double orderTakeProfit[], double orderLots[], int returnedOrders[])
    {

        BOOL retValue = 0;


        InitStorage(tmpDir());

        std::string sOrderSymbol;
        std::string sOrderDatetime;
        int rwCnt = 0;

        try
        {
            std::string databasePath = "";
            databasePath = tmpDir();
            databasePath += "\\tradedup.db";


            sd::sqlite database(databasePath);   // open the db with the table already created
            sd::sql selquery(database);


            std::string squery = "select orderid , ordertype, orderopenprice, orderstoploss, ordertakeprofit, orderlots from activeTrades where ordersymbol = '";
            squery += orderSymbol;
            squery += "'";

            selquery << squery;

            // extract the matching rows

            while (selquery.step())
            {
                selquery >>  orderTicket[rwCnt] >> op[rwCnt] >> orderOpenPrice[rwCnt] >> orderStoploss[rwCnt] >> orderTakeProfit[rwCnt] >> orderLots[rwCnt];
                retValue = 1;
                rwCnt++;

            }


        }
        catch (sd::db_error& err)
        {
            // do something with error
            //std::string errText = err.what_;

            retValue = 0;
        }


        returnedOrders[0] = rwCnt;
        return retValue;
    }

    MT4_EXPFUNC BOOL	__stdcall		ClearOrderTable()
    {

        BOOL retValue = 0;
        InitStorage(tmpDir());
        try
        {

            std::string databasePath = "";

            databasePath = tmpDir();
            databasePath += "\\tradedup.db";
            sd::sqlite database(databasePath);   // open the db with the table already created

            sd::sql selquery(database);
            selquery << "delete from tempTrades";

            selquery.step();
            retValue = 1;

        }
        catch (sd::db_error& err)
        {

        }
        return retValue;
    }

    MT4_EXPFUNC BOOL __stdcall		FinalizeOrderTable()
    {
        BOOL retValue = 0;
        InitStorage(tmpDir());
        try
        {
            //char *path=NULL;
            std::string databasePath = "";
            //path=getcwd(path,size);
            databasePath = tmpDir();
            databasePath += "\\tradedup.db";
            sd::sqlite database(databasePath);   // open the db with the table already created
            sd::sql insert_query(database);   // build an sql query
            sd::sql selquery(database);
            database << "begin transaction";// create a transaction for speed

            selquery << "DROP TABLE IF EXISTS activeTrades";
            selquery.step();


            insert_query << "CREATE TABLE activeTrades AS SELECT * FROM tempTrades";

            insert_query.step();

            database << "commit transaction";// complete transaction

        }
        catch (sd::db_error& err)
        {

        }

        return retValue;

    }



    BOOL WINAPI DllMain(HINSTANCE hinstDLL, DWORD fdwReason, LPVOID lpvReserved)
    {

        switch (fdwReason)
        {
        case DLL_PROCESS_ATTACH:
            // attach to process
            // return FALSE to fail DLL load

            break;

        case DLL_PROCESS_DETACH:
            // detach from process
            break;

        case DLL_THREAD_ATTACH:
            // attach to thread
            break;

        case DLL_THREAD_DETACH:
            // detach from thread
            break;
        }
        return TRUE; // succesful
    }
#ifdef __cplusplus
}
#endif

#endif /* _DLL_H_ */

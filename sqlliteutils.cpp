
#include "log.h"
#include <tchar.h>
#include <string>
#include <cstdlib>
#include <windows.h>
#include "sqlliteutils.h"
#include "convert.h"

void __stdcall	        InitStorage(const char* path)
{
    try
    {
        std::string databasePath = "";
        databasePath = std::string(path);
        databasePath += "\\tradedup.db";
        sd::sqlite database(databasePath);
        database << "create table if not exists tempTrades (orderid int, ordersymbol text, ordertype int, orderopenprice double, orderstoploss double, ordertakeprofit double, orderlots double, orderopentime text )";

    }
    catch (sd::db_error& err)
    {
        // do something with error

        //FILELog::ReportingLevel() = FILELog::FromString("ERROR");
        //FILE_LOG(logDEBUG) << "Error on sqlitedb create table: " << err.what_;
    }


}

BOOL __stdcall    SQLStoreNewOrder(const char* path, const int orderTicket, const char *orderSymbol, int op,
                                const double orderOpenPrice, const double orderStoploss,
                                const double orderTakeProfit, const double orderLots,
                                const char *orderOpenTime)
{

    InitStorage(path);
    BOOL retValue = 0;


    try
    {
        std::string databasePath = "";
        databasePath = path;
        databasePath += "\\tradedup.db";



        sd::sqlite database(databasePath);   // open the db with the table already created
        sd::sql insert_query(database);   // build an sql query
        insert_query << "insert into tempTrades (orderid , ordersymbol, ordertype, orderopenprice, orderstoploss, ordertakeprofit, orderlots, orderopentime) VALUES(?, ?, ?, ?, ?, ?, ?, ?)";

        database << "begin transaction";// create a transaction for speed

        // insert data (sdsqlite will auto-detect data type and execute query)
        insert_query << orderTicket << orderSymbol << op << orderOpenPrice << orderStoploss
                     << orderTakeProfit << orderLots << orderOpenTime;

        //insert_query.step();

        database << "commit transaction";// complete transaction
        retValue = 1;

    }
    catch (sd::db_error& err)
    {
        // do something with error
        //std::string errText = err.what_;
//        BSTR bstrErrText = SysAllocString((err.what_).c_str());
        //LOG_INIT("C:\\test.txt");
       // FILELog::ReportingLevel() = FILELog::FromString("ERROR");
       // FILE_LOG(logDEBUG) << "Error on sqlitedb insert: " << err.what_;
    }

    return retValue;
}

BOOL __stdcall    SQLRetrieveOrder(const char* path, const int rowID, int& orderTicket, char *orderSymbol, int& op,
                                double& orderOpenPrice, double& orderStoploss,
                                double& orderTakeProfit, double& orderLots,
                                char *orderOpenTime)
{

    InitStorage(path);
    BOOL retValue = 0;
    std::string sOrderSymbol;
    std::string sOrderDatetime;

    try
    {
        std::string databasePath = "";
        databasePath = path;
        databasePath += "\\tradedup.db";



        sd::sqlite database(databasePath);   // open the db with the table already created
        sd::sql selquery(database);
        // char *orderSymbol, int op,
        //                        double& orderOpenPrice, double& orderStoploss,
        //                        double& orderTakeProfit, double& orderLots,
        //                        char *orderOpenTime
        std::string squery = "select orderid , ordersymbol, ordertype, orderopenprice, orderstoploss, ordertakeprofit, orderlots, orderopentime from activeTrades where ROWID = ";
        squery += stringify(rowID);
        selquery << squery;

        // extract the matching rows
        while (selquery.step())
        {
            selquery >>  orderTicket >> sOrderSymbol >> op >> orderOpenPrice >> orderStoploss >> orderTakeProfit >> orderLots >> sOrderDatetime;
            retValue = 1;
        }


    }
    catch (sd::db_error& err)
    {
        // do something with error
        //std::string errText = err.what_;
//        BSTR bstrErrText = SysAllocString((err.what_).c_str());

//        FILELog::ReportingLevel() = FILELog::FromString("ERROR");
//        FILE_LOG(logDEBUG) << "Error on sqlitedb insert: " << err.what_;
        retValue = 0;
    }

    strcpy(orderSymbol, sOrderSymbol.c_str());
    strcpy(orderOpenTime, sOrderDatetime.c_str());

    return retValue;
}

BOOL __stdcall    SQLGetRowCount(const char* path, int& rowCount)
{
    BOOL retValue = 0;

    InitStorage(path);

    try
    {
        //char *path=NULL;
        std::string databasePath = "";
        //path=getcwd(path,size);
        databasePath = path;
        databasePath += "\\tradedup.db";
        sd::sqlite database(databasePath);   // open the db with the table already created

        sd::sql selquery(database);
        std::string squery = "select count(*) from activeTrades";
        selquery << squery;

        // extract the matching rows
        while (selquery.step())
        {
            selquery >>   rowCount;
        }

        retValue = 1;


    }
    catch (sd::db_error& err)
    {
 //       FILELog::ReportingLevel() = FILELog::FromString("ERROR");
 //       FILE_LOG(logDEBUG) << "Error on sqliteldb select: " << err.what_;
    }


    return retValue;
}

BOOL __stdcall    SQLClearOrderTable(const char* path)
{
    BOOL retValue = 0;
    InitStorage(path);
    try
    {
        //char *path=NULL;
        std::string databasePath = "";
        //path=getcwd(path,size);
        databasePath = path;
        databasePath += "\\tradedup.db";
        sd::sqlite database(databasePath);   // open the db with the table already created

        sd::sql selquery(database);
        selquery << "delete from tempTrades";

        selquery.step();

    }
    catch (sd::db_error& err)
    {
        //FILELog::ReportingLevel() = FILELog::FromString("ERROR");
        //FILE_LOG(logDEBUG) << "Error on db delete: " << err.what_;
    }

    return retValue;

}

BOOL __stdcall    SQLFinalizeOrderTable(const char* path)
{
    BOOL retValue = 0;
    InitStorage(path);
    try
    {
        //char *path=NULL;
        std::string databasePath = "";
        //path=getcwd(path,size);
        databasePath = path;
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
        //FILELog::ReportingLevel() = FILELog::FromString("ERROR");
        //FILE_LOG(logDEBUG) << "Error on db delete: " << err.what_;
    }

    return retValue;

}

const char *tmpDir(){
    char *dirname;
    dirname = std::getenv("TMP");
    if(NULL == dirname)
        dirname = std::getenv("TMPDIR");
    if(NULL == dirname)
        dirname = std::getenv("TEMP");
    if(NULL == dirname){
        //assert(false); // no temp directory found
        dirname = ".";
    }
    return dirname;
}


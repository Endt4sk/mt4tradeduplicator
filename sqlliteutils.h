#define			STATUS_BUFFER_LENGTH 1024
#define			STATUS_MESSAGE_SUCCESS 0

#include "sdsqlite.h"

void __stdcall	   InitStorage(const char* path);
BOOL __stdcall    SQLStoreNewOrder(const char* path, const int orderTicket, const char *orderSymbol, int op,
                                const double orderOpenPrice, const double orderStoploss,
                                const double orderTakeProfit, const double orderLots,
                                const char *orderOpenTime);
char* __stdcall    GetBaseID( const char* path, char *mt4orderid);
BOOL __stdcall    SQLRetrieveOrder(const char* path, const int rowID, int& orderTicket, char *orderSymbol, int& op,
                                double& orderOpenPrice, double& orderStoploss,
                                double& orderTakeProfit, double& orderLots,
                                char *orderOpenTime);
BOOL __stdcall    SQLClearOrderTable(const char* path);
BOOL __stdcall    SQLGetRowCount(const char* path, int &rowCount);
BOOL __stdcall    SQLFinalizeOrderTable(const char* path);
const char *tmpDir();

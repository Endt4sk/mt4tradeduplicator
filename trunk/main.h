#ifndef _DLL_H_
#define _DLL_H_
#define CURL_STATICLIB

#define _UNICODE 1
#define UNICODE 1
#define _WIN32_IE 0x0501


//#include <xpath_static.h>
#include <string>
#include <sstream>
#include <time.h>
#include <iostream>
#include <fstream>
//#include "convert.h"
#include <windows.h>

#include "o2go.h"

#include "convert.h"

#if BUILDING_DLL
# define DLLIMPORT __declspec (dllexport)
#else /* Not BUILDING_DLL */
# define DLLIMPORT __declspec (dllimport)
#endif /* Not BUILDING_DLL */

#define MT4_EXPFUNC __declspec(dllexport)

enum TradeOperation
{
    OP_BUY = 0,
    OP_SELL = 1,
    OP_BUYLIMIT = 2,
    OP_SELLLIMIT = 3,
    OP_BUYSTOP = 4,
    OP_SELLSTOP = 5
};


#define export extern "C" __declspec( dllexport )


#ifdef __cplusplus
extern "C"
{
#endif

    /*class DLLIMPORT DllClass
    {

    public:

        DllClass();
        virtual ~DllClass(void);
    */
    MT4_EXPFUNC ITradeDeskAut*  __stdcall	TradeDesk();

    MT4_EXPFUNC	ICoreAut*       __stdcall	Core();

    MT4_EXPFUNC char*   __stdcall	FXCMLogin(char* pszUserID,char* pszPassword,
                                            char* pszUrl, char* pszConnection,
                                            char* terminalPath, int iDebugFlag);

    MT4_EXPFUNC void	__stdcall	FXCMLogout(void);

    MT4_EXPFUNC char*  __stdcall    NewOrderSend(char *symbol, TradeOperation cmd, const double volume,
            const double stoploss, const double price, const double takeprofit, const int debugFlag);


    MT4_EXPFUNC char* __stdcall	    NewOrderClose(char* symbol, const TradeOperation cmd, const double volume,
            const double stoploss, const double price, const double takeprofit,const double rateToClose,
            const double volumeToClose, const int debugFlag);

    MT4_EXPFUNC char* __stdcall     NewOrderDelete(char* symbol, const TradeOperation cmd, const double volume,
            const double stoploss, const double price, const double takeprofit,const int debugFlag);

    MT4_EXPFUNC char*  __stdcall    NewOrderModify(char* symbol, const TradeOperation cmd, const double volume,
            const double price, const double stoploss, const double takeprofit,const double newStoploss,
            const double newTakeprofit,const int debugFlag);

    MT4_EXPFUNC char*	__stdcall	FXCMAccountName(const int debugFlag);

    MT4_EXPFUNC double  __stdcall	FXCMAccountEquity(const int debugFlag);
    /*
    };
    */
#ifdef __cplusplus
}
#endif

#endif /* _DLL_H_ */

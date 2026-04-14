//+------------------------------------------------------------------+
//|                                               DataTrackrBeta.mq5 |
//|                                    Synchronisation Datatrackr   |
//|                                   https://www.datatrackr.fr    |
//+------------------------------------------------------------------+
#property copyright "Datatrackr"
#property link      "https://www.datatrackr.fr"
#property version   "4.00"
#property strict

//--- Paramètres d'entrée
input string USER_EMAIL = "";  // Email Datatrackr (obligatoire)
input string API_Key = "";     // Clé API du journal (obligatoire)
input string API_URL = "https://datatrackr.fr/api/functions/syncTrades";  // URL API

//--- Variables globales
datetime lastSyncTime = 0;
bool isSyncing = false;
int syncButtonX = 20;
int syncButtonY = 30;
int statusIndicatorX = 20;
int statusIndicatorY = 60;

//+------------------------------------------------------------------+
int OnInit()
{
    Print("=== Datatrackr Beta EA v4.00 démarré ===");
    
    if(StringLen(USER_EMAIL) == 0)
    {
        Alert("ERREUR : Veuillez entrer votre email Datatrackr !");
        return(INIT_FAILED);
    }
    
    if(StringLen(API_Key) == 0)
    {
        Alert("ERREUR : Veuillez entrer votre clé API !");
        return(INIT_FAILED);
    }
    
    CreateGraphicalObjects();
    Print("Synchronisation automatique au démarrage...");
    SyncTrades();
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    ObjectDelete(0, "DatatrackrSyncButton");
    ObjectDelete(0, "DatatrackrStatus");
    ObjectDelete(0, "DatatrackrStatusText");
    Print("=== Datatrackr Beta EA arrêté ===");
}

//+------------------------------------------------------------------+
void OnTick() { }

//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
    if(id == CHARTEVENT_OBJECT_CLICK)
    {
        if(sparam == "DatatrackrSyncButton")
        {
            if(!isSyncing)
            {
                Print("Synchronisation manuelle déclenchée");
                SyncTrades();
            }
            ObjectSetInteger(0, "DatatrackrSyncButton", OBJPROP_STATE, false);
        }
    }
}

//+------------------------------------------------------------------+
void CreateGraphicalObjects()
{
    ObjectCreate(0, "DatatrackrSyncButton", OBJ_BUTTON, 0, 0, 0);
    ObjectSetInteger(0, "DatatrackrSyncButton", OBJPROP_XDISTANCE, syncButtonX);
    ObjectSetInteger(0, "DatatrackrSyncButton", OBJPROP_YDISTANCE, syncButtonY);
    ObjectSetInteger(0, "DatatrackrSyncButton", OBJPROP_XSIZE, 150);
    ObjectSetInteger(0, "DatatrackrSyncButton", OBJPROP_YSIZE, 30);
    ObjectSetString(0, "DatatrackrSyncButton", OBJPROP_TEXT, "Synchroniser");
    ObjectSetInteger(0, "DatatrackrSyncButton", OBJPROP_COLOR, clrWhite);
    ObjectSetInteger(0, "DatatrackrSyncButton", OBJPROP_BGCOLOR, clrBlue);
    ObjectSetInteger(0, "DatatrackrSyncButton", OBJPROP_BORDER_COLOR, clrNavy);
    ObjectSetInteger(0, "DatatrackrSyncButton", OBJPROP_CORNER, CORNER_LEFT_UPPER);
    
    ObjectCreate(0, "DatatrackrStatus", OBJ_RECTANGLE_LABEL, 0, 0, 0);
    ObjectSetInteger(0, "DatatrackrStatus", OBJPROP_XDISTANCE, statusIndicatorX);
    ObjectSetInteger(0, "DatatrackrStatus", OBJPROP_YDISTANCE, statusIndicatorY);
    ObjectSetInteger(0, "DatatrackrStatus", OBJPROP_XSIZE, 15);
    ObjectSetInteger(0, "DatatrackrStatus", OBJPROP_YSIZE, 15);
    ObjectSetInteger(0, "DatatrackrStatus", OBJPROP_BGCOLOR, clrGray);
    ObjectSetInteger(0, "DatatrackrStatus", OBJPROP_BORDER_TYPE, BORDER_FLAT);
    ObjectSetInteger(0, "DatatrackrStatus", OBJPROP_CORNER, CORNER_LEFT_UPPER);
    
    ObjectCreate(0, "DatatrackrStatusText", OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(0, "DatatrackrStatusText", OBJPROP_XDISTANCE, statusIndicatorX + 20);
    ObjectSetInteger(0, "DatatrackrStatusText", OBJPROP_YDISTANCE, statusIndicatorY);
    ObjectSetString(0, "DatatrackrStatusText", OBJPROP_TEXT, "Prêt");
    ObjectSetInteger(0, "DatatrackrStatusText", OBJPROP_COLOR, clrWhite);
    ObjectSetInteger(0, "DatatrackrStatusText", OBJPROP_CORNER, CORNER_LEFT_UPPER);
    
    ChartRedraw();
}

//+------------------------------------------------------------------+
void UpdateStatus(string text, color statusColor)
{
    ObjectSetInteger(0, "DatatrackrStatus", OBJPROP_BGCOLOR, statusColor);
    ObjectSetString(0, "DatatrackrStatusText", OBJPROP_TEXT, text);
    ChartRedraw();
}

//+------------------------------------------------------------------+
void SyncTrades()
{
    isSyncing = true;
    UpdateStatus("Synchronisation...", clrOrange);
    
    string accountCurrency = AccountInfoString(ACCOUNT_CURRENCY);
    long accountLogin = AccountInfoInteger(ACCOUNT_LOGIN);
    string accountServer = AccountInfoString(ACCOUNT_SERVER);
    double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    
    Print("=== DÉBUT DE LA SYNCHRONISATION Beta v4.00 ===");
    Print("Email : ", USER_EMAIL);
    Print("Compte : ", accountLogin);
    Print("Serveur : ", accountServer);
    Print("Devise : ", accountCurrency);
    Print("Balance : ", accountBalance);
    
    // =====================================================
    // ÉTAPE 1 : POSITIONS FERMÉES (historique)
    // =====================================================
    datetime fromDate = 0;
    datetime toDate = TimeCurrent();
    
    if(!HistorySelect(fromDate, toDate))
    {
        Print("Erreur lors de la sélection de l'historique");
        UpdateStatus("Erreur historique", clrRed);
        isSyncing = false;
        return;
    }
    
    int totalDeals = HistoryDealsTotal();
    Print("Nombre total de deals dans l'historique : ", totalDeals);
    
    ulong processedPositions[];
    ArrayResize(processedPositions, 0);
    
    string jsonData = "{";
    jsonData += "\"email\":\"" + USER_EMAIL + "\",";
    jsonData += "\"api_key\":\"" + API_Key + "\",";
    jsonData += "\"account_id\":\"" + IntegerToString(accountLogin) + "\",";
    jsonData += "\"account_currency\":\"" + accountCurrency + "\",";
    jsonData += "\"server\":\"" + accountServer + "\",";
    jsonData += "\"trades\":[";
    
    int tradesCount = 0;
    double totalProfitNet = 0;
    
    // --- Positions FERMÉES ---
    for(int i = 0; i < totalDeals; i++)
    {
        ulong dealTicket = HistoryDealGetTicket(i);
        if(dealTicket > 0)
        {
            ENUM_DEAL_ENTRY dealEntry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
            long dealType = HistoryDealGetInteger(dealTicket, DEAL_TYPE);
            
            if(dealEntry == DEAL_ENTRY_OUT && (dealType == DEAL_TYPE_BUY || dealType == DEAL_TYPE_SELL))
            {
                ulong positionId = HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID);
                
                bool alreadyProcessed = false;
                for(int p = 0; p < ArraySize(processedPositions); p++)
                {
                    if(processedPositions[p] == positionId)
                    {
                        alreadyProcessed = true;
                        break;
                    }
                }
                
                if(!alreadyProcessed)
                {
                    int newSize = ArraySize(processedPositions) + 1;
                    ArrayResize(processedPositions, newSize);
                    processedPositions[newSize - 1] = positionId;
                    
                    double totalProfit = 0;
                    double totalCommission = 0;
                    double totalSwap = 0;
                    double totalVolume = 0;
                    datetime lastCloseTime = 0;
                    double lastClosePrice = 0;
                    datetime openTime = 0;
                    double openPrice = 0;
                    string symbol = "";
                    string orderTypeStr = "";
                    
                    for(int k = 0; k < totalDeals; k++)
                    {
                        ulong checkDealTicket = HistoryDealGetTicket(k);
                        if(checkDealTicket > 0)
                        {
                            ulong checkPositionId = HistoryDealGetInteger(checkDealTicket, DEAL_POSITION_ID);
                            long  checkDealType   = HistoryDealGetInteger(checkDealTicket, DEAL_TYPE);
                            
                            if(checkPositionId == positionId)
                            {
                                ENUM_DEAL_ENTRY checkEntry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(checkDealTicket, DEAL_ENTRY);
                                
                                if(checkDealType == DEAL_TYPE_COMMISSION)
                                {
                                    totalCommission += HistoryDealGetDouble(checkDealTicket, DEAL_PROFIT);
                                }
                                else if(checkDealType == DEAL_TYPE_BUY || checkDealType == DEAL_TYPE_SELL)
                                {
                                    double dealComm = HistoryDealGetDouble(checkDealTicket, DEAL_COMMISSION);
                                    if(dealComm != 0.0)
                                        totalCommission += dealComm;
                                    
                                    if(checkEntry == DEAL_ENTRY_IN)
                                    {
                                        openTime     = (datetime)HistoryDealGetInteger(checkDealTicket, DEAL_TIME);
                                        openPrice    = HistoryDealGetDouble(checkDealTicket, DEAL_PRICE);
                                        orderTypeStr = (checkDealType == DEAL_TYPE_BUY) ? "BUY" : "SELL";
                                        
                                        if(symbol == "")
                                            symbol = HistoryDealGetString(checkDealTicket, DEAL_SYMBOL);
                                    }
                                    else if(checkEntry == DEAL_ENTRY_OUT)
                                    {
                                        totalProfit += HistoryDealGetDouble(checkDealTicket, DEAL_PROFIT);
                                        totalSwap   += HistoryDealGetDouble(checkDealTicket, DEAL_SWAP);
                                        totalVolume += HistoryDealGetDouble(checkDealTicket, DEAL_VOLUME);
                                        
                                        datetime exitTime = (datetime)HistoryDealGetInteger(checkDealTicket, DEAL_TIME);
                                        if(exitTime > lastCloseTime)
                                        {
                                            lastCloseTime  = exitTime;
                                            lastClosePrice = HistoryDealGetDouble(checkDealTicket, DEAL_PRICE);
                                        }
                                        
                                        if(symbol == "")
                                            symbol = HistoryDealGetString(checkDealTicket, DEAL_SYMBOL);
                                    }
                                }
                            }
                        }
                    }
                    
                    double profit     = totalProfit;
                    double commission = totalCommission;
                    double swap       = totalSwap;
                    double volume     = totalVolume;
                    datetime closeTime  = lastCloseTime;
                    double closePrice   = lastClosePrice;
                    
                    double profitNet = profit + commission + swap;
                    totalProfitNet += profitNet;
                    
                    Print("Trade ", symbol,
                          " | Brut: ",       DoubleToString(profit, 2),
                          " | Commission: ", DoubleToString(commission, 2),
                          " | Swap: ",       DoubleToString(swap, 2),
                          " | NET: ",        DoubleToString(profitNet, 2));
                    
                    double profitPercent = (accountBalance > 0) ? (profitNet / accountBalance) * 100 : 0;
                    
                    double riskPercent = 0;
                    if(accountBalance > 0)
                    {
                        riskPercent = (volume * 1000) / accountBalance;
                        if(riskPercent > 10)   riskPercent = 1.0;
                        if(riskPercent < 0.01) riskPercent = 0.5;
                    }
                    else riskPercent = 1.0;
                    
                    double riskReward = 0;
                    double riskAmount = (riskPercent * accountBalance / 100);
                    if(riskAmount > 0.01)
                    {
                        riskReward = profitNet / riskAmount;
                        if(riskReward >  100) riskReward =  100;
                        if(riskReward < -100) riskReward = -100;
                    }
                    
                    if(tradesCount > 0) jsonData += ",";
                    
                    jsonData += "{";
                    jsonData += "\"ticket\":\""      + IntegerToString(dealTicket)                     + "\",";
                    jsonData += "\"position_id\":\"" + IntegerToString(positionId)                     + "\",";
                    jsonData += "\"symbol\":\""      + symbol                                           + "\",";
                    jsonData += "\"order_type\":\""  + orderTypeStr                                     + "\",";
                    jsonData += "\"open_time\":\""   + TimeToString(openTime,  TIME_DATE|TIME_MINUTES)  + "\",";
                    jsonData += "\"close_time\":\""  + TimeToString(closeTime, TIME_DATE|TIME_MINUTES)  + "\",";
                    jsonData += "\"volume\":"        + DoubleToString(volume,      2)                   + ",";
                    jsonData += "\"open_price\":"    + DoubleToString(openPrice,   5)                   + ",";
                    jsonData += "\"close_price\":"   + DoubleToString(closePrice,  5)                   + ",";
                    jsonData += "\"profit_gross\":"  + DoubleToString(profit,      2)                   + ",";
                    jsonData += "\"commission\":"    + DoubleToString(commission,  2)                   + ",";
                    jsonData += "\"swap\":"          + DoubleToString(swap,        2)                   + ",";
                    jsonData += "\"profit_net\":"    + DoubleToString(profitNet,   2)                   + ",";
                    jsonData += "\"profit_percent\":" + DoubleToString(profitPercent, 4)                + ",";
                    jsonData += "\"risk_percent\":"  + DoubleToString(riskPercent, 4)                   + ",";
                    jsonData += "\"risk_reward\":"   + DoubleToString(riskReward,  2)                   + ",";
                    jsonData += "\"status\":\"closed\"";
                    jsonData += "}";
                    
                    tradesCount++;
                }
            }
        }
    }
    
    // =====================================================
    // ÉTAPE 2 : POSITIONS OUVERTES (en cours)
    // =====================================================
    int totalOpenPositions = PositionsTotal();
    Print("Nombre de positions ouvertes : ", totalOpenPositions);
    
    for(int i = 0; i < totalOpenPositions; i++)
    {
        ulong posTicket = PositionGetTicket(i);
        if(posTicket > 0)
        {
            string symbol      = PositionGetString(POSITION_SYMBOL);
            ulong  positionId  = PositionGetInteger(POSITION_IDENTIFIER);
            long   posType     = PositionGetInteger(POSITION_TYPE);
            double openPrice   = PositionGetDouble(POSITION_PRICE_OPEN);
            double volume      = PositionGetDouble(POSITION_VOLUME);
            double currentProfit = PositionGetDouble(POSITION_PROFIT);
            double swap        = PositionGetDouble(POSITION_SWAP);
            double commission  = PositionGetDouble(POSITION_COMMISSION);
            datetime openTime  = (datetime)PositionGetInteger(POSITION_TIME);
            string orderTypeStr = (posType == POSITION_TYPE_BUY) ? "BUY" : "SELL";
            
            double profitNet = currentProfit + commission + swap;
            double profitPercent = (accountBalance > 0) ? (profitNet / accountBalance) * 100 : 0;
            
            double riskPercent = 0;
            if(accountBalance > 0)
            {
                riskPercent = (volume * 1000) / accountBalance;
                if(riskPercent > 10)   riskPercent = 1.0;
                if(riskPercent < 0.01) riskPercent = 0.5;
            }
            else riskPercent = 1.0;
            
            double riskReward = 0;
            double riskAmount = (riskPercent * accountBalance / 100);
            if(riskAmount > 0.01)
            {
                riskReward = profitNet / riskAmount;
                if(riskReward >  100) riskReward =  100;
                if(riskReward < -100) riskReward = -100;
            }
            
            Print("Position ouverte ", symbol,
                  " | Type: ", orderTypeStr,
                  " | Profit courant: ", DoubleToString(profitNet, 2));
            
            if(tradesCount > 0) jsonData += ",";
            
            jsonData += "{";
            jsonData += "\"ticket\":\""      + IntegerToString(posTicket)                             + "\",";
            jsonData += "\"position_id\":\"" + IntegerToString(positionId)                            + "\",";
            jsonData += "\"symbol\":\""      + symbol                                                  + "\",";
            jsonData += "\"order_type\":\""  + orderTypeStr                                            + "\",";
            jsonData += "\"open_time\":\""   + TimeToString(openTime, TIME_DATE|TIME_MINUTES)          + "\",";
            jsonData += "\"close_time\":\""  + ""                                                      + "\",";
            jsonData += "\"volume\":"        + DoubleToString(volume,       2)                         + ",";
            jsonData += "\"open_price\":"    + DoubleToString(openPrice,    5)                         + ",";
            jsonData += "\"close_price\":"   + DoubleToString(0.0,          5)                         + ",";
            jsonData += "\"profit_gross\":"   + DoubleToString(0.0, 2)           + ",";
            jsonData += "\"commission\":"     + DoubleToString(0.0, 2)           + ",";
            jsonData += "\"swap\":"           + DoubleToString(0.0, 2)           + ",";
            jsonData += "\"profit_net\":"     + DoubleToString(0.0, 2)           + ",";
            jsonData += "\"profit_percent\":" + DoubleToString(0.0, 4)           + ",";
            jsonData += "\"risk_percent\":"   + DoubleToString(riskPercent, 4)   + ",";
            jsonData += "\"risk_reward\":"    + DoubleToString(0.0, 2)           + ",";
            jsonData += "\"status\":\"open\"";
            jsonData += "}";
            
            tradesCount++;
        }
    }
    
    jsonData += "]";
    jsonData += "}";
    
    Print("Nombre total de positions (fermées + ouvertes) : ", tradesCount);
    Print("=== TOTAL PROFIT NET : ", DoubleToString(totalProfitNet, 2), " ===");
    
    if(tradesCount == 0)
    {
        Print("Aucune position à synchroniser");
        UpdateStatus("Aucune position", clrYellow);
        isSyncing = false;
        return;
    }
    
    bool success = SendToAPI(jsonData);
    
    if(success)
    {
        Print("Synchronisation réussie ! ", tradesCount, " positions");
        UpdateStatus("Synchronisé (" + IntegerToString(tradesCount) + " positions)", clrGreen);
        lastSyncTime = TimeCurrent();
    }
    else
    {
        Print("Erreur lors de la synchronisation");
        UpdateStatus("Erreur", clrRed);
    }
    
    Print("=== FIN DE LA SYNCHRONISATION ===");
    isSyncing = false;
}

//+------------------------------------------------------------------+
bool SendToAPI(string jsonData)
{
    char post[];
    char result[];
    string headers;
    
    StringToCharArray(jsonData, post, 0, StringLen(jsonData));
    headers = "Content-Type: application/json\r\n";
    
    Print("Envoi à l'API : ", API_URL);
    
    int res = WebRequest("POST", API_URL, headers, 5000, post, result, headers);
    
    if(res == -1)
    {
        int error = GetLastError();
        Print("Erreur WebRequest : ", error);
        
        if(error == 4060)
        {
            Alert("ERREUR : URL non autorisée.\n\n" +
                  "Outils > Options > Expert Advisors\n" +
                  "Ajoutez : " + API_URL);
        }
        return false;
    }
    
    if(res == 200 || res == 201)
    {
        string responseText = CharArrayToString(result);
        Print("Réponse API : ", responseText);
        return true;
    }
    else
    {
        Print("Code HTTP : ", res);
        Print("Réponse : ", CharArrayToString(result));
        return false;
    }
}
//+------------------------------------------------------------------+

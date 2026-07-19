//+------------------------------------------------------------------+
//| FX Signal Generator EA for MetaTrader 5                          |
//| FX マルチフレーム自動売買システム                                 |
//+------------------------------------------------------------------+

#property copyright "FX Signal Generator"
#property link      "https://tradingview.com"
#property version   "1.00"
#property strict
#property description "マルチタイムフレーム分析に基づいた自動トレード"

// ===== 入力パラメータ =====
input double RiskPercent = 2.0;              // リスク％（口座資金の％）
input double RiskRewardRatio = 2.0;          // リスク・リワード比率
input int FastMALength = 9;                  // 短期MA
input int SlowMALength = 21;                 // 長期MA
input ENUM_MA_METHOD MAType = MODE_SMA;      // MA種類
input int RSILength = 14;                    // RSI期間
input int MaxSlippage = 30;                  // スリッページ許容値
input bool UseTrailingStop = true;           // トレーリングストップ使用
input int TrailingStopDistance = 50;         // トレーリングストップpips
input bool ShowComments = true;              // コメント表示

// ===== グローバル変数 =====
CTrade trade;
int handleMA_4H_Fast, handleMA_4H_Slow, handleRSI_4H;
int handleMA_1D_Fast, handleMA_1D_Slow, handleRSI_1D;
int handleMA_1W_Fast, handleMA_1W_Slow, handleRSI_1W;

//+------------------------------------------------------------------+
//| CTrade クラス定義                                               |
//+------------------------------------------------------------------+
class CTrade
{
public:
    bool BuyPosition;
    bool SellPosition;
    ulong BuyTicket;
    ulong SellTicket;

    CTrade() : BuyPosition(false), SellPosition(false), BuyTicket(0), SellTicket(0) {}

    bool HasPosition() { return BuyPosition || SellPosition; }
    void ResetPositions() { BuyPosition = false; SellPosition = false; BuyTicket = 0; SellTicket = 0; }
};

CTrade trader;

//+------------------------------------------------------------------+
//| OnInit()                                                          |
//+------------------------------------------------------------------+
int OnInit()
{
    // インジケータハンドル取得
    handleMA_4H_Fast = iMA(_Symbol, PERIOD_H4, FastMALength, 0, MAType, PRICE_CLOSE);
    handleMA_4H_Slow = iMA(_Symbol, PERIOD_H4, SlowMALength, 0, MAType, PRICE_CLOSE);
    handleRSI_4H = iRSI(_Symbol, PERIOD_H4, RSILength, PRICE_CLOSE);

    handleMA_1D_Fast = iMA(_Symbol, PERIOD_D1, FastMALength, 0, MAType, PRICE_CLOSE);
    handleMA_1D_Slow = iMA(_Symbol, PERIOD_D1, SlowMALength, 0, MAType, PRICE_CLOSE);
    handleRSI_1D = iRSI(_Symbol, PERIOD_D1, RSILength, PRICE_CLOSE);

    handleMA_1W_Fast = iMA(_Symbol, PERIOD_W1, FastMALength, 0, MAType, PRICE_CLOSE);
    handleMA_1W_Slow = iMA(_Symbol, PERIOD_W1, SlowMALength, 0, MAType, PRICE_CLOSE);
    handleRSI_1W = iRSI(_Symbol, PERIOD_W1, RSILength, PRICE_CLOSE);

    // ハンドル検証
    if(handleMA_4H_Fast == INVALID_HANDLE || handleMA_4H_Slow == INVALID_HANDLE ||
       handleRSI_4H == INVALID_HANDLE || handleMA_1D_Fast == INVALID_HANDLE ||
       handleMA_1D_Slow == INVALID_HANDLE || handleRSI_1D == INVALID_HANDLE ||
       handleMA_1W_Fast == INVALID_HANDLE || handleMA_1W_Slow == INVALID_HANDLE ||
       handleRSI_1W == INVALID_HANDLE)
    {
        Alert("インジケータハンドルの取得に失敗しました");
        return(INIT_FAILED);
    }

    Print("FX Signal Generator EA が起動しました");
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| OnTick()                                                          |
//+------------------------------------------------------------------+
void OnTick()
{
    // 現在のポジションを確認
    UpdatePositionStatus();

    // データの取得
    double ma_4H_fast = GetIndicatorValue(handleMA_4H_Fast);
    double ma_4H_slow = GetIndicatorValue(handleMA_4H_Slow);
    double rsi_4H = GetIndicatorValue(handleRSI_4H);

    double ma_1D_fast = GetIndicatorValue(handleMA_1D_Fast);
    double ma_1D_slow = GetIndicatorValue(handleMA_1D_Slow);
    double rsi_1D = GetIndicatorValue(handleRSI_1D);

    double ma_1W_fast = GetIndicatorValue(handleMA_1W_Fast);
    double ma_1W_slow = GetIndicatorValue(handleMA_1W_Slow);
    double rsi_1W = GetIndicatorValue(handleRSI_1W);

    // トレンド判定
    int trend_4H = DetermineTrend(ma_4H_fast, ma_4H_slow);
    int trend_1D = DetermineTrend(ma_1D_fast, ma_1D_slow);
    int trend_1W = DetermineTrend(ma_1W_fast, ma_1W_slow);

    // シグナル判定
    int signal = GenerateSignal(trend_4H, trend_1D, trend_1W, rsi_4H, rsi_1D);

    // トレード実行
    ExecuteTrade(signal, ma_4H_fast, ma_4H_slow);

    // トレーリングストップ
    if(UseTrailingStop)
        ManageTrailingStop();

    // コメント表示
    if(ShowComments)
        DisplayComments(trend_4H, trend_1D, trend_1W, rsi_4H);
}

//+------------------------------------------------------------------+
//| OnDeinit()                                                        |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    IndicatorRelease(handleMA_4H_Fast);
    IndicatorRelease(handleMA_4H_Slow);
    IndicatorRelease(handleRSI_4H);
    IndicatorRelease(handleMA_1D_Fast);
    IndicatorRelease(handleMA_1D_Slow);
    IndicatorRelease(handleRSI_1D);
    IndicatorRelease(handleMA_1W_Fast);
    IndicatorRelease(handleMA_1W_Slow);
    IndicatorRelease(handleRSI_1W);
    Print("FX Signal Generator EA が停止しました");
}

//+------------------------------------------------------------------+
//| GetIndicatorValue() - インジケータ値を取得                      |
//+------------------------------------------------------------------+
double GetIndicatorValue(int handle)
{
    double buffer[1];
    if(CopyBuffer(handle, 0, 0, 1, buffer) <= 0)
    {
        Print("バッファコピーエラー");
        return(0.0);
    }
    return(buffer[0]);
}

//+------------------------------------------------------------------+
//| DetermineTrend() - トレンド判定                                  |
//+------------------------------------------------------------------+
int DetermineTrend(double ma_fast, double ma_slow)
{
    if(ma_fast > ma_slow)
        return(1);  // アップトレンド
    else if(ma_fast < ma_slow)
        return(-1); // ダウントレンド
    else
        return(0);  // 不確定
}

//+------------------------------------------------------------------+
//| GenerateSignal() - シグナル生成                                  |
//+------------------------------------------------------------------+
int GenerateSignal(int trend_4H, int trend_1D, int trend_1W, double rsi_4H, double rsi_1D)
{
    // マルチタイムフレーム確認
    // 買いシグナル: 日足と4時間足がアップトレンド
    if(trend_1D > 0 && trend_4H > 0)
    {
        // RSI確認（買われすぎ回避）
        if(rsi_4H < 70 && rsi_1D < 70)
        {
            // 週足確認
            if(trend_1W > 0)
                return(2);  // 強い買いシグナル
            else
                return(1);  // 弱い買いシグナル
        }
    }

    // 売りシグナル: 日足と4時間足がダウントレンド
    if(trend_1D < 0 && trend_4H < 0)
    {
        // RSI確認（売られすぎ回避）
        if(rsi_4H > 30 && rsi_1D > 30)
        {
            // 週足確認
            if(trend_1W < 0)
                return(-2);  // 強い売りシグナル
            else
                return(-1);  // 弱い売りシグナル
        }
    }

    return(0);  // シグナルなし
}

//+------------------------------------------------------------------+
//| ExecuteTrade() - トレード実行                                   |
//+------------------------------------------------------------------+
void ExecuteTrade(int signal, double ma_fast, double ma_slow)
{
    // 既存ポジションがある場合は処理しない
    if(trader.HasPosition())
        return;

    if(signal > 0)  // 買いシグナル
    {
        // ストップロスとテイクプロフィットを計算
        double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        double stopLoss = ma_slow - 50 * Point();
        double takeProfit = entry + (entry - stopLoss) * RiskRewardRatio;

        // ロットサイズ計算
        double lotSize = CalculateLotSize(entry, stopLoss);

        // 買い注文
        if(SendBuyOrder(entry, stopLoss, takeProfit, lotSize))
        {
            trader.BuyPosition = true;
            if(ShowComments)
                Print("BUY Order: Entry=", DoubleToString(entry, _Digits),
                      " SL=", DoubleToString(stopLoss, _Digits),
                      " TP=", DoubleToString(takeProfit, _Digits));
        }
    }
    else if(signal < 0)  // 売りシグナル
    {
        // ストップロスとテイクプロフィットを計算
        double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        double stopLoss = ma_slow + 50 * Point();
        double takeProfit = entry - (stopLoss - entry) * RiskRewardRatio;

        // ロットサイズ計算
        double lotSize = CalculateLotSize(entry, stopLoss);

        // 売り注文
        if(SendSellOrder(entry, stopLoss, takeProfit, lotSize))
        {
            trader.SellPosition = true;
            if(ShowComments)
                Print("SELL Order: Entry=", DoubleToString(entry, _Digits),
                      " SL=", DoubleToString(stopLoss, _Digits),
                      " TP=", DoubleToString(takeProfit, _Digits));
        }
    }
}

//+------------------------------------------------------------------+
//| CalculateLotSize() - ロットサイズ計算                           |
//+------------------------------------------------------------------+
double CalculateLotSize(double entry, double stopLoss)
{
    double riskAmount = AccountInfoDouble(ACCOUNT_BALANCE) * (RiskPercent / 100.0);
    double pipsDifference = MathAbs(entry - stopLoss) / Point();
    double lotSize = riskAmount / (pipsDifference * SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE));

    // 最小ロットと最大ロットを確認
    double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double stepLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

    if(lotSize < minLot)
        lotSize = minLot;
    if(lotSize > maxLot)
        lotSize = maxLot;

    // ステップに合わせる
    lotSize = MathFloor(lotSize / stepLot) * stepLot;

    return(lotSize);
}

//+------------------------------------------------------------------+
//| SendBuyOrder() - 買い注文送信                                   |
//+------------------------------------------------------------------+
bool SendBuyOrder(double entry, double stopLoss, double takeProfit, double lotSize)
{
    MqlTradeRequest request = {0};
    MqlTradeResult result = {0};

    request.action = TRADE_ACTION_DEAL;
    request.symbol = _Symbol;
    request.volume = lotSize;
    request.type = ORDER_TYPE_BUY;
    request.price = entry;
    request.sl = stopLoss;
    request.tp = takeProfit;
    request.deviation = MaxSlippage;
    request.magic = 20240115;
    request.comment = "FX Signal Generator - BUY";

    if(!OrderSend(request, result))
    {
        Print("買い注文送信エラー: ", GetLastError());
        return(false);
    }

    trader.BuyTicket = result.order;
    return(true);
}

//+------------------------------------------------------------------+
//| SendSellOrder() - 売り注文送信                                  |
//+------------------------------------------------------------------+
bool SendSellOrder(double entry, double stopLoss, double takeProfit, double lotSize)
{
    MqlTradeRequest request = {0};
    MqlTradeResult result = {0};

    request.action = TRADE_ACTION_DEAL;
    request.symbol = _Symbol;
    request.volume = lotSize;
    request.type = ORDER_TYPE_SELL;
    request.price = entry;
    request.sl = stopLoss;
    request.tp = takeProfit;
    request.deviation = MaxSlippage;
    request.magic = 20240115;
    request.comment = "FX Signal Generator - SELL";

    if(!OrderSend(request, result))
    {
        Print("売り注文送信エラー: ", GetLastError());
        return(false);
    }

    trader.SellTicket = result.order;
    return(true);
}

//+------------------------------------------------------------------+
//| ManageTrailingStop() - トレーリングストップ管理                 |
//+------------------------------------------------------------------+
void ManageTrailingStop()
{
    if(!trader.HasPosition())
        return;

    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(!PositionSelectByTicket(PositionGetTicket(i)))
            continue;

        if(PositionGetSymbol(i) != _Symbol)
            continue;

        ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
        double posPrice = PositionGetDouble(POSITION_PRICE_OPEN);
        double posStopLoss = PositionGetDouble(POSITION_SL);
        double currentPrice = (posType == POSITION_TYPE_BUY) ?
                            SymbolInfoDouble(_Symbol, SYMBOL_BID) :
                            SymbolInfoDouble(_Symbol, SYMBOL_ASK);

        if(posType == POSITION_TYPE_BUY)
        {
            double newStopLoss = currentPrice - TrailingStopDistance * Point();
            if(newStopLoss > posStopLoss)
            {
                ModifyPosition(PositionGetTicket(i), newStopLoss, PositionGetDouble(POSITION_TP));
            }
        }
        else if(posType == POSITION_TYPE_SELL)
        {
            double newStopLoss = currentPrice + TrailingStopDistance * Point();
            if(newStopLoss < posStopLoss)
            {
                ModifyPosition(PositionGetTicket(i), newStopLoss, PositionGetDouble(POSITION_TP));
            }
        }
    }
}

//+------------------------------------------------------------------+
//| ModifyPosition() - ポジション修正                               |
//+------------------------------------------------------------------+
void ModifyPosition(ulong ticket, double stopLoss, double takeProfit)
{
    MqlTradeRequest request = {0};
    MqlTradeResult result = {0};

    request.action = TRADE_ACTION_SLTP;
    request.position = ticket;
    request.symbol = _Symbol;
    request.sl = stopLoss;
    request.tp = takeProfit;

    OrderSend(request, result);
}

//+------------------------------------------------------------------+
//| UpdatePositionStatus() - ポジション状態を更新                   |
//+------------------------------------------------------------------+
void UpdatePositionStatus()
{
    trader.ResetPositions();

    for(int i = 0; i < PositionsTotal(); i++)
    {
        if(!PositionSelectByTicket(PositionGetTicket(i)))
            continue;

        if(PositionGetSymbol(i) != _Symbol)
            continue;

        ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

        if(posType == POSITION_TYPE_BUY)
        {
            trader.BuyPosition = true;
            trader.BuyTicket = PositionGetTicket(i);
        }
        else if(posType == POSITION_TYPE_SELL)
        {
            trader.SellPosition = true;
            trader.SellTicket = PositionGetTicket(i);
        }
    }
}

//+------------------------------------------------------------------+
//| DisplayComments() - コメント表示                                |
//+------------------------------------------------------------------+
void DisplayComments(int trend_4H, int trend_1D, int trend_1W, double rsi_4H)
{
    string comment = "";
    comment += "Account Balance: " + DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2) + "\n";
    comment += "Symbol: " + _Symbol + "\n";
    comment += "4H Trend: " + (trend_4H > 0 ? "UP" : trend_4H < 0 ? "DOWN" : "RANGE") + "\n";
    comment += "1D Trend: " + (trend_1D > 0 ? "UP" : trend_1D < 0 ? "DOWN" : "RANGE") + "\n";
    comment += "1W Trend: " + (trend_1W > 0 ? "UP" : trend_1W < 0 ? "DOWN" : "RANGE") + "\n";
    comment += "RSI 4H: " + DoubleToString(rsi_4H, 2) + "\n";
    comment += "Position: " + (trader.BuyPosition ? "LONG" : trader.SellPosition ? "SHORT" : "NO POSITION") + "\n";

    Comment(comment);
}
//+------------------------------------------------------------------+

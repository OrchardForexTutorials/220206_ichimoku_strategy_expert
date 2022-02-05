/*

	Ichimoku v1
	Expert
	
	Copyright 2022, Orchard Forex
	https://www.orchardforex.com

*/

/** Disclaimer and Licence

 *	This file is free software: you can redistribute it and/or modify
 *	it under the terms of the GNU General Public License as published by
 *	the Free Software Foundation, either version 3 of the License, or
 *	(at your option) any later version.

 *	This program is distributed in the hope that it will be useful,
 *	but WITHOUT ANY WARRANTY; without even the implied warranty of
 *	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *	GNU General Public License for more details.
 
 *	You should have received a copy of the GNU General Public License
 *	along with this program.  If not, see <http://www.gnu.org/licenses/>.

 *	All trading involves risk. You should have received the risk warnings
 *	and terms of use in the README.MD file distributed with this software.
 *	See the README.MD file for more information and before using this software.

 **/

/*
 *	Strategy
 *
 *	Buy when:
 *		Candle crosses into Kumo cloud from below and closes above Leading Span A
 *	Sell when:
 *		Candle crosses into Kumo cloud from above and closes below Leading Span A
 *	Close when:
 *		Price touches Leading Span B
 *	Stop Loss:
 *		1:1 from the initial take profit or
 *		1:1 floating from the current take profit
 *
 *	This will use Take Profit and Stop Loss levels, not monitor the trade for a close
 *
 */

#include "Framework.mqh"

class CExpert : public CExpertBase {

private:

protected:

	int		mHandle;
	
	void		Loop();
	void		UpdateTPSL(double tp);

public:

	CExpert(	double orderSize, string tradeComment, long magic);
	~CExpert();

};


CExpert::CExpert(	double orderSize, string tradeComment, long magic)
						:	CExpertBase(orderSize, tradeComment, magic) {

	#ifdef __MQL5__
		mHandle			=	iIchimoku(mSymbol, mTimeframe, 9, 26, 52);
		if (mHandle==INVALID_HANDLE) {
			mInitResult		=	INIT_FAILED;
			return;
		}
	#endif
	
	mInitResult		=	INIT_SUCCEEDED;
	
}

CExpert::~CExpert() {

	#ifdef __MQL5__
		IndicatorRelease(mHandle);
	#endif 
	
}

void		CExpert::Loop() {

	if (!mNewBar) return;	// No need to check price at each tick because
									//	There is a tp and sl to take care of that

	//	Load indicator values MQL4
	#ifdef __MQL4__
		double	spanA1	=	iIchimoku(mSymbol, mTimeframe, 9, 26, 52, MODE_SENKOUSPANA, 1);
		double	spanA2	=	iIchimoku(mSymbol, mTimeframe, 9, 26, 52, MODE_SENKOUSPANA, 2);
		double	spanB		=	iIchimoku(mSymbol, mTimeframe, 9, 26, 52, MODE_SENKOUSPANB, 1);
	#endif

	//	Load indicator values MQL5	
	#ifdef __MQL5__
		double	buf[];
		ArraySetAsSeries(buf, true);
		CopyBuffer(mHandle, SENKOUSPANA_LINE, 0, 3, buf);
		double	spanA1	=	buf[1];
		double	spanA2	=	buf[2];
		CopyBuffer(mHandle, SENKOUSPANB_LINE, 0, 3, buf);
		double	spanB		=	buf[1];
	#endif 
	
	//	Closing prices
	double	close1	=	iClose(mSymbol, mTimeframe, 1);
	double	close2	=	iClose(mSymbol, mTimeframe, 2);

	double	tp	=	spanB;
	double	sl	=	(spanA1<spanB) ?
							(mLastTick.bid*2)-spanB :
							(mLastTick.ask*2)-spanB;
	
	Recount();
	if (mCount>0) {
		UpdateTPSL(tp);
		Recount();
	}
	
	if (mCount>0) return;	// Test again in case of close above
	
	if (close2<spanA2 && close1>=spanA1 && close1<spanB) {
		Trade.Buy(mOrderSize, mSymbol, 0, sl, tp, mTradeComment);
	} else
	if (close2>spanA2 && close1<=spanA1 && close1>spanB) {
		Trade.Sell(mOrderSize, mSymbol, 0, sl, tp, mTradeComment);
	}

	return;	
	
}

void		CExpert::UpdateTPSL( double tp ) {

	double	sl;
	for (int i=PositionInfo.Total()-1; i>=0; i--) {
		
		if (!PositionInfo.SelectByIndex(i)) continue;
		if (PositionInfo.Symbol()!=mSymbol || PositionInfo.Magic()!=mMagic) continue;

		sl	=	(PositionInfo.PriceOpen()*2.0)-tp;

		//	Handle conditions where the tp/sl has moved past current price
		if (PositionInfo.PositionType()==POSITION_TYPE_BUY) {
			if (mLastTick.bid>=tp || mLastTick.bid<=sl) {
				Trade.PositionClose(PositionInfo.Ticket());
				continue;
			} 
		} else
		if (PositionInfo.PositionType()==POSITION_TYPE_SELL) {
			if (mLastTick.ask<=tp || mLastTick.ask>=sl) {
				Trade.PositionClose(PositionInfo.Ticket());
				continue;
			} 
		}
		
		if (PositionInfo.TakeProfit()!=tp
				|| PositionInfo.StopLoss()!=sl) {
			Trade.PositionModify(PositionInfo.Ticket(), sl, tp);
		}		
		
	}

}

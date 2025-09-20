************************************************************
* Assignment – 20.09.2025
************************************************************

* Start log
capture log close
log using "empirical_finance_assignment.log", replace text

************************************************************
* 1. Load data
************************************************************
use tic date rh PRC SHROUT using "rh_daily.dta", clear

************************************************************
* 2. Data Cleaning
************************************************************
drop if missing(PRC) | PRC < 0
drop if inlist(date, mdy(3,2,2020), mdy(3,3,2020), mdy(6,18,2020))

************************************************************
* 3. Distinct Stocks & Days
************************************************************
egen stockid = tag(tic)
egen dayid = tag(date)
* count if stockid
* count if dayid

************************************************************
* 4. Year & Summary Stats
************************************************************
gen year = year(date)
* by year, sort: summarize rh
* by year, sort: tabstat rh, statistics(mean sd median n)

* Total RH investors in 2018
summarize rh if year==2018, meanonly
display "RH investors 2018 = " r(sum)

* Median RH investors in 2020
summarize rh if year==2020, detail
display "Median RH investors 2020 = " r(p50)

* Dataset is stock-day level
duplicates report tic date

************************************************************
* 5. Days Per Ticker
************************************************************
bysort tic: egen days_per_ticker = count(date)
egen ticker_tag = tag(tic)
summarize days_per_ticker if ticker_tag, meanonly

display "Avg Days per Ticker: " r(mean)

* Sprint Corp check
summarize days_per_ticker if tic=="S"

************************************************************
* 6. Derived Variables
************************************************************
gen mktcap = PRC * SHROUT / 1000
bysort tic (date): gen ret = (mktcap - mktcap[_n-1]) / mktcap[_n-1]
bysort tic (date): gen userchg = rh - rh[_n-1]
bysort tic (date): gen userratio = rh / rh[_n-1]
drop if missing(ret)

************************************************************
* 7. Top Movers
************************************************************
gen absret = abs(ret)
bysort date (absret): gen rank_absret = _N - _n + 1
bysort date: gen topmover = rank_absret <= 20
gen byte posret = (ret > 0)

* tab posret if topmover==1

tabstat mktcap ret absret userchg userratio, by(topmover) statistics(n mean sd median)

bysort tic (date): gen lag_topmover = topmover[_n-1]

************************************************************
* Quality Check – Top Movers Per Day
************************************************************
bys date: egen tmcount = total(topmover)
summ tmcount
* list date tmcount if tmcount != 20

************************************************************
* Heteroskedasticity Tests
************************************************************
quietly regress userchg lag_topmover
estat hettest
local bp_pvalue = r(p)
estat imtest, white
local white_pvalue = r(p)

if `bp_pvalue' < 0.05 | `white_pvalue' < 0.05 {
    local use_robust = 1
}
else {
    local use_robust = 0
}

************************************************************
* Regressions – Lagged Top Mover
************************************************************

* --- Model 1: userchg on lag_topmover ---
if `use_robust' {
    regress userchg lag_topmover, robust
}
else {
    regress userchg lag_topmover
}

local coef_lag = _b[lag_topmover]
display "Model 1: Coef = " `coef_lag'

* --- Model 2: userratio on lag_topmover ---
if `use_robust' {
    regress userratio lag_topmover, robust
}
else {
    regress userratio lag_topmover
}
local coef_lag2 = _b[lag_topmover]
display "Model 2: Coef = " `coef_lag2'

* --- Model 3: userchg on lag_topmover + mktcap ---
if `use_robust' {
    regress userchg lag_topmover mktcap, robust
}
else {
    regress userchg lag_topmover mktcap
}
local coef_lag3 = _b[lag_topmover]
display "Model 3: Coef = " `coef_lag3'

************************************************************
* DiD: RH Top Movers Feature Introduction (Aug 1, 2019)
************************************************************
gen byte list = date >= mdy(8,1,2019)

if `use_robust' {
    regress userchg lag_topmover list c.lag_topmover#c.list mktcap, robust
}
else {
    regress userchg lag_topmover list c.lag_topmover#c.list mktcap
}

************************************************************
* End log
************************************************************
log close

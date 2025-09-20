************************************************************
* Assignment for Empirical Methods in Finance – Christoph Herler, 22.09.2025
************************************************************
* Presets


* 2. Loading data
use tic date rh PRC SHROUT using ///
    "rh_daily.dta", clear

************************************************************
* Data cleaning – Assignment 1
************************************************************

* a) Drop observations with missing or negative stock price
drop if missing(PRC) | PRC < 0

* b) Drop observations on Robinhood outage dates
drop if inlist(date, mdy(3,2,2020), mdy(3,3,2020), mdy(6,18,2020))

************************************************************
* Count remaining distinct stocks and trading days
************************************************************

* Count number of distinct stocks (unique ticker symbols)
egen stockid = tag(tic)
count if stockid

* Count number of distinct trading days (unique dates)
egen dayid = tag(date)
count if dayid

************************************************************
* Task 2 – Create year variable and summary statistics
************************************************************

* a) Generate year from the Stata daily date variable
gen year = year(date)

* b) Summary statistics of rh (number of RH investors holding a stock),
*    by year: N (obs), mean, standard deviation, median
by year, sort: summarize rh
by year, sort: tabstat rh, statistics(mean sd median n)

************************************************************
* Task 2(b) – Check which statements are correct
************************************************************
* i. Total number of Robinhood investors in 2018
*    (sum of rh across all observations in 2018) -> INCORRECT
summarize rh if year==2018, detail
display "Total RH investors 2018 = " r(sum)

* ii & iii. Median number of investors in 2020 - ii -> INCORRECT, iii -> CORRECT
summarize rh if year==2020, detail
display "Median number of investors per stock in 2020 = " r(p50)

* iv. Check if data is at stock-day level
duplicates report tic date

************************************************************
* Task 3 – Number of trading-day observations per ticker
************************************************************

bysort tic: egen days_per_ticker = count(date)
egen ticker_tag = tag(tic)

summarize days_per_ticker if ticker_tag, detail
display "Average days per ticker = " r(mean)
display "Median days per ticker = " r(p50)
display "Minimum days per ticker = " r(min)
display "Maximum days per ticker = " r(max)

summarize days_per_ticker if tic=="S"

************************************************************
* Task 4 – Calculate new variables
************************************************************

gen mktcap = PRC * SHROUT / 1000
bysort tic (date): gen ret = (mktcap - mktcap[_n-1]) / mktcap[_n-1]
bysort tic (date): gen userchg = rh - rh[_n-1]
bysort tic (date): gen userratio = rh / rh[_n-1]
drop if missing(ret)

summarize mktcap ret userchg userratio

************************************************************
* Task 5 – Identify top movers
************************************************************

gen absret = abs(ret)
bysort date (absret): gen rank_absret = _N - _n + 1
bysort date: gen topmover = rank_absret <= 20
gen byte posret = (ret > 0)
tab posret if topmover==1
tabstat mktcap ret absret userchg userratio, by(topmover) statistics(n mean sd median)
bysort tic (date): gen lag_topmover = topmover[_n-1]

************************************************************
* Quality check: confirm 20 top movers per day
************************************************************

bys date: egen tmcount = total(topmover)
summ tmcount
list date tmcount if tmcount != 20

************************************************************
* Task 5(f) – Model 1: userchg on lag_topmover
************************************************************

regress userchg lag_topmover
estat hettest
regress userchg lag_topmover, robust

************************************************************
* Task 5(g) – Model 2: userratio on lag_topmover
************************************************************

regress userratio lag_topmover
estat hettest
regress userratio lag_topmover, robust

************************************************************
* Task 5(h) – Model 3: userchg on lag_topmover + mktcap
************************************************************

regress userchg lag_topmover mktcap
estat hettest
regress userchg lag_topmover mktcap, robust

************************************************************
* Task 6 – Feature Launch Interaction Model (Diff-in-Diff)
************************************************************

gen byte list = date >= mdy(8,1,2019)

regress userchg lag_topmover list c.lag_topmover#c.list mktcap
estat hettest
regress userchg lag_topmover list c.lag_topmover#c.list mktcap, robust

************************************************************
* Task 7 – Interpretation Notes (for PDF)
************************************************************

* β1  = effect of being a lagged top mover BEFORE Aug 1, 2019.
* β2  = shift in baseline user change after Aug 1, 2019 (when the list existed).
* β3  = additional effect of being a lagged top mover AFTER Aug 1, 2019.
* β4  = effect of market capitalization (in millions) on user change.

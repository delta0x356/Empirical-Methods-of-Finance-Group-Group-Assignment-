************************************************************
* Assignment for Empirical Methods in Finance – Christoph Herler, Darius Richter, Leonard   22.09.2025
************************************************************
* Presets

* Start log file (close any existing log first)
capture log close
log using "empirical_finance_assignment.log", replace text

* 1. Loading data
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
*     (one observation per stock per day)
duplicates report tic date
* iv. The dataset is organized at the stock–day level (one observation per ticker and date).
*     This means each row represents a specific stock on a specific trading day. -> CORRECT

************************************************************
* Task 3 – Number of trading-day observations per ticker
************************************************************

* a) Count the number of distinct trading days for each ticker
bysort tic: egen days_per_ticker = count(date)

* b) Keep only one row per ticker to summarize these counts
egen ticker_tag = tag(tic)

* c) Compute average, median, minimum, and maximum number of days per ticker
summarize days_per_ticker if ticker_tag, detail
* r(mean)  = average number of days
* r(p50)   = median number of days
* r(min)   = minimum number of days
* r(max)   = maximum number of days

display "Average days per ticker = " r(mean)
display "Median days per ticker = " r(p50)
display "Minimum days per ticker = " r(min)
display "Maximum days per ticker = " r(max)

* d) Check the number of days for Sprint Corporation (ticker "S")
summarize days_per_ticker if tic=="S"

* Explanation:
* Not all tickers are observed for the same number of trading days because
*   - some firms IPO'd or were delisted during the sample period,
*   - some merged or were acquired,
*   - or trading was halted / data missing on some dates.
* Sprint Corporation (ticker S) has only 455 days because it merged with
* T-Mobile US in 2020 and was delisted, so data collection stopped.

************************************************************
* Task 4 – Calculate new variables
************************************************************

* a) Daily market capitalization (mktcap) in millions of dollars
*    PRC is in dollars and SHROUT is in thousands of shares.
*    Multiply price × (shares outstanding in thousands), divide by 1,000 to convert to millions.
gen mktcap = PRC * SHROUT / 1000

* b) Daily simple returns: (mktcap_t - mktcap_t-1) / mktcap_t-1
*    Compute within each ticker and sort by date so that t-1 is the previous trading day for that stock.
bysort tic (date): gen ret = (mktcap - mktcap[_n-1]) / mktcap[_n-1]

* c) Daily change in users: rh_t - rh_t-1
bysort tic (date): gen userchg = rh - rh[_n-1]

* d) Ratio of users compared to prior day: rh_t / rh_t-1
bysort tic (date): gen userratio = rh / rh[_n-1]

* Drop observations with missing returns (these occur on the first trading day for each ticker)
drop if missing(ret)

* Control -> Summarization
summarize mktcap ret userchg userratio

************************************************************
* Task 5 – Identify top movers
************************************************************

* a) Absolute daily return
gen absret = abs(ret)

* b) Dummy = 1 if stock is among the 20 largest absolute-return movers on that day
*    We rank absret within each trading day and flag the top 20.
bysort date (absret): gen rank_absret = _N - _n + 1   // reverse rank: 1 = largest
bysort date: gen topmover = rank_absret <= 20

* c.) Fraction of top movers with positive vs. negative returns
* Create a dummy for positive daily return (1 = positive, 0 = zero or negative)
gen byte posret = (ret > 0)

* One-way tabulation of positive vs. non-positive returns among top movers
tab1 posret if topmover==1

* Optional: see counts and percentages more explicitly
tab posret if topmover==1

* d.) Summary statistics for top movers vs non-top movers

* Report N, mean, standard deviation and median of key variables,
* separately for top movers and non-top movers
tabstat mktcap ret absret userchg userratio, by(topmover) statistics(n mean sd median)

* e.) Lagged topmover indicator

* Generate lag_topmover = 1 if the stock was a top mover on its previous trading day
bysort tic (date): gen lag_topmover = topmover[_n-1]

************************************************************
* Quality check: confirm 20 top movers per day
************************************************************

* Count the number of top movers within each date
bys date: egen tmcount = total(topmover)

* Summarize to see if tmcount equals 20 on (almost) all days
summ tmcount

* Optional quick check: list days where the count is not 20
list date tmcount if tmcount != 20

************************************************************
* 10f–h. Regressions on lagged top mover status
************************************************************

* ----f.) Model 1: user change on lagged top mover ----
regress userchg lag_topmover

* Interpretation:
* Coefficient on lag_topmover = 420.38
*   -> On average, if a stock was a top mover yesterday,
*      the number of RH users holding it increases on average c.p. by about
*      420 on the next day, compared to non-top movers.
* p-value < 0.001
*   -> Highly significant; we reject the null of no effect.
* t-statistic = 133.52
*   -> Far above 1.96, confirming strong significance.
* 95% confidence interval = [414.21 , 426.55]
*   -> We are 95% confident the true effect lies inside this range.

************************************************************

* ----g.) Model 2: user ratio on lagged top mover ----
regress userratio lag_topmover

* Interpretation:
* Coefficient on lag_topmover = 0.225
*   -> If a stock was a top mover on the previous day,
*      the number of RH users on the following day is on average 22.5% higher
*      than on day before (user ratio increases by 0.225).
* p-value < 0.001
*   -> Highly significant.
* t-statistic = 91.43
*   -> Well above 1.96, confirming strong significance.
* 95% confidence interval = [0.220 , 0.229]
*   -> Effect is positive and precisely estimated.

************************************************************

* ----h.) Model 3: user change on lagged top mover + market capitalization ----
regress userchg lag_topmover mktcap

* Interpretation:
* Coefficient on lag_topmover = 427.53
*   -> Including market capitalization raises the estimated effect
*      from about 420 (Model 1) to roughly 428.
* Coefficient on mktcap = 0.00091
*   -> Each extra $1 million of market capitalization is associated
*      with about 0.9 more RH users per day.
* p-values < 0.001 for both predictors
*   -> Both effects are highly significant.
* 95% confidence interval for lag_topmover = [421.40 , 433.65]
*   -> Strong and precise positive effect.

************************************************************
* Economic meaning for Task 5(h)
************************************************************
* After controlling for firm size, the effect of being a top mover
* becomes larger. This indicates that top movers are on average
* smaller than typical firms. The univariate model therefore
* underestimated the true effect.
* Correct multiple-choice statement:
*   (i) The univariate model underestimates the effect of being a
*       top mover on the change in RH users. This is because top
*       movers are smaller than the average company. -> CORRECT
************************************************************

************************************************************
* Task 6 – Top Movers feature introduction (Aug 1, 2019)
************************************************************

* Define list = 1 on and after August 1, 2019, 0 otherwise
gen byte list = date >= mdy(8,1,2019)

* Estimate the model:
*    userchg = β0 + β1 lag_topmover + β2 list + β3 lag_topmover × list + β4 mktcap + ε
regress userchg lag_topmover list c.lag_topmover#c.list mktcap

************************************************************
* Task 7 – Interpretation
************************************************************

* β1  = effect of being a lagged top mover BEFORE Aug 1, 2019.
* β2  = shift in baseline user change after Aug 1, 2019 (when the list existed).
* β3  = additional effect of being a lagged top mover AFTER Aug 1, 2019
*       (i.e. the difference-in-differences effect).
* β4  = effect of market capitalization (in millions) on user change.
* Significance is judged by p-value, t-statistic, and 95% confidence interval
* as in the previous regressions.




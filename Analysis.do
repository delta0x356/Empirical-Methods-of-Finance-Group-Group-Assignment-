************************************************************
* Assignment for Empirical Methods in Finance – Christoph Herler, Darius Richter and Leonard Hug,  22.09.2025
************************************************************
* Presets

* Start log file (close any existing log first)
capture log close
log using "Results.log", replace text

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
* Test for heteroskedasticity before running main regressions
************************************************************

display ""
display "************************************************************"
display "* HETEROSKEDASTICITY TESTING"
display "************************************************************"

* Run initial regression to test for heteroskedasticity
quietly regress userchg lag_topmover

* Breusch-Pagan test for heteroskedasticity
estat hettest
local bp_pvalue = r(p)
display "Breusch-Pagan test p-value: " `bp_pvalue'

* White test for heteroskedasticity  
estat imtest, white
local white_pvalue = r(p)
display "White test p-value: " `white_pvalue'

* Decision rule: if either test rejects at 5% level, use robust standard errors
if `bp_pvalue' < 0.05 | `white_pvalue' < 0.05 {
    local use_robust = 1
    display ""
    display "*** HETEROSKEDASTICITY DETECTED ***"
    display "At least one test rejects homoskedasticity at 5% level"
    display "Using robust standard errors for all regressions"
    display ""
}
else {
    local use_robust = 0
    display ""
    display "*** NO STRONG EVIDENCE OF HETEROSKEDASTICITY ***"
    display "Both tests fail to reject homoskedasticity at 5% level"
    display "Using standard OLS standard errors"
    display ""
}

************************************************************
* 5f–h. Regressions on lagged top mover status
************************************************************

display "************************************************************"
display "* MAIN REGRESSION ANALYSIS"
display "************************************************************"

* ----f.) Model 1: user change on lagged top mover ----
display ""
display "*** MODEL 1: User Change on Lagged Top Mover ***"

if `use_robust' == 1 {
    regress userchg lag_topmover, robust
    display "Note: Using robust standard errors due to heteroskedasticity"
}
else {
    regress userchg lag_topmover
    display "Note: Using standard OLS standard errors"
}

* Store results for interpretation
local coef_lag = _b[lag_topmover]
local se_lag = _se[lag_topmover]
local t_lag = _b[lag_topmover]/_se[lag_topmover]
local p_lag = 2*ttail(e(df_r), abs(`t_lag'))
local ci_lower = `coef_lag' - invttail(e(df_r), 0.025) * `se_lag'
local ci_upper = `coef_lag' + invttail(e(df_r), 0.025) * `se_lag'

display ""
display "Interpretation:"
display "Coefficient on lag_topmover = " %9.2f `coef_lag'
display "  -> On average, if a stock was a top mover yesterday,"
display "     the number of RH users holding it increases by about"
display "     " %9.0f `coef_lag' " on the next day, compared to non-top movers."
display "p-value = " %9.3f `p_lag'
if `p_lag' < 0.001 {
    display "  -> Highly significant; we reject the null of no effect."
}
else if `p_lag' < 0.05 {
    display "  -> Significant at 5% level."
}
else {
    display "  -> Not statistically significant at conventional levels."
}
display "t-statistic = " %9.2f `t_lag'
display "95% confidence interval = [" %9.2f `ci_lower' ", " %9.2f `ci_upper' "]"

************************************************************

* ----g.) Model 2: user ratio on lagged top mover ----
display ""
display "*** MODEL 2: User Ratio on Lagged Top Mover ***"

if `use_robust' == 1 {
    regress userratio lag_topmover, robust
    display "Note: Using robust standard errors due to heteroskedasticity"
}
else {
    regress userratio lag_topmover
    display "Note: Using standard OLS standard errors"
}

* Store results for interpretation
local coef_lag2 = _b[lag_topmover]
local se_lag2 = _se[lag_topmover]
local t_lag2 = _b[lag_topmover]/_se[lag_topmover]
local p_lag2 = 2*ttail(e(df_r), abs(`t_lag2'))

display ""
display "Interpretation:"
display "Coefficient on lag_topmover = " %9.3f `coef_lag2'
display "  -> If a stock was a top mover on the previous day,"
display "     the number of RH users on the following day is on average"
display "     " %5.1f `coef_lag2'*100 "% higher than the day before."
display "p-value = " %9.3f `p_lag2'
if `p_lag2' < 0.001 {
    display "  -> Highly significant."
}
else if `p_lag2' < 0.05 {
    display "  -> Significant at 5% level."
}

************************************************************

* ----h.) Model 3: user change on lagged top mover + market capitalization ----
display ""
display "*** MODEL 3: User Change with Market Cap Control ***"

if `use_robust' == 1 {
    regress userchg lag_topmover mktcap, robust
    display "Note: Using robust standard errors due to heteroskedasticity"
}
else {
    regress userchg lag_topmover mktcap
    display "Note: Using standard OLS standard errors"
}

* Store results for interpretation
local coef_lag3 = _b[lag_topmover]
local coef_mktcap = _b[mktcap]
local se_lag3 = _se[lag_topmover]
local ci_lower3 = `coef_lag3' - invttail(e(df_r), 0.025) * `se_lag3'
local ci_upper3 = `coef_lag3' + invttail(e(df_r), 0.025) * `se_lag3'

display ""
display "Interpretation:"
display "Coefficient on lag_topmover = " %9.2f `coef_lag3'
display "  -> Including market capitalization changes the estimated effect"
display "     from about " %9.0f `coef_lag' " (Model 1) to " %9.0f `coef_lag3' " (Model 3)."
display "Coefficient on mktcap = " %12.5f `coef_mktcap'
display "  -> Each extra $1 million of market capitalization is associated"
display "     with about " %5.1f `coef_mktcap'*1000 " more RH users per day."
display "95% confidence interval for lag_topmover = [" %9.2f `ci_lower3' ", " %9.2f `ci_upper3' "]"

************************************************************
* Economic meaning for Task 5(h)
************************************************************
display ""
display "*** ECONOMIC INTERPRETATION ***"

if `coef_lag3' > `coef_lag' {
    display "After controlling for firm size, the effect of being a top mover"
    display "becomes LARGER (" %9.2f `coef_lag3' " vs " %9.2f `coef_lag' ")."
    display "This indicates that top movers are on average SMALLER than typical firms."
    display "The univariate model therefore UNDERESTIMATED the true effect."
    display ""
    display "Correct multiple-choice statement:"
    display "  (i) The univariate model underestimates the effect of being a"
    display "      top mover on the change in RH users. This is because top"
    display "      movers are smaller than the average company. -> CORRECT"
}
else {
    display "After controlling for firm size, the effect of being a top mover"
    display "becomes SMALLER (" %9.2f `coef_lag3' " vs " %9.2f `coef_lag' ")."
    display "This indicates that top movers are on average LARGER than typical firms."
    display "The univariate model therefore OVERESTIMATED the true effect."
}

************************************************************
* Task 6 – Top Movers feature introduction (Aug 1, 2019)
************************************************************

* Define list = 1 on and after August 1, 2019, 0 otherwise
gen byte list = date >= mdy(8,1,2019)

display ""
display "*** DIFFERENCE-IN-DIFFERENCES MODEL ***"
display "Feature introduction: August 1, 2019"

* Estimate the model:
*    userchg = β0 + β1 lag_topmover + β2 list + β3 lag_topmover × list + β4 mktcap + ε
if `use_robust' == 1 {
    regress userchg lag_topmover list c.lag_topmover#c.list mktcap, robust
    display "Note: Using robust standard errors due to heteroskedasticity"
}
else {
    regress userchg lag_topmover list c.lag_topmover#c.list mktcap
    display "Note: Using standard OLS standard errors"
}

************************************************************
* Task 7 – Interpretation
************************************************************

display ""
display "*** COEFFICIENT INTERPRETATION ***"
display "β1 (lag_topmover)     = effect of being a lagged top mover BEFORE Aug 1, 2019"
display "β2 (list)             = shift in baseline user change AFTER Aug 1, 2019"
display "β3 (interaction)      = additional effect of being a lagged top mover AFTER Aug 1, 2019"
display "                       (i.e. the difference-in-differences effect)"
display "β4 (mktcap)           = effect of market capitalization on user change"
display ""
display "Statistical significance is judged by p-value, t-statistic, and"
display "95% confidence interval as in the previous regressions."

************************************************************
* Summary of heteroskedasticity testing approach
************************************************************

display ""
display "************************************************************"
display "* METHODOLOGY SUMMARY"
display "************************************************************"
display "Heteroskedasticity Testing Approach:"
display "1. Breusch-Pagan test: Tests for linear relationship between"
display "   squared residuals and fitted values"
display "2. White test: More general test allowing for nonlinear"
display "   relationships in heteroskedasticity"
display "3. Decision rule: Use robust standard errors if either test"
display "   rejects homoskedasticity at 5% significance level"
display "4. Panel structure: Could also consider clustering by ticker"
display "   to account for within-stock correlation over time"
display ""

if `use_robust' == 1 {
    display "CONCLUSION: Robust standard errors used throughout analysis"
    display "due to evidence of heteroskedasticity."
}
else {
    display "CONCLUSION: Standard OLS standard errors used as no strong"
    display "evidence of heteroskedasticity was found."
}
# Attention-Induced Trading Among Robinhood Investors

Empirical analysis of how Robinhood's "Top Movers" feature influences retail investor behavior using Stata.

## Overview

This repository contains code for analyzing attention-driven trading behavior among Robinhood users. The study examines whether stocks appearing on Robinhood's "Top Movers" list experience increased investor attention and trading activity using a difference-in-differences methodology around the feature's August 2019 launch.

## Dataset

* **Source** : Daily Robinhood user holdings (mid-2018 to mid-2020)
* **Size** : 86.4 MB

## Key Features

* 📊 Top mover identification based on daily absolute returns
* 📈 User acquisition pattern analysis
* 🔬 Difference-in-differences estimation
* 🎯 Controls for firm characteristics and market conditions

## Files

```
├── Assignment.do                          # Main Stata analysis script (11 KB)
├── empirical_finance_assignment.log       # Complete analysis output (22 KB)  
├── rh_daily.dta                          # Robinhood holdings dataset (86.4 MB)
└── README.md                             # This file
```

## Usage

1. **Prerequisites** : Stata software
2. **Setup** : Place all files in the same directory
3. **Run** : Execute `Assignment.do` in Stata
4. **Output** : Review `empirical_finance_assignment.log` for results

## Methodology

* Identifies daily top 20 stocks by absolute price movement
* Tracks user acquisition patterns following top mover status
* Uses feature introduction as natural experiment
* Employs regression analysis with proper controls

## Contributing

This is an academic assignment repository. For questions or suggestions, please open an issue.

## License

Academic use only.

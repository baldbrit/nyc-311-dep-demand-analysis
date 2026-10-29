# Project summary

## The problem

Call-center and customer-service managers must plan workload before actual demand is known. This project tested whether historical NYC 311 records could provide a useful daily forecast for telephone requests assigned to DEP.

## The approach

I filtered 2025 NYC 311 records to DEP requests received through the PHONE channel and aggregated the individual records into 365 daily totals. I used linear regression to forecast the final 73 days of the year from weekday and seasonal variables. I compared the model with a mean-based baseline. I also used k-means clustering to identify different types of demand days.

## What I found

The regression achieved an MAE of 53.73 and an RMSE of 135.44. It improved MAE by 27.4% compared with the baseline, although the modest R-squared and correlated residuals showed that important demand drivers were still missing. K-means identified weekend days, typical weekdays, and four extreme-volume weekdays.

## Recommendation

The regression can serve as an initial workload estimate, but it should not be treated as an exact staffing requirement. A future version should include multiple years, holidays, complaint categories, and weather information. Workforce-performance decisions would also require internal staffing and service-level data.

## Skills demonstrated

- Data filtering and aggregation
- Exploratory analysis
- Feature engineering
- Regression modeling and baseline comparison
- K-means clustering
- Model diagnostics
- Data visualization
- Translating technical results into an operational recommendation


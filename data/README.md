# Data source and preparation

## Official source

[NYC OpenData — 311 Service Requests from 2020 to Present](https://data.cityofnewyork.us/d/erm2-nwe9)

## Filters used

- `Created Date`: January 1 through December 31, 2025
- `Agency`: `DEP`
- `Open Data Channel Type`: `PHONE`

The filtered raw export contained **78,211 service-request records**. Those records were counted by calendar date to produce `nyc311_dep_phone_daily_2025.csv`.

## Included fields

| Field | Type | Description |
|---|---|---|
| `request_date` | Date-time text | Calendar date of the daily total |
| `requests` | Integer | Number of filtered service requests created on that date |

The file contains one row for each of the 365 dates in 2025. There are no customer names, telephone numbers, addresses, passwords, account information, or internal company records in this aggregate.

## Why the full raw file is not included

The raw NYC 311 dataset is large and changes as new records are added. Keeping the small daily aggregate makes the project easier to download and reproduce. Anyone who wants to review the source records can use the official dataset link and filters above.

## Important limitation

These are service requests assigned to DEP, not a complete record of every call handled by the NYC 311 contact center. The data can support analysis of recorded demand, but it cannot measure staffing effectiveness, handling time, wait time, service level, or abandonment.


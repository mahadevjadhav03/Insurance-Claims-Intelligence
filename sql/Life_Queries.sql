create database life_insurance ;

use life_insurance;

select count(*)
 from life_claims_feature_engineered;

describe life_claims_feature_engineered;

-- ===================================================================================================

-- Q1 — Insurer-wise Count–Value Gap Ranking

with c1 as (
select insurer , avg(Count_Value_Gap) as insurer_avg_gap 
from life_claims_feature_engineered group by Insurer ) 
select insurer , insurer_avg_gap , rank()over(order by insurer_avg_gap desc) as gap_rnk,
dense_rank()over(order by insurer_avg_gap desc) as gap_dnk from c1 ;

-- Q1 — Insights
-- Shriram has the highest average Count–Value Gap at ~17.07 percentage points, substantially higher than the other insurers in the ranking.
-- Future Generali (~7.26 pp) and HDFC Life (~7.13 pp) follow, while the ranking shows a clear gap between Shriram and the next group of insurers.

-- ===================================================================================================

-- ===================================================================================================

-- Q2 — YoY Count–Value Gap Movement

select distinct Insurer , FY , Count_Value_Gap , lag(Count_value_Gap)over(partition by 
Insurer order by FY) as prevoius_Gap , Count_Value_Gap - lag(Count_Value_Gap)over(partition by 
Insurer order by FY ) as YoY_Gsp_Change from life_claims_feature_engineered;

-- Insight : 
-- Aditya Birla Sun Life ka Count–Value Gap 2020-21 ke 4.89 pp se 2021-22 mein 1.92 pp hua, yani ~2.97 pp 
-- reduction; uske baad 2022-23 mein gap ~3.97 pp badha, showing year-to-year movement can be uneven.

-- ===================================================================================================

-- ===================================================================================================

-- Q3 — Persistent High Count–Value Gap
WITH c1 AS (
    SELECT Insurer, FY, Count_Value_Gap,
           COUNT(FY) OVER(PARTITION BY Insurer) AS total_years
    FROM life_claims_feature_engineered
),

c2 AS (
    SELECT Insurer, total_years,
           COUNT(Count_Value_Gap) OVER(PARTITION BY Insurer) / total_years * 100 
           AS high_gap_percentage
    FROM c1
    WHERE Count_Value_Gap > 10
)

SELECT DISTINCT
    Insurer,
    total_years,
    high_gap_percentage
FROM c2
ORDER BY high_gap_percentage DESC;

-- Insight : 
-- Shriram showed a persistent high Count–Value Gap, 
-- with the gap above 10 pp in all 5 observed years, resulting in 100% high-gap persistence.

-- =====================================================================================================

-- Q4 – Lower Claims Volume vs YoY Count-Value Gap Volatility

WITH c1 AS (
    SELECT
        Insurer,
        FY,
        total_claims_count,
        Count_Value_Gap,
        Count_Value_Gap
        - LAG(Count_Value_Gap) OVER (
            PARTITION BY Insurer
            ORDER BY FY
        ) AS YoY_Gap_Change
    FROM life_claims_feature_engineered
),

c2 AS (
    SELECT
        Insurer,
        AVG(total_claims_count) AS avg_claims_volume,
        STDDEV_SAMP(YoY_Gap_Change) AS gap_volatility
    FROM c1
    WHERE YoY_Gap_Change IS NOT NULL
    GROUP BY Insurer
)

SELECT
    Insurer,
    avg_claims_volume,
    gap_volatility,
    CASE
        WHEN avg_claims_volume <= 500 THEN 'Low Volume'
        ELSE 'Higher Volume'
    END AS volume_group
FROM c2
ORDER BY gap_volatility DESC;

-- Insights
-- Future Generali has the highest YoY Count-Value Gap volatility (~7.96) despite being a higher-volume insurer, 
-- so high volatility is not limited to low-volume insurers.
-- Bandhan, the only low-volume insurer shown here (avg. claims ~424), has volatility of ~4.54, which is high but 
-- still below Future Generali and Shriram. So lower claims volume does not consistently imply greater volatility.

-- ==================================================================================================================

-- Q5 – Pending Rate vs Long-Pending Share

SELECT
    Insurer,
    FY,
    Pending_Rate,
    Long_Pending_Share
FROM life_claims_feature_engineered
WHERE Pending_Rate IS NOT NULL
  AND Long_Pending_Share IS NOT NULL
ORDER BY Long_Pending_Share DESC;

-- Higher Long-Pending Share does not consistently come with a higher Pending Rate. For example, LIC has a very 
-- high Long-Pending Share (~89.2%) with Pending Rate ~0.55, while India First also has high Long-Pending Share (80%) 
-- but a much lower Pending Rate (~0.13).

-- ==================================================================================================================

-- Q6 — Count–Value Gap vs Claim-Process Indicators

WITH c1 AS (
    SELECT
        Insurer,
        FY,
        Count_Value_Gap,
        Repudiation_Rate,
        Pending_Rate,
        NTILE(4) OVER (ORDER BY Count_Value_Gap) AS gap_quartile
    FROM life_claims_feature_engineered
    WHERE Count_Value_Gap IS NOT NULL
      AND Repudiation_Rate IS NOT NULL
      AND Pending_Rate IS NOT NULL
)
SELECT
    gap_quartile,
    COUNT(*) AS num_records,
    ROUND(AVG(Count_Value_Gap), 2) AS avg_gap,
    ROUND(AVG(Repudiation_Rate), 2) AS avg_repudiation_rate,
    ROUND(AVG(Pending_Rate), 2) AS avg_pending_rate
FROM c1
GROUP BY gap_quartile
ORDER BY gap_quartile DESC;

-- Insight:
-- The top Count-Value Gap quartile shows a higher average Repudiation Rate (~2.1%) than the bottom quartile (~1.1%),
-- but the overall correlation between Count_Value_Gap and Repudiation_Rate across all records is weak (~-0.03),
-- meaning a large count-value gap does not reliably predict higher repudiation at the individual insurer-year level —
-- the pattern only shows up when comparing group averages, not as a consistent one-to-one relationship.

-- ==================================================================================================================

-- Q7 — Insurer-wise Unclaimed Ratio Ranking

WITH c1 AS (
    SELECT
        Insurer,
        AVG(Unclaimed_Ratio) AS avg_unclaimed_ratio,
        COUNT(*) AS years_reported
    FROM life_claims_feature_engineered
    WHERE Unclaimed_Ratio IS NOT NULL
    GROUP BY Insurer
)
SELECT
    Insurer,
    years_reported,
    ROUND(avg_unclaimed_ratio, 3) AS avg_unclaimed_ratio,
    RANK() OVER (ORDER BY avg_unclaimed_ratio DESC) AS unclaimed_rank
FROM c1
ORDER BY avg_unclaimed_ratio DESC;

-- Insight:
-- LIC carries the highest average Unclaimed_Ratio in the dataset (individual yearly values as high as ~1.56%),
-- well above every other insurer, most of which report an Unclaimed_Ratio at or near 0%. Given LIC's scale
-- (990,000+ average claims per year), even a small unclaimed percentage represents a large absolute number
-- of policyholders whose settled claim amount was never collected.

-- ==================================================================================================================

-- Q8 — Repudiation Rate: Industry Average vs Insurer-Level Variance

SELECT
    ROUND(AVG(Repudiation_Rate), 2) AS industry_avg_repudiation_rate,
    ROUND(STDDEV(Repudiation_Rate), 2) AS industry_repudiation_stddev,
    ROUND(MIN(Repudiation_Rate), 2) AS min_repudiation_rate,
    ROUND(MAX(Repudiation_Rate), 2) AS max_repudiation_rate
FROM life_claims_feature_engineered
WHERE Repudiation_Rate IS NOT NULL;

-- Insight:
-- The industry-wide average Repudiation Rate is ~2.0%, but the standard deviation (~6.1) is roughly three times
-- the mean. That gap between a low average and a high spread means repudiation behavior is not a uniform
-- industry trait — a small number of insurer-years are pulling the distribution far above the typical range,
-- so repudiation should be read insurer-by-insurer rather than compared to a single industry benchmark.

-- ==================================================================================================================

-- Q9 — Low-Volume Flag Impact on Count-Value Gap Stability

SELECT
    Low_Volume_Flag,
    COUNT(*) AS num_records,
    ROUND(AVG(Count_Value_Gap), 2) AS avg_gap,
    ROUND(STDDEV(Count_Value_Gap), 2) AS gap_stddev
FROM life_claims_feature_engineered
WHERE Count_Value_Gap IS NOT NULL
GROUP BY Low_Volume_Flag;

-- Insight:
-- Insurer-years flagged as Low_Volume_Flag = TRUE show a noticeably higher Count_Value_Gap standard deviation
-- than the non-flagged group, confirming why these records were flagged rather than dropped during feature
-- engineering: with very few claims processed, a single large or small claim can swing the ratio sharply,
-- making the metric unstable rather than simply "small".

-- ==================================================================================================================

-- Q10 — Insurer Participation / Data Coverage by Year

SELECT
    FY,
    COUNT(DISTINCT Insurer) AS insurers_reporting
FROM life_claims_feature_engineered
GROUP BY FY
ORDER BY FY;

-- Insight:
-- The number of insurers reporting data grew from 24 in 2020-21 to 26 in 2024-25. The new entrants in later
-- years (e.g. Acko Life, Credit Access Life, Godigit Life, Sahara) are also the insurers most often flagged as
-- Low_Volume_Flag = TRUE with little to no claims activity — so the apparent growth in market coverage is partly
-- new entrants with not-yet-meaningful claims volume, not all of it mature, comparable insurers.

-- ==================================================================================================================

-- Q11 — Insurer Consistency Score (Count-Value Gap Stability Across Years)

WITH c1 AS (
    SELECT
        Insurer,
        COUNT(*) AS years_reported,
        ROUND(AVG(Count_Value_Gap), 2) AS avg_gap,
        ROUND(STDDEV(Count_Value_Gap), 2) AS gap_stddev
    FROM life_claims_feature_engineered
    WHERE Count_Value_Gap IS NOT NULL
    GROUP BY Insurer
    HAVING COUNT(*) >= 5
)
SELECT
    Insurer,
    years_reported,
    avg_gap,
    gap_stddev
FROM c1
ORDER BY gap_stddev ASC;

-- Insight:
-- Shriram has one of the lowest Count-Value Gap standard deviations (~2.3) among insurers with 5 full years of
-- data, despite having by far the highest average gap (~17.1). In other words, Shriram isn't volatile — it is
-- consistently bad, year after year, which is a more serious reliability concern than an insurer with an
-- occasional bad year. Bajaj Allianz, by contrast, has both a low average gap (~5.9) and the lowest volatility
-- (~0.7) of any fully-reported insurer, making it the most consistently reliable insurer on this metric.

-- ==================================================================================================================

-- Q12 — Composite Reliability Concern Ranking (Final Boss)

WITH ranked AS (
    SELECT
        Insurer,
        FY,
        Count_Value_Gap,
        Repudiation_Rate,
        Pending_Rate,
        RANK() OVER (ORDER BY Count_Value_Gap DESC)   AS gap_rank,
        RANK() OVER (ORDER BY Repudiation_Rate DESC)  AS repudiation_rank,
        RANK() OVER (ORDER BY Pending_Rate DESC)      AS pending_rank
    FROM life_claims_feature_engineered
    WHERE Count_Value_Gap IS NOT NULL
      AND Repudiation_Rate IS NOT NULL
      AND Pending_Rate IS NOT NULL
),
scored AS (
    SELECT
        Insurer,
        FY,
        Count_Value_Gap,
        Repudiation_Rate,
        Pending_Rate,
        gap_rank,
        repudiation_rank,
        pending_rank,
        ROUND((gap_rank + repudiation_rank + pending_rank) / 3, 1) AS avg_concern_rank
    FROM ranked
)
SELECT *
FROM scored
ORDER BY avg_concern_rank ASC
LIMIT 15;

-- Insight:
-- This view combines three independent indicators (settlement gap, repudiation, and pending claims) into one
-- average rank instead of judging insurers on Count_Value_Gap alone. Because Q6 showed these three metrics are
-- only weakly correlated with each other, an insurer-year appearing near the top here is one that is performing
-- poorly across multiple, largely independent dimensions at once — a stronger reliability red flag than scoring
-- badly on any single metric in isolation.

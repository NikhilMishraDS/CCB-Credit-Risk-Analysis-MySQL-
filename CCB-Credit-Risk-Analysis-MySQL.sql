USE ccb_credit_risk;

-- 1. Show every column name and data type
DESCRIBE uci_credit_card;

-- 2. Row count (should be 30000)
SELECT COUNT(*) AS total_rows FROM uci_credit_card;

-- 3. Peek at the first 5 rows
SELECT * FROM uci_credit_card LIMIT 5; 


USE ccb_credit_risk;

DROP TABLE IF EXISTS uci_credit_card;

CREATE TABLE uci_credit_card (
  `ID`        INT PRIMARY KEY,
  `LIMIT_BAL` INT,
  `SEX`       TINYINT,
  `EDUCATION` TINYINT,
  `MARRIAGE`  TINYINT,
  `AGE`       TINYINT,
  `PAY_0` TINYINT, `PAY_2` TINYINT, `PAY_3` TINYINT,
  `PAY_4` TINYINT, `PAY_5` TINYINT, `PAY_6` TINYINT,
  `BILL_AMT1` INT, `BILL_AMT2` INT, `BILL_AMT3` INT,
  `BILL_AMT4` INT, `BILL_AMT5` INT, `BILL_AMT6` INT,
  `PAY_AMT1` INT, `PAY_AMT2` INT, `PAY_AMT3` INT,
  `PAY_AMT4` INT, `PAY_AMT5` INT, `PAY_AMT6` INT,
  `default.payment.next.month` TINYINT
); 


USE ccb_credit_risk;

SELECT COUNT(*) AS total_rows,
       MIN(AGE) AS min_age, MAX(AGE) AS max_age,
       MIN(PAY_0) AS min_pay0, MAX(PAY_0) AS max_pay0,
       SUM(`default.payment.next.month`) AS total_defaults
FROM uci_credit_card; 



-- Building the Clean Data Analysis Table : 

USE ccb_credit_risk;

DROP TABLE IF EXISTS credit_clean;

CREATE TABLE credit_clean AS
SELECT
  ID                                              AS customer_id,
  LIMIT_BAL                                       AS credit_limit,
  CASE SEX WHEN 1 THEN 'Male' WHEN 2 THEN 'Female' END AS sex,
  CASE WHEN EDUCATION = 1 THEN 'Graduate school'
       WHEN EDUCATION = 2 THEN 'University'
       WHEN EDUCATION = 3 THEN 'High school'
       ELSE 'Others/Unknown' END                  AS education,
  CASE MARRIAGE WHEN 1 THEN 'Married'
                WHEN 2 THEN 'Single'
                ELSE 'Other' END                  AS marital_status,
  AGE                                             AS age,
  CASE WHEN AGE < 25 THEN '1. Under 25'
       WHEN AGE < 35 THEN '2. 25-34'
       WHEN AGE < 45 THEN '3. 35-44'
       WHEN AGE < 55 THEN '4. 45-54'
       ELSE '5. 55+' END                          AS age_group,
  CASE WHEN LIMIT_BAL < 50000  THEN '1. Under 50k'
       WHEN LIMIT_BAL < 100000 THEN '2. 50k-100k'
       WHEN LIMIT_BAL < 200000 THEN '3. 100k-200k'
       WHEN LIMIT_BAL < 400000 THEN '4. 200k-400k'
       ELSE '5. 400k+' END                        AS limit_band,
  PAY_0 AS pay_sep, PAY_2 AS pay_aug, PAY_3 AS pay_jul,
  PAY_4 AS pay_jun, PAY_5 AS pay_may, PAY_6 AS pay_apr,
  BILL_AMT1 AS bill_sep, BILL_AMT2 AS bill_aug, BILL_AMT3 AS bill_jul,
  BILL_AMT4 AS bill_jun, BILL_AMT5 AS bill_may, BILL_AMT6 AS bill_apr,
  PAY_AMT1 AS paid_sep, PAY_AMT2 AS paid_aug, PAY_AMT3 AS paid_jul,
  PAY_AMT4 AS paid_jun, PAY_AMT5 AS paid_may, PAY_AMT6 AS paid_apr,
  `default.payment.next.month`                    AS is_default,
  GREATEST(PAY_0,PAY_2,PAY_3,PAY_4,PAY_5,PAY_6)   AS max_delay_6m,
  (PAY_0>0)+(PAY_2>0)+(PAY_3>0)+(PAY_4>0)+(PAY_5>0)+(PAY_6>0) AS months_delinquent_6m,
  ROUND(GREATEST(BILL_AMT1,0) / LIMIT_BAL, 4)     AS utilization_sep,
  ROUND((GREATEST(BILL_AMT1,0)+GREATEST(BILL_AMT2,0)+GREATEST(BILL_AMT3,0)+
         GREATEST(BILL_AMT4,0)+GREATEST(BILL_AMT5,0)+GREATEST(BILL_AMT6,0)) / 6 / LIMIT_BAL, 4) AS avg_utilization_6m,
  (BILL_AMT1 > LIMIT_BAL)                         AS over_limit,
  GREATEST(BILL_AMT1, 0)                          AS ead
FROM uci_credit_card;

ALTER TABLE credit_clean ADD PRIMARY KEY (customer_id);
CREATE INDEX idx_default ON credit_clean (is_default);
CREATE INDEX idx_pay_sep ON credit_clean (pay_sep);

-- Result 1: reconciliation (raw vs clean must match)
SELECT (SELECT COUNT(*) FROM uci_credit_card)          AS raw_rows,
       (SELECT COUNT(*) FROM credit_clean)             AS clean_rows,
       (SELECT SUM(LIMIT_BAL) FROM uci_credit_card)    AS raw_total_limit,
       (SELECT SUM(credit_limit) FROM credit_clean)    AS clean_total_limit,
       (SELECT SUM(`default.payment.next.month`) FROM uci_credit_card) AS raw_defaults,
       (SELECT SUM(is_default) FROM credit_clean)      AS clean_defaults;

-- Result 2: preview of the clean table
SELECT customer_id, credit_limit, sex, education, marital_status, age_group, limit_band,
       pay_sep, max_delay_6m, months_delinquent_6m, utilization_sep, avg_utilization_6m,
       over_limit, ead, is_default
FROM credit_clean LIMIT 5; 



-- Portfolio and Delinquency Analysis : 

USE ccb_credit_risk;

-- Q1. Portfolio snapshot
SELECT COUNT(*)                                AS customers,
       ROUND(SUM(credit_limit)/1000000,1)      AS total_limit_m,
       ROUND(SUM(ead)/1000000,1)               AS total_balance_m,
       ROUND(100*SUM(ead)/SUM(credit_limit),1) AS portfolio_utilization_pct,
       SUM(is_default)                         AS defaulters,
       ROUND(100*AVG(is_default),2)            AS default_rate_pct
FROM credit_clean;

-- Q2. Default rate by latest repayment status
SELECT CASE pay_sep WHEN -2 THEN '0. No consumption'
                    WHEN -1 THEN '1. Paid in full'
                    WHEN  0 THEN '2. Revolving (min. pay)'
                    WHEN  1 THEN '3. 1 month late'
                    WHEN  2 THEN '4. 2 months late'
                    ELSE        '5. 3+ months late' END AS repayment_status,
       COUNT(*)                                    AS customers,
       ROUND(100*COUNT(*)/SUM(COUNT(*)) OVER (),1) AS pct_of_customers,
       SUM(is_default)                             AS defaulters,
       ROUND(100*AVG(is_default),2)                AS default_rate_pct
FROM credit_clean
GROUP BY repayment_status
ORDER BY repayment_status;

-- Q3. Persistence: months late in the last 6 vs default rate
SELECT months_delinquent_6m,
       COUNT(*)                     AS customers,
       SUM(is_default)              AS defaulters,
       ROUND(100*AVG(is_default),2) AS default_rate_pct
FROM credit_clean
GROUP BY months_delinquent_6m
ORDER BY months_delinquent_6m; 


-- Segment Analysis : 

USE ccb_credit_risk;

-- Q4. Default rate by credit limit band
SELECT limit_band,
       COUNT(*)                          AS customers,
       ROUND(SUM(ead)/1000000,1)         AS balance_m,
       SUM(is_default)                   AS defaulters,
       ROUND(100*AVG(is_default),2)      AS default_rate_pct,
       ROUND(100*AVG(utilization_sep),1) AS avg_utilization_pct
FROM credit_clean
GROUP BY limit_band
ORDER BY limit_band;

-- Q5. Default rate by 6-month average utilization
SELECT CASE WHEN avg_utilization_6m < 0.10 THEN '1. Under 10%'
            WHEN avg_utilization_6m < 0.30 THEN '2. 10-30%'
            WHEN avg_utilization_6m < 0.60 THEN '3. 30-60%'
            WHEN avg_utilization_6m < 0.90 THEN '4. 60-90%'
            ELSE '5. 90%+' END           AS utilization_band,
       COUNT(*)                          AS customers,
       SUM(is_default)                   AS defaulters,
       ROUND(100*AVG(is_default),2)      AS default_rate_pct
FROM credit_clean
GROUP BY utilization_band
ORDER BY utilization_band;

-- Q6. Default rate by payment behaviour (September payment vs August bill)
SELECT CASE WHEN bill_aug <= 0 THEN '0. No balance last month'
            WHEN paid_sep = 0 THEN '1. Paid nothing'
            WHEN paid_sep < 0.10 * bill_aug THEN '2. Paid under 10%'
            WHEN paid_sep < bill_aug THEN '3. Paid 10-99%'
            ELSE '4. Paid in full' END   AS payment_behaviour,
       COUNT(*)                          AS customers,
       SUM(is_default)                   AS defaulters,
       ROUND(100*AVG(is_default),2)      AS default_rate_pct
FROM credit_clean
GROUP BY payment_behaviour
ORDER BY payment_behaviour;

-- Q7. Over-limit customers vs within limit
SELECT CASE WHEN over_limit = 1 THEN 'Over limit' ELSE 'Within limit' END AS limit_status,
       COUNT(*)                          AS customers,
       SUM(is_default)                   AS defaulters,
       ROUND(100*AVG(is_default),2)      AS default_rate_pct
FROM credit_clean
GROUP BY over_limit
ORDER BY over_limit; 



-- Expected Loss and Risk : 

USE ccb_credit_risk;

-- Q8. Expected Loss = PD x LGD x EAD by credit limit band
-- LGD (loss given default) is an ASSUMPTION: 75% for unsecured card debt.
SET @lgd = 0.75;

SELECT limit_band,
       ROUND(AVG(is_default),4)                          AS pd,
       ROUND(@lgd,2)                                     AS lgd_assumed,
       ROUND(SUM(ead)/1000000,2)                         AS ead_m,
       ROUND(AVG(is_default)*@lgd*SUM(ead)/1000000,2)    AS expected_loss_m,
       ROUND(100*AVG(is_default)*@lgd,2)                 AS loss_rate_pct
FROM credit_clean
GROUP BY limit_band
UNION ALL
SELECT 'TOTAL PORTFOLIO',
       ROUND(AVG(is_default),4), ROUND(@lgd,2),
       ROUND(SUM(ead)/1000000,2),
       ROUND(AVG(is_default)*@lgd*SUM(ead)/1000000,2),
       ROUND(100*AVG(is_default)*@lgd,2)
FROM credit_clean
ORDER BY limit_band;

-- Q9. Build a rule-based risk score (points) as a reusable view
CREATE OR REPLACE VIEW v_scored AS
SELECT *,
  ( CASE WHEN pay_sep >= 2 THEN 40 WHEN pay_sep = 1 THEN 20 ELSE 0 END
  + CASE WHEN months_delinquent_6m >= 3 THEN 25 WHEN months_delinquent_6m >= 1 THEN 10 ELSE 0 END
  + CASE WHEN avg_utilization_6m >= 0.9 THEN 15 WHEN avg_utilization_6m >= 0.6 THEN 8 ELSE 0 END
  + CASE WHEN paid_sep = 0 AND bill_aug > 0 THEN 10 ELSE 0 END
  + CASE WHEN credit_limit < 50000 THEN 10 ELSE 0 END ) AS risk_score
FROM credit_clean;

-- Q9b. Do the risk tiers separate good and bad customers?
SELECT CASE WHEN risk_score >= 60 THEN 'E. Very High'
            WHEN risk_score >= 40 THEN 'D. High'
            WHEN risk_score >= 20 THEN 'C. Medium'
            WHEN risk_score >= 10 THEN 'B. Low'
            ELSE 'A. Very Low' END         AS risk_tier,
       COUNT(*)                            AS customers,
       SUM(is_default)                     AS defaulters,
       ROUND(100*AVG(is_default),2)        AS default_rate_pct
FROM v_scored
GROUP BY risk_tier
ORDER BY risk_tier;

-- Q10. Gains table: how many defaults sit in the riskiest customers?
WITH ranked AS (
  SELECT is_default,
         NTILE(10) OVER (ORDER BY risk_score DESC, customer_id) AS decile
  FROM v_scored)
SELECT decile,
       COUNT(*)                         AS customers,
       SUM(is_default)                  AS defaulters,
       ROUND(100*AVG(is_default),2)     AS default_rate_pct,
       ROUND(100*SUM(SUM(is_default)) OVER (ORDER BY decile)
             / SUM(SUM(is_default)) OVER (),1) AS cumulative_pct_of_defaults_captured
FROM ranked
GROUP BY decile
ORDER BY decile; 



-- Policy Implications and Final Checks : 

USE ccb_credit_risk;

-- Q11. Policy simulation: flag customers at or above a score cutoff
-- (action could be a limit freeze, early collections call or manual review)
SET @lgd = 0.75;

SELECT cutoff,
       SUM(risk_score >= cutoff)                                  AS customers_flagged,
       ROUND(100*SUM(risk_score >= cutoff)/COUNT(*),1)            AS pct_of_portfolio_flagged,
       SUM(is_default = 1 AND risk_score >= cutoff)               AS defaulters_caught,
       ROUND(100*SUM(is_default = 1 AND risk_score >= cutoff)/SUM(is_default),1) AS pct_of_defaults_caught,
       ROUND(100*SUM(is_default = 1 AND risk_score >= cutoff)/SUM(risk_score >= cutoff),1) AS default_rate_of_flagged_pct,
       SUM(is_default = 0 AND risk_score >= cutoff)               AS good_customers_flagged,
       ROUND(SUM(CASE WHEN is_default = 1 AND risk_score >= cutoff THEN ead*@lgd END)/1000000,1) AS loss_addressed_m
FROM v_scored
CROSS JOIN (SELECT 20 AS cutoff UNION SELECT 30 UNION SELECT 40 UNION SELECT 50 UNION SELECT 60) c
GROUP BY cutoff
ORDER BY cutoff;

-- Q12. Final reconciliation checks (report validation)
SELECT 'Row count: raw vs clean (expect 0)' AS check_name,
       (SELECT COUNT(*) FROM uci_credit_card) - (SELECT COUNT(*) FROM credit_clean) AS result
UNION ALL SELECT 'Total limit: raw vs clean (expect 0)',
       (SELECT SUM(LIMIT_BAL) FROM uci_credit_card) - (SELECT SUM(credit_limit) FROM credit_clean)
UNION ALL SELECT 'Defaults: raw vs clean (expect 0)',
       (SELECT SUM(`default.payment.next.month`) FROM uci_credit_card) - (SELECT SUM(is_default) FROM credit_clean)
UNION ALL SELECT 'Customers across limit bands vs total (expect 0)',
       (SELECT COUNT(*) FROM credit_clean) - (SELECT SUM(c) FROM (SELECT COUNT(*) c FROM credit_clean GROUP BY limit_band) x)
UNION ALL SELECT 'Customers across risk tiers vs total (expect 0)',
       (SELECT COUNT(*) FROM v_scored) - (SELECT SUM(c) FROM (SELECT COUNT(*) c FROM v_scored GROUP BY CASE WHEN risk_score>=60 THEN 5 WHEN risk_score>=40 THEN 4 WHEN risk_score>=20 THEN 3 WHEN risk_score>=10 THEN 2 ELSE 1 END) y)
UNION ALL SELECT 'Null key fields in clean table (expect 0)',
       (SELECT COUNT(*) FROM credit_clean WHERE credit_limit IS NULL OR is_default IS NULL OR sex IS NULL OR pay_sep IS NULL)
UNION ALL SELECT 'Default rate recomputed (22.12 expected)',
       (SELECT ROUND(100*SUM(is_default)/COUNT(*),2) FROM credit_clean); 
       
       
       
/* 
   CONCLUSION: Credit Card Risk Strategy Analytics
   Dataset: UCI Credit Card Default (30,000 customers) | Tool: MySQL 8.0
   

   OVERVIEW
   The portfolio holds about 5,024.5M in credit limits and 1,537.4M in
   balances (30.6% utilization). 6,636 customers defaulted, a baseline
   default rate of 22.12%.

   DATA QUALITY
   No duplicates, missing key values or invalid ages, limits or targets.
   345 education records and 54 marriage records had undefined codes and
   were grouped into Others/Unknown and Other. 590 customers had negative
   bills (kept, exposure floored at zero) and 2,115 were over their limit
   (flagged). The clean table matched the raw table on rows, total limits
   and defaults, and all reconciliation checks passed.

   KEY FINDINGS
   1. Recent payment behaviour is the strongest warning sign. Default rate
      is 12.81% for revolving customers, 33.95% for 1 month late and
      69.14% for 2 months late. Customers late in all 6 months default
      at 70.32%, versus 11.71% for customers never late.
   2. Customers who paid nothing last month default at 52.52%, versus
      13.89% for those who paid in full.
   3. Default falls as credit limit rises: 36.07% under 50k down to
      11.95% above 400k.
   4. Default rises with utilization: 15.55% at 10-30% up to 32.61% at
      90% and above. Over-limit customers default at 30.07% versus
      21.52% within limit.

   EXPECTED LOSS (PD x LGD x EAD, LGD assumed 75%)
   Under 50k: 17.71M | 50k-100k: 51.91M | 100k-200k: 63.97M
   200k-400k: 70.46M | 400k+: 18.17M
   Portfolio total (sum of bands): about 222.2M, a loss rate of roughly
   14.5% on balances.

   RISK SCORE
   Default rate by tier: Very Low 
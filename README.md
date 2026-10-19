# CCB-Credit-Risk-Analysis-MySQL-
This is a SQL project I did on credit card default data. I wanted to practice the kind of work a consumer banking risk team does: check the data, find what drives default, estimate losses, and test a simple rule for flagging risky customers.
Data

UCI Credit Card Default dataset: 30,000 credit card customers from Taiwan, with data from April to September 2005. Each row has the credit limit, some customer details, six months of repayment status, bill amounts, payment amounts, and whether the customer defaulted the next month.

Source: https://archive.ics.uci.edu/dataset/350/default+of+credit+card+clients

The CSV is not included in this repo. Download it from the link above.

What I did
Checked the data quality (duplicates, missing values, odd category codes, negative bills)
Built a clean table with readable labels and a few new fields (utilization, months delinquent, exposure)
Looked at default rates by repayment status, credit limit, utilization and payment behaviour
Estimated expected loss using PD x LGD x EAD
Built a simple points-based risk score and checked how well it ranks customers
Tested a few score cutoffs to see how many customers would be flagged and how many defaults they would catch
Ran reconciliation checks to make sure the clean table matches the raw table
Main results
30,000 customers, 6,636 defaults, so the default rate is 22.12%
Total credit limits are about 5,024.5M and balances are about 1,537.4M (30.6% utilization)
Repayment status was the strongest signal. Customers who were revolving normally defaulted at 12.81%, one month late at 33.95%, and two months late at 69.14%
Customers who paid nothing last month defaulted at 52.52%, compared with 13.89% for those who paid in full
Default rate went down as the credit limit went up: 36.07% for limits under 50k and 11.95% for limits over 400k
Default rate went up with utilization: 15.55% at 10-30% and 32.61% at 90% or more
Expected loss was about 222.2M in total (sum of the five limit bands), roughly 14.5% of balances
Default rate by risk tier went from 10.77% (very low) to 67.09% (very high)
The riskiest 10% of customers held 30.4% of all defaults, and the riskiest 30% held 61.4%
Score cutoff test
Cutoff	Customers flagged	Defaults caught	Good customers flagged
20	8,797 (29.3%)	60.7%	4,768
40	5,229 (17.4%)	46.4%	2,151
60	3,057 (10.2%)	30.9%	1,006

I would pick a cutoff of 40. Compared with 20 it flags 3,568 fewer customers and gives up only a small amount of the loss that gets addressed (132.2M vs 144.1M). The flagged action should be light, like an early collections call or a manual review, because some flagged customers would not have defaulted anyway.

Limitations
The 75% loss given default is my assumption for unsecured card debt. It is not in the data, so the loss numbers change if it changes.
I picked the score weights by hand after looking at the patterns, and tested them on the same data. A real model would need to be checked on new data.
The data is old and from one country, so the numbers should not be treated as current.
Sex, marital status and age are not used in the score because they are protected characteristics in lending.
"Paid in full" customers default slightly more than "revolving" customers in this dataset. I did not dig into why.

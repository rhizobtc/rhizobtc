
-- First I cleaned up to relevent data by dropping address and cleaning date and account types.

CREATE TABLE celsius_clean as 

SELECT Column1
, USERNAME as username
, Case 
	WHEN DATE = '4/14/2022 - 7/13/2022' THEN NULL
	ELSE DATE
END as date
, CASE 
	WHEN ACCOUNT = 'Earn - Interest; Earn, Custody or Withheld - Rewards' THEN 'pending_rewards'
	ELSE ACCOUNT
END as account
, TYPE as type 
, Descriptive_Purpose
, COIN as asset
, COIN_QUANTITY as amount
, COIN_USD as value
FROM celsius c 

-- quick check
SELECT * FROM celsius_clean cc 

-- Understanding users
SELECT username, Descriptive_Purpose, SUM(value)
FROM celsius_clean cc WHERE username = 'MARK BERGER' GROUP BY Descriptive_Purpose, username  

-- top value for withdrawls and deposits. used to determine type later.
CREATE TABLE customer_value as 

WITH filter as (SELECT username 
	, CASE 
		WHEN Descriptive_Purpose  = 'Internal Account Transfer' THEN SUM(value)
		WHEN Descriptive_Purpose  = 'Deposit' THEN SUM(value)
		WHEN Descriptive_Purpose  = 'Withdrawal' THEN SUM(value)
	END as value
	FROM celsius_clean cc 
	GROUP BY Descriptive_purpose, username
	ORDER BY username )

SELECT username,
MAX(value) OVER(PARTITION BY username ORDER BY username) as max_value,
ROW_NUMBER() OVER(PARTITION BY username ORDER BY value) as number
FROM filter


-- So basically 'Deposit' covers all USD deposited after the withdrawl date date '
-- need to adjust for user with funds in celsius before this date. 
		
-- Finding the withdrawl amount by type and day		
-- Problem Im running into:
-- 'Balence withdrawan' has many millionares who only withdrew only within the time window. Fix in customer type 

-- finding the count of withdrawls per day in each cutomer type
-- Counts_bydate_bytype

WITH type as (
	SELECT username
	, CASE WHEN max_value <1000 THEN '0-1K' 
		WHEN max_value <10000 THEN '1K-10K' 
		WHEN max_value <100000 THEN '10K-100K' 
		WHEN max_value <1000000 THEN '100K-1M' 
	ELSE 'Millionaire' END as customer_type
	FROM customer_value cv
	WHERE number = 1
),

	counts as (
	SELECT date
		, username, sum(value) as value
	-- 	, SUM(value) as value
	FROM celsius_clean cc 
	WHERE Descriptive_Purpose  = 'Withdrawal'
	GROUP BY date, username 
	ORDER BY date 
)


SELECT c.date
	, t.customer_type
	, COUNT(c.username) as total_count
	, SUM(c.value) as total_value
FROM counts c 
LEFT JOIN type t ON t.username = c.username
WHERE customer_type IS NOT NULL
GROUP BY c.date, t.customer_type
Order by date


-- Lets look at users with balence still on the exchange
-- Balence on exchange
-- this assums that users with excess withdrawls were able to claim ALL their assets. I know its a big one

CREATE TABLE remaining_balences as 

WITH balences as (WITH type as (
					SELECT username
						, CASE WHEN max_value <1000 THEN '0-1K' 
							WHEN max_value <10000 THEN '1K-10K' 
							WHEN max_value <100000 THEN '10K-100K' 
							WHEN max_value <1000000 THEN '100K-1M' 
					ELSE 'Millionaire' END as customer_type
					FROM customer_value cv
					WHERE number = 1 
		),
		deposits as (
					
					SELECT username, SUM(value) as value 
					FROM celsius_clean cc 
					WHERE Descriptive_Purpose  = 'Deposit' 
					GROUP BY username
				),
				
		interest_rewards as (
					
					SELECT username, SUM(value) as value 
					FROM celsius_clean cc 
					WHERE Descriptive_Purpose  = 'Interest and Rewards' 
					GROUP BY username		
				),
				
		withdrawals as (
					
				 	SELECT username, SUM(value) as value
					FROM celsius_clean cc 
					WHERE Descriptive_Purpose  = 'Withdrawal' 
					GROUP BY username 
				) 
				
		SELECT w.username
			, IFNULL(d.value,0) as total_deposit
			, IFNULL(ir.value,0) as total_rewards
			, IFNULL(w.value,0) as total_withdrawal
			, t.customer_type
		FROM withdrawals w 
		LEFT JOIN deposits d ON d.username = w.username
		LEFT JOIN type t ON w.username = t.username
		LEFT JOIN interest_rewards ir ON w.username = ir.username
			
)

SELECT username
	, Case 
		when total_deposit - total_withdrawal < 0 THEN total_deposit + total_withdrawal
		ELSE total_deposit
	END as total_deposits
	, total_withdrawal
	, CASE 
		WHEN total_deposit - total_withdrawal < 0 then total_withdrawal - total_withdrawal
		ELSE total_deposit - total_withdrawal
	END as remaining_balence
	, customer_type
	FROM balences


-- checking the validity of interest and rewards 
-- turns out is its the 9th ranked event in a platform of 2.8B

	SELECT Descriptive_Purpose, SUM(value) as value
	FROM celsius_clean cc 
	GROUP BY Descriptive_Purpose
	ORDER BY value DESC
	
		
SELECT date
	 	, username
	 	, SUM(value) as value 
FROM celsius_clean cc 
WHERE Descriptive_Purpose  = 'Withdrawal' 	
GROUP BY date, username 
ORDER by DATE 
		
		
		
-- Finding the most popular withdrawl dates. 

SELECT date, COUNT(DISTINCT username)
FROM celsius_clean cc 
WHERE Descriptive_Purpose = 'Withdrawl'
GROUP BY date
ORDER BY date 


-- Liquidations by  THE most trapped assets. 

SELECT asset, SUM(value) as value 
FROM celsius_clean cc 
WHERE Descriptive_Purpose = 'Loan Principal Liquidation'
GROUP BY asset 
ORDER BY value DESC


-- OKAY so final question
-- What investor group was able to escape the best?


SELECT customer_type
	, SUM(total_deposits) as deposited
	, SUM(total_withdrawal) as withdrawn
	, (SUM(total_withdrawal))/SUM(total_deposits) as percentage
FROM celcius.remaining_balences 
GROUP BY customer_type
ORDER BY deposited

-- checking withdrawal accuracy


WITH one as (SELECT username
	, SUM(value) as withdrawal
FROM celsius_clean cc 
WHERE Descriptive_Purpose  = 'Withdrawal'
GROUP BY username 
),

two as (
SELECT username
	, total_withdrawal
FROM remaining_balences rb 
)

SELECT o.username
	, withdrawal
	, total_withdrawal
	,CASE WHEN withdrawal = total_withdrawal THEN "TRUE"
	ELSE NULL
	END as test
	FROM one o
	LEFT JOIN two t ON t.username = o.username

-- final checks

SELECT SUM(value) FROM celsius_clean cc WHERE Descriptive_Purpose  = 'Withdrawal' 

SELECT customer_type, COUNT(username) FROM remaining_balences rb GROUP BY customer_type 

SELECT * from remaining_balences ORDER BY username 



--Covid 19 health data explorations

--Tools Used: Joins, CTE's, Sub-queries, Temp Tables, Aggregate Functions, Creating Views, Converting Data Types

--Creating tables: First I had to make some workable tables for this  enourmous data set. 
--I have a question. How much influence does health have on covid death outcomes? 
--Many metrics pleople cannot control, like their locations, access to medicine, and living conditions.  
--Is there any evidence that healthy populations are less susceptible to covid deaths? 
--Health is different though, and much more under an individual's control. 


--Create views for basic health and covid data 
--I used views because they were and easy way to sort these tables for later.
--The first will represent general info about location, date, and deaths. 
--The second will include heath information per population. 

CREATE VIEW general_info_covid AS 
SELECT iso_code
	, continent
	, location
	, date
	, new_cases
	, total_deaths
	, new_deaths
	, population  
FROM owid_covid_data 


CREATE VIEW health_metrics AS 
SELECT DATE
	, continent 
	, location 
	, median_age
	, aged_65_older
	, aged_70_older
	, cardiovasc_death_rate
	, diabetes_prevalence
	, female_smokers
	, male_smokers 
FROM owid_covid_data

--I wanted to grab some headline metrics:
--World Total Deaths

Select location, MAX(total_deaths)
FROM general_info_covid gic 
WHERE location like 'world'

Wrold 
Select gic.location as location
	, CAST(SUM(gic.new_deaths)as int) as covid_deaths
FROM general_info_covid gic 
Where gic.total_deaths != '' AND gic.continent != ''
GROUP BY gic.location 

--I wanted to compare the cardiovascular death rate to the covid death rate per population
--I used CTEs to query 1 temp table tables. 
--The first, covid death rates per 100000 people in a 1 year time spam BEFORE wide spread vacine addoption. 
--(May 1st 2020, the USA opened vaccinations to all citizens.)
--I then joined it with heath metrics to few the 2 rates per country. 

With deaths as(
Select gic.location as location
	, CAST(SUM(gic.new_deaths)/(gic.population/100000) as int) as covid_death_rate
FROM general_info_covid gic 
Where gic.date BETWEEN '2020-05-01' AND '2021-05-01' AND gic.total_deaths != '' AND gic.continent != ''
GROUP BY gic.location 
)

SELECT hm. continent, hm.location, d.covid_death_rate, cast(hm.cardiovasc_death_rate as INT) as cardiovasc_death_rate
FROM health_metrics hm 
JOIN deaths d ON hm.location = d.location
WHERE hm.cardiovasc_death_rate != ''
GROUP by hm.location 

--Here I wanted to compare the percentage of smokers to the percentage of people would died from covid in a population.  
--I used CTEs to query smoking percentage as average between men and women columns 
--(I assumed 50/50 popultaion splits)
--For the Second I selected the percentage of the population that has died from covid
--I finnaly joined them and filtered them for non zero answers. 

WITH smoking_pop as 
(
SELECT DISTINCT hm.location
	, (hm.female_smokers + hm.male_smokers)/2 as smoking_percentage
FROM health_metrics hm

WHERE hm.continent != '' AND smoking_percentage > 0 
GROUP BY hm.location 
),

death_perc as 
(SELECT continent
	, location
	, max(total_deaths)/(population)*100 as covid_death_percentage
	, population 
FROM general_info_covid gic 
WHERE total_deaths != '' AND population != ''AND continent != ''
GROUP BY location 
)

SELECT dp.continent
	, dp.location
	, dp.covid_death_percentage
	, sp.smoking_percentage
	, dp.population
FROM death_perc dp
JOIN smoking_pop sp ON dp.location = sp.location

--Headline metric for Diabetes prevelence per country

SELECT continent, location, diabetes_prevalence 
FROM health_metrics hm 
WHERE continent != '' AND diabetes_prevalence != ''
GROUP BY location 


--I wanter to compare the a populations diabetes prevelence with their outcomes 
--Using Tableau I ran a cluster anaysis in order to divide diabetes risk into 5 sub classifications. 
--These were seperated using CASE WHEN statements
--I also selected the total covid death rate per country
--I joined these and performed some final aggregation.



WITH risk as (
SELECT DISTINCT hm.location as location 
	, CASE 
		WHEN hm.diabetes_prevalence < 5 THEN 'low_risk'
		WHEN hm.diabetes_prevalence < 9 THEN 'medium_risk'
		WHEN hm.diabetes_prevalence < 15 THEN 'high_risk'
		WHEN hm.diabetes_prevalence < 20 THEN 'severe_risk'
		ELSE 'extreme_risk'	
	END as risk_level
FROM health_metrics hm 
WHERE hm.diabetes_prevalence != '' AND continent != ''
),

deaths as (
SELECT continent
	, location
	, max(total_deaths)/(population/100000) as deaths_per_100000
	, population 
FROM general_info_covid gic 
WHERE total_deaths != '' AND population != ''AND continent != ''
GROUP BY location 
)

SELECT COUNT(r.location) as count
	, r.risk_level
	, CAST(AVG(d.deaths_per_100000) as int) as avg_deaths_per_100000
	, CAST(SUM(d.population)/(select MAX(population) FROM general_info_covid gic WHERE location = 'World')*100 as int) as percentage_of_population
FROM risk r 
JOIN deaths d ON d.location = r.location
GROUP BY risk_level
ORDER BY count DESC 




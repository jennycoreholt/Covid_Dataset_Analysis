SELECT 
	location,
    date,
    total_cases,
    new_cases,
    total_deaths,
    population
FROM covid_portfolio_project_1.coviddeaths;

-- Looking at Total Cases vs Total Deaths
-- Shows the likelihood of dying if you contract covid in germany between 2019 - 2021
SELECT 
	location,
    date,
    total_cases,
    total_deaths,
    (total_deaths/total_cases) * 100 AS 'deaths(%)'
FROM covid_portfolio_project_1.coviddeaths
WHERE location 
	LIKE '%germany%';

-- Looking at Total Cases vs Population
SELECT 
	location,
    date,
    total_cases,
    population,
    (total_cases/population) * 100 AS 'deaths(%)'
FROM covid_portfolio_project_1.coviddeaths
WHERE location 
	LIKE '%germany%';
    
-- What countries have the highest infection rates compared to population
SELECT 
	location,
    MAX(total_cases) AS 'Highest_Infection_Count',
    population,
    MAX((total_cases/population)) * 100 AS 'Population Infected(%)'
FROM covid_portfolio_project_1.coviddeaths
GROUP BY population,
		 location
ORDER BY 4 DESC;

-- show countries with the highest death count per population
SELECT 
	location,
	MAX(CAST(total_deaths AS unsigned)) AS 'Total_Death_Count'
FROM covid_portfolio_project_1.coviddeaths
GROUP BY location
ORDER BY 2 DESC;

-- show continents with the highest death count per population
SELECT 
	continent,
	MAX(CAST(total_deaths AS unsigned)) AS 'Total_Death_Count'
FROM covid_portfolio_project_1.coviddeaths
GROUP BY continent
ORDER BY 2 DESC;

-- show global death count
SELECT 
    SUM(new_cases) AS 'Total_Cases',
    SUM(new_deaths) AS 'Total_Deaths',
    SUM(new_deaths) / SUM(new_cases)*100 AS 'Total_Death_Count'
    -- total_deaths,
    -- (total_deaths/total_cases) * 100 AS 'deaths(%)'
FROM covid_portfolio_project_1.coviddeaths
-- GROUP BY date
ORDER BY 3;

-- Join tables by date and location: THROWS ERROR
SELECT *
FROM covid_portfolio_project_1.coviddeaths dea
JOIN covid_portfolio_project_1.covidvaccinations vac
	ON dea.location = vac.location
    AND dea.date = vac.date;

-- Troubeshooting: Check column tables for possible causes. CAUSE FOUND: DATE FORMATTING ISSUE    
SELECT DISTINCT date FROM covid_portfolio_project_1.coviddeaths LIMIT 10; 
SELECT DISTINCT date FROM covid_portfolio_project_1.covidvaccinations LIMIT 10; 

-- Update my tables for consistent date formatting and store permanently
-- Step 1: remove safe updates option REMEMBER TO REVERT THIS BACK TO 1 WHEN FINISHED
SET SQL_SAFE_UPDATES = 0;

-- Step 2: alter table / add column
ALTER TABLE covid_portfolio_project_1.coviddeaths ADD COLUMN date_clean DATE;

-- Step 3: update column with correct date format
UPDATE covid_portfolio_project_1.coviddeaths
SET date_clean = STR_TO_DATE(date, '%d.%m.%y')
WHERE date_clean IS NULL;

-- Check the results
SELECT *
FROM covid_portfolio_project_1.coviddeaths;

-- Same procedure with vaccinations table
ALTER TABLE covid_portfolio_project_1.covidvaccinations ADD COLUMN date_clean DATE;
UPDATE covid_portfolio_project_1.covidvaccinations
SET date_clean = STR_TO_DATE(date, '%c/%e/%y')
WHERE date_clean IS NULL;

-- Check the results
SELECT *
FROM covid_portfolio_project_1.covidvaccinations;

-- Reset safe updates option
SET SQL_SAFE_UPDATES = 1;

-- Join tables by date and location with clean date column
SELECT *
FROM covid_portfolio_project_1.coviddeaths dea
JOIN covid_portfolio_project_1.covidvaccinations vac
	ON dea.location = vac.location
    AND dea.date_clean = vac.date_clean;
    
-- Show total population vs vaccination 
SELECT 
	dea.continent,
    dea.location,
	dea.date_clean,
    dea.population,
    SUM(vac.new_vaccinations) OVER (partition by dea.location ORDER BY dea.location, dea.date_clean) AS 'rolling_people_vaccinated'
FROM covid_portfolio_project_1.coviddeaths dea
JOIN covid_portfolio_project_1.covidvaccinations vac
	ON dea.location = vac.location
    AND dea.date_clean = vac.date_clean
ORDER BY 2, 3;

-- Use Common Table Expression (CTE)
WITH PopulationvsVaccination (continent, location, date_clean, population, new_vaccinations, rolling_people_vaccinated)
AS (
SELECT 
	dea.continent,
    dea.location,
	dea.date_clean,
    dea.population,
    vac.new_vaccinations,
    SUM(vac.new_vaccinations) OVER (partition by dea.location ORDER BY dea.location, dea.date_clean) AS 'rolling_people_vaccinated'
FROM covid_portfolio_project_1.coviddeaths dea
JOIN covid_portfolio_project_1.covidvaccinations vac
	ON dea.location = vac.location
    AND dea.date_clean = vac.date_clean
)
SELECT *,
	(rolling_people_vaccinated/population)*100 AS '%_population_vaccinated'
FROM PopulationvsVaccination
ORDER BY location, date_clean;

-- TEMPORARY TABLE
DROP TEMPORARY TABLE IF EXISTS PercentPopulationVaccinated;

CREATE TEMPORARY TABLE PercentPopulationVaccinated (
    continent VARCHAR(255),
    location VARCHAR(255),
    date_clean DATETIME,
    population NUMERIC,
    new_vaccinations DECIMAL(15,2),
    rolling_people_vaccinated NUMERIC
);

INSERT INTO PercentPopulationVaccinated
SELECT 
    dea.continent,
    dea.location,
    dea.date_clean,
    dea.population,
    CAST(NULLIF(REPLACE(vac.new_vaccinations, ',', ''), '') AS DECIMAL(15,2)) AS new_vaccinations,
    SUM(CAST(NULLIF(REPLACE(vac.new_vaccinations, ',', ''), '') AS DECIMAL(15,2))) 
        OVER (PARTITION BY dea.location ORDER BY dea.location, dea.date_clean) AS rolling_people_vaccinated
FROM covid_portfolio_project_1.coviddeaths dea
JOIN covid_portfolio_project_1.covidvaccinations vac
    ON dea.location = vac.location
    AND dea.date_clean = vac.date_clean;

SELECT * FROM PercentPopulationVaccinated;

-- create view to store data for visualisations: Percentage of the population vaccinated
CREATE VIEW PercentPopulationVaccinated AS 
SELECT 
    dea.continent,
    dea.location,
    dea.date_clean,
    dea.population,
    CAST(NULLIF(REPLACE(vac.new_vaccinations, ',', ''), '') AS DECIMAL(15,2)) AS new_vaccinations,
    SUM(CAST(NULLIF(REPLACE(vac.new_vaccinations, ',', ''), '') AS DECIMAL(15,2))) 
        OVER (PARTITION BY dea.location ORDER BY dea.location, dea.date_clean) AS rolling_people_vaccinated
FROM covid_portfolio_project_1.coviddeaths dea
JOIN covid_portfolio_project_1.covidvaccinations vac
    ON dea.location = vac.location
    AND dea.date_clean = vac.date_clean;

SELECT *
FROM covid_portfolio_project_1.percentpopulationvaccinated;

-- create view to store data for visualisations: highest death count per population
CREATE VIEW TotalDeathCountPerContinent AS 
SELECT 
	continent,
	MAX(CAST(total_deaths AS unsigned)) AS 'Total_Death_Count'
FROM covid_portfolio_project_1.coviddeaths
GROUP BY continent
ORDER BY 2 DESC;

SELECT *
FROM covid_portfolio_project_1.TotalDeathCountPerContinent;

-- create view to store data for visualisations: show global death count
CREATE VIEW GlobalDeathCount AS 
SELECT 
    SUM(new_cases) AS 'Total_Cases',
    SUM(new_deaths) AS 'Total_Deaths',
    SUM(new_deaths) / SUM(new_cases)*100 AS 'Total_Death_Count'
FROM covid_portfolio_project_1.coviddeaths
ORDER BY 3;

SELECT *
FROM covid_portfolio_project_1.GlobalDeathCount;

-- create view to store data for visualisations: Likelihood of dying of Covid in Germany
CREATE VIEW LiklihoodOfDyingGermany AS 
SELECT 
	location,
    date,
    total_cases,
    total_deaths,
    (total_deaths/total_cases) * 100 AS 'deaths(%)'
FROM covid_portfolio_project_1.coviddeaths
WHERE location 
	LIKE '%germany%';

SELECT *
FROM covid_portfolio_project_1.LiklihoodOfDyingGermany;

-- create view to store data for visualisations: Total Cases vs Population Germany
CREATE VIEW TotalCasesGermany AS 
SELECT 
	location,
    date,
    total_cases,
    population,
    (total_cases/population) * 100 AS 'deaths(%)'
FROM covid_portfolio_project_1.coviddeaths
WHERE location 
	LIKE '%germany%';

SELECT *
FROM covid_portfolio_project_1.TotalCasesGermany;

-- create view to store data for visualisations: countries with highest infection
CREATE VIEW CountriesWithHighestInfectionRate AS 
SELECT 
	location,
    MAX(total_cases) AS 'Highest_Infection_Count',
    population,
    MAX((total_cases/population)) * 100 AS 'Population Infected(%)'
FROM covid_portfolio_project_1.coviddeaths
GROUP BY population,
		 location
ORDER BY 4 DESC;

SELECT *
FROM covid_portfolio_project_1.CountriesWithHighestInfectionRate;

-- create view to store data for visualisations: countries with highest death count
CREATE VIEW CountriesWithHighestDeathCount AS 
SELECT 
	location,
	MAX(CAST(total_deaths AS unsigned)) AS 'Total_Death_Count'
FROM covid_portfolio_project_1.coviddeaths
GROUP BY location
ORDER BY 2 DESC;

SELECT *
FROM covid_portfolio_project_1.CountriesWithHighestDeathCount;
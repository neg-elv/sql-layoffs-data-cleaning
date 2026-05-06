/*
================================================================================
SQL Data Cleaning Project
Dataset: Layoffs Dataset
Author: Negin

Project Goal:
Clean and prepare a raw layoffs dataset for analysis by removing duplicates,
standardizing inconsistent values, handling null/blank values, converting data
formats, and removing unnecessary columns.

Skills Demonstrated:
- Creating staging tables
- Using window functions: ROW_NUMBER()
- Detecting and removing duplicate rows
- Standardizing text values with TRIM()
- Converting text dates into DATE format with STR_TO_DATE()
- Handling NULL and blank values
- Self-joining a table to populate missing values
- Removing irrelevant rows and columns
================================================================================
*/


-- ============================================================================
-- 1. Create a staging table
-- ============================================================================
-- Best practice: never clean or modify the raw table directly.
-- We first create a copy of the original dataset and perform all cleaning steps
-- on the staging table.

CREATE TABLE layoffs_staging
LIKE layoffs;

INSERT INTO layoffs_staging
SELECT *
FROM layoffs;


-- ============================================================================
-- 2. Detect duplicate rows
-- ============================================================================
-- ROW_NUMBER() assigns a number to each row within groups of identical records.
-- If row_num > 1, the row is considered a duplicate.

WITH duplicate_cte AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY company, location, industry, total_laid_off,
                         percentage_laid_off, `date`, stage, country,
                         funds_raised_millions
        ) AS row_num
    FROM layoffs_staging
)
SELECT *
FROM duplicate_cte
WHERE row_num > 1;


-- Optional check: inspect one company to confirm duplicate behavior.
SELECT *
FROM layoffs_staging
WHERE company = 'Casper';


-- ============================================================================
-- 3. Create a second staging table with row numbers
-- ============================================================================
-- MySQL does not allow deleting directly from a CTE in this way.
-- Therefore, we create a second staging table that includes row_num,
-- then delete the duplicate rows from that table.

CREATE TABLE layoffs_staging2 (
    company TEXT,
    location TEXT,
    industry TEXT,
    total_laid_off TEXT,
    percentage_laid_off TEXT,
    `date` TEXT,
    stage TEXT,
    country TEXT,
    funds_raised_millions TEXT,
    row_num INT
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_0900_ai_ci;

INSERT INTO layoffs_staging2
SELECT
    *,
    ROW_NUMBER() OVER (
        PARTITION BY company, location, industry, total_laid_off,
                     percentage_laid_off, `date`, stage, country,
                     funds_raised_millions
    ) AS row_num
FROM layoffs_staging;


-- Remove duplicate rows and verify that no duplicates remain.
DELETE
FROM layoffs_staging2
WHERE row_num > 1;

SELECT *
FROM layoffs_staging2
WHERE row_num > 1;


-- ============================================================================
-- 4. Standardize text data
-- ============================================================================

-- Remove extra spaces from company names.
SELECT
    company,
    TRIM(company) AS cleaned_company
FROM layoffs_staging2;

UPDATE layoffs_staging2
SET company = TRIM(company);


-- Check distinct industries to find inconsistent naming.
SELECT DISTINCT industry
FROM layoffs_staging2
ORDER BY industry;

-- Example: standardize all Crypto-related industry values to 'Crypto'.
SELECT *
FROM layoffs_staging2
WHERE industry LIKE 'Crypto%';

UPDATE layoffs_staging2
SET industry = 'Crypto'
WHERE industry LIKE 'Crypto%';


-- Check distinct locations.
SELECT DISTINCT location
FROM layoffs_staging2
ORDER BY location;


-- Check and clean country values.
SELECT DISTINCT country
FROM layoffs_staging2
ORDER BY country;

SELECT DISTINCT
    country,
    TRIM(TRAILING '.' FROM country) AS cleaned_country
FROM layoffs_staging2
WHERE country LIKE 'United States%'
ORDER BY country;

UPDATE layoffs_staging2
SET country = TRIM(TRAILING '.' FROM country)
WHERE country LIKE 'United States%';


-- ============================================================================
-- 5. Convert date column from text to DATE type
-- ============================================================================
-- The original date values are stored as text in MM/DD/YYYY format.
-- STR_TO_DATE() converts them into a real SQL date.

SELECT
    `date`,
    STR_TO_DATE(`date`, '%m/%d/%Y') AS converted_date
FROM layoffs_staging2;

UPDATE layoffs_staging2
SET `date` = STR_TO_DATE(`date`, '%m/%d/%Y');

ALTER TABLE layoffs_staging2
MODIFY COLUMN `date` DATE;

-- Verify date conversion.
SELECT `date`
FROM layoffs_staging2
ORDER BY `date`;


-- ============================================================================
-- 6. Handle NULL and blank values
-- ============================================================================

-- Identify records where both layoff count and percentage are missing.
SELECT *
FROM layoffs_staging2
WHERE total_laid_off IS NULL
  AND percentage_laid_off IS NULL;


-- Identify rows with missing industry values.
SELECT *
FROM layoffs_staging2
WHERE industry IS NULL
   OR industry = '';


-- Convert blank industry values to NULL for consistency.
UPDATE layoffs_staging2
SET industry = NULL
WHERE industry = '';


-- ============================================================================
-- 7. Populate missing industry values using available company data
-- ============================================================================
-- Some companies appear multiple times. If one row has a missing industry but
-- another row for the same company has a valid industry, we can use a self-join
-- to fill the missing value.

-- Example check: Airbnb has multiple records.
SELECT *
FROM layoffs_staging2
WHERE company = 'Airbnb';


-- Preview the values that can be populated before updating.
SELECT
    t1.company,
    t1.location,
    t1.industry AS missing_industry,
    t2.industry AS available_industry
FROM layoffs_staging2 AS t1
JOIN layoffs_staging2 AS t2
    ON t1.company = t2.company
WHERE t1.industry IS NULL
  AND t2.industry IS NOT NULL;


-- Populate missing industry values.
UPDATE layoffs_staging2 AS t1
JOIN layoffs_staging2 AS t2
    ON t1.company = t2.company
SET t1.industry = t2.industry
WHERE t1.industry IS NULL
  AND t2.industry IS NOT NULL;


-- Check remaining rows with missing industry values.
-- If a company has no valid industry value anywhere in the dataset,
-- we should not guess the industry manually.
SELECT *
FROM layoffs_staging2
WHERE industry IS NULL;


-- ============================================================================
-- 8. Remove rows that are not useful for analysis
-- ============================================================================
-- Rows where both total_laid_off and percentage_laid_off are missing do not
-- provide useful layoff size information for this analysis.

SELECT *
FROM layoffs_staging2
WHERE total_laid_off IS NULL
  AND percentage_laid_off IS NULL;

DELETE
FROM layoffs_staging2
WHERE total_laid_off IS NULL
  AND percentage_laid_off IS NULL;


-- ============================================================================
-- 9. Remove helper column
-- ============================================================================
-- row_num was only needed for duplicate detection and removal.

ALTER TABLE layoffs_staging2
DROP COLUMN row_num;


-- ============================================================================
-- 10. Final cleaned dataset
-- ============================================================================

SELECT *
FROM layoffs_staging2;


-- Optional final checks
SELECT COUNT(*) AS final_row_count
FROM layoffs_staging2;

SELECT DISTINCT industry
FROM layoffs_staging2
ORDER BY industry;

SELECT DISTINCT country
FROM layoffs_staging2
ORDER BY country;

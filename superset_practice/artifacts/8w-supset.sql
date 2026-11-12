SELECT * from default.HH limit 10;

DESCRIBE TABLE default.HH;

SELECT count() AS total_rows FROM default.HH;

SELECT
    countIf(id IS NULL) AS null_id,
    countIf(technology = '' OR technology IS NULL) AS empty_technology,
    countIf(name = '' OR name IS NULL) AS empty_name,
    countIf(company = '' OR company IS NULL) AS empty_company,
    countIf(city = '' OR city IS NULL) AS empty_city,
    countIf(salary_from IS NULL) AS null_salary_from,
    countIf(salary_to IS NULL) AS null_salary_to,
    countIf(salary_currency = '' OR salary_currency IS NULL) AS empty_currency,
    countIf(experience = '' OR experience IS NULL) AS empty_experience,
    countIf(employment = '' OR employment IS NULL) AS empty_employment,
    countIf(schedule = '' OR schedule IS NULL) AS empty_schedule,
    countIf(published IS NULL) AS null_published,
    countIf(key_skills = '' OR key_skills IS NULL) AS empty_key_skills,
    countIf(description = '' OR description IS NULL) AS empty_description
FROM default.HH;
-- null_id	empty_technology	empty_name	empty_company	empty_city	null_salary_from	null_salary_to	empty_currency	empty_experience	empty_employment	empty_schedule	null_published	empty_key_skills	empty_description
-- 0	0	0	0	0	0	0	6368	0	3636	3636	0	3620	0



--дубликаты
SELECT
    count() AS total,
    countDistinct(id) AS unique_ids,
    count() - countDistinct(id) AS duplicates_count
FROM default.HH;
--total	unique_ids	duplicates_count
--10257	10256	1

SELECT technology, count() AS cnt
FROM default.HH
WHERE (technology != '') AND (technology IS NOT NULL)
GROUP BY technology
ORDER BY cnt DESC
LIMIT 20;
--все ок

-- Опыт
SELECT experience--, count() AS cnt
FROM default.HH
WHERE (experience != '') AND (experience IS NOT NULL)
GROUP BY experience;
--ORDER BY cnt DESC;
--все ок

SELECT employment--, count() AS cnt
FROM default.HH
WHERE (employment != '') AND (employment IS NOT NULL)
GROUP BY employment;
--ORDER BY cnt DESC;

--need to be replaced

-- График
SELECT schedule--, count() AS cnt
FROM default.HH
WHERE (schedule != '') AND (schedule IS NOT NULL)
GROUP BY schedule;
--ORDER BY cnt DESC;
--too much

-- Валюты
SELECT salary_currency--, count() AS cnt
FROM default.HH
WHERE (salary_currency != '') AND (salary_currency IS NOT NULL)
GROUP BY salary_currency;
--ORDER BY cnt DESC;
-- salary_currency
-- RUR
-- USD
-- EUR

select count() from default.HH where published::DATE >= '2026-01-01';

SELECT
  id,
  any(technology) AS technology,
  any(name) AS vacancy_name,
  any(company) AS company,
  any(city) AS city,
  -- средняя зарплата в валюте (все значения приведены к Float64)
  if(
      ifNull(toFloat64(any(salary_from)), 0) > 0 AND ifNull(toFloat64(any(salary_to)), 0) > 0,
      (toFloat64(any(salary_from)) + toFloat64(any(salary_to))) / 2,
      if(ifNull(toFloat64(any(salary_from)), 0) > 0, toFloat64(any(salary_from)),
         if(ifNull(toFloat64(any(salary_to)), 0) > 0, toFloat64(any(salary_to)), NULL))
  ) AS avg_salary_currency,
  -- конвертация в рубли
  CASE
      WHEN any(salary_currency) = 'USD' THEN avg_salary_currency * 76.37
      WHEN any(salary_currency) = 'EUR' THEN avg_salary_currency * 87.09
      ELSE avg_salary_currency   -- или NULL, если нужно только RUR
  END AS salary_rub_avg,
  -- Группировка опыта
  CASE
      WHEN any(experience) = 'Нет опыта' THEN 'Junior'
      WHEN any(experience) = 'От 1 года до 3 лет' THEN 'Middle'
      WHEN any(experience) = 'От 3 до 6 лет' THEN 'Senior'
      WHEN any(experience) = 'Более 6 лет' THEN 'Lead'
      ELSE 'Unknown'
  END AS experience_group,

  -- Группировка занятости (объединение по вашему списку)
  CASE
      WHEN any(employment) IN ('Проект', 'Проектная работа') THEN 'Проектная работа'
      WHEN any(employment) IN ('Полная', 'Полная занятость') THEN 'Полная занятость'
      WHEN any(employment) IN ('Подработка', 'Частичная', 'Частичная занятость') THEN 'Частичная занятость'
      ELSE 'Unknown'
  END AS employment_group,

  toDate(any(published)) AS published_date,
  toYear(any(published)) AS published_year,
  toMonth(any(published)) AS published_month

FROM default.HH
-- WHERE id IS NOT NULL
--   AND (technology != '' AND technology IS NOT NULL)
--   AND (company != '' AND company IS NOT NULL)
--   AND (city != '' AND city IS NOT NULL)
GROUP BY id
-- при необходимости раскомментировать фильтр по дате
-- HAVING published_date >= '2025-01-01'
;

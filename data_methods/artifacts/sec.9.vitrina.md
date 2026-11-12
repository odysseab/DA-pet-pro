## 9. Детальное описание витрин

### 9.1. Основная витрина: `discount_analytics` (ClickHouse)

#### Назначение

Предоставляет агрегированные показатели для анализа эффективности скидочных и промо-кампаний: наиболее популярные скидки (по `discount_id` и `discount_category`), динамика конверсии в скидку по дням, часам, географии и устройствам, а также детализированные данные по каждому открытию скидки/промокода. Витрина построена поверх существующих таблиц `events` и `sessions` и оптимизирована для быстрых запросов дашборда.

#### Бизнес-ценность

- Позволяет маркетологам и менеджерам по продукту **выявлять самые привлекательные скидки** и перераспределять бюджет на их продвижение.
- Даёт возможность **оптимизировать время запуска акций** – публиковать скидки в часы и дни максимальной активности пользователей.
- Помогает **сегментировать аудиторию** (новые vs возвратные пользователи) для персонализированных предложений.
- Снижает время подготовки отчётов с нескольких дней до секунд благодаря предрасчитанным агрегатам.

#### Технические параметры

| Параметр | Значение |
|----------|----------|
| **СУБД** | ClickHouse |
| **Схема** | `google_analytics` |
| **Таблица** | `discount_analytics` (материализованное представление либо физическая таблица, обновляемая в рамках DAG) |
| **Гранулярность** | Одна строка = комбинация `(date, discount_id, discount_category, country, device_category, is_new)` для агрегированных метрик; отдельная секция с детальными строками (или отдельная таблица `discount_details`). Для упрощения – две связанные сущности: агрегаты и детализация. |
| **Глубина хранения** | 3 года (актуальные данные за весь доступный период) |
| **Частота обновления** | Еженедельно, после обновления слоёв `events` и `sessions` |
| **Способ обновления** | **Инкремент + снапшот**: агрегированные данные пересчитываются только за последние 4 недели (скользящее окно), исторические агрегаты не трогаются; детальные данные (открытия скидок) дописываются инкрементально. При первом развёртывании – полная перезагрузка. |

#### Структура полей

**Таблица `discount_analytics` (агрегированная часть):**

| Поле | Тип | Описание |
|------|-----|----------|
| `date` | Date | Дата события (агрегации) |
| `discount_id` | UInt32 | Идентификатор скидки (0 – без скидки, >0 – конкретная скидка) |
| `discount_category` | String | Категория скидки (например, 'beauty-health', 'electronics') |
| `country` | String | Страна пользователя |
| `device_category` | String | Тип устройства (desktop, mobile, tablet) |
| `is_new` | Bool | Тип пользователя: true – новый, false – возвратный |
| `total_opens` | UInt32 | Количество открытий данной скидки |
| `unique_sessions` | UInt32 | Количество уникальных сессий, в которых открыта эта скидка |
| `avg_opens_per_session` | Float64 | Среднее количество открытий на сессию (total_opens / unique_sessions) |
| `conversion_rate` | Float64 | Доля сессий с данной скидкой от общего числа сессий в той же группе (страна, устройство, тип пользователя) – вычисляется на лету или хранится отдельно |
| `hour` | UInt8 | Час дня (0-23) – для тепловых карт |
| `day_of_week` | UInt8 | День недели (1-7) – для тепловых карт |

*Примечание:* для тепловых карт и динамики по дням используется отдельный срез (либо те же поля с группировкой по `hour`, `day_of_week`).

**Таблица `discount_details` (детализация):**

| Поле | Тип | Описание |
|------|-----|----------|
| `date` | Date | Дата события |
| `hour` | UInt8 | Час события |
| `discount_id` | UInt32 | Идентификатор скидки |
| `discount_category` | String | Категория скидки |
| `country` | String | Страна |
| `region` | String | Регион/область |
| `city` | String | Город |
| `device_category` | String | Тип устройства |
| `browser` | String | Браузер |
| `is_new` | Bool | Тип пользователя |
| `synthetic_session_id` | String | Идентификатор сессии (для связи с другими данными) |
| `user_fingerprint` | String | Идентификатор пользователя |
| `page_location` | String | URL страницы, где произошло открытие скидки |
| `page_referrer` | String | Источник перехода |

#### Спецификация метрик

| Метрика | Формула / Источник | Бизнес-смысл |
|---------|--------------------|--------------|
| `total_opens` | `COUNT(*)` из `events` с `event_name = 'Open_discount'` и группировкой по измерениям | Общая популярность скидки |
| `unique_sessions` | `COUNT(DISTINCT synthetic_session_id)` | Сколько сессий вовлечено в скидку |
| `avg_opens_per_session` | `total_opens / unique_sessions` | Интенсивность использования скидки в рамках одной сессии |
| `conversion_rate` | `unique_sessions_with_discount / total_sessions` (из `sessions`) | Эффективность скидки как конверсионного триггера |
| `bounce_rate_among_discount_sessions` | Доля отказных сессий среди сессий с данной скидкой | Оценивает, удерживает ли скидка пользователя |

#### DDL (ClickHouse)

```sql
-- Агрегированная таблица (с заменой при повторной вставке)
CREATE TABLE google_analytics.discount_analytics (
    date Date,
    discount_id UInt32,
    discount_category String,
    country String,
    device_category String,
    is_new Bool,
    total_opens UInt32,
    unique_sessions UInt32,
    avg_opens_per_session Float64,
    hour UInt8,
    day_of_week UInt8
) ENGINE = ReplacingMergeTree()
ORDER BY (date, discount_id, country, device_category, is_new, hour, day_of_week);

-- Детальная таблица (инкрементальная)
CREATE TABLE google_analytics.discount_details (
    date Date,
    hour UInt8,
    discount_id UInt32,
    discount_category String,
    country String,
    region String,
    city String,
    device_category String,
    browser String,
    is_new Bool,
    synthetic_session_id String,
    user_fingerprint String,
    page_location String,
    page_referrer String
) ENGINE = MergeTree()
ORDER BY (date, discount_id, country, device_category)
PARTITION BY toYYYYMM(date);
```

### 9.2. Использование витрины для удовлетворения user stories

| User Story | Как витрина даёт ответ | Конкретный пример запроса / действия |
|------------|------------------------|--------------------------------------|
| **US-1** (Маркетолог: топ-20 скидок по открытиям) | Агрегированная таблица позволяет отсортировать `discount_id` по `total_opens` за выбранный период. | `SELECT discount_id, discount_category, total_opens FROM discount_analytics WHERE date BETWEEN '2026-04-01' AND '2026-04-30' ORDER BY total_opens DESC LIMIT 20;` |
| **US-2** (Продуктовый аналитик: динамика конверсии по странам и устройствам) | В витрине есть поля `date`, `country`, `device_category` и вычисляемая метрика `conversion_rate` (можно добавить как материализованную или считать на лету через `JOIN` с `sessions`). | `SELECT date, country, device_category, AVG(conversion_rate) FROM discount_analytics WHERE discount_id > 0 GROUP BY date, country, device_category ORDER BY date;` |
| **US-3** (Менеджер по продукту: тепловая карта по часам и дням недели) | Витрина содержит `hour` и `day_of_week`, можно сгруппировать `total_opens` по этим измерениям. | `SELECT hour, day_of_week, SUM(total_opens) as opens FROM discount_analytics GROUP BY hour, day_of_week ORDER BY day_of_week, hour;` |
| **US-4** (Аналитик данных: сравнение новых vs возвратных пользователей) | Поле `is_new` позволяет фильтровать и сравнивать все метрики для двух сегментов. | `SELECT is_new, AVG(avg_opens_per_session) FROM discount_analytics WHERE discount_id = 12345 GROUP BY is_new;` |
| **US-5** (Рекламный менеджер: детальная таблица открытий промокодов по региону и устройству) | Таблица `discount_details` содержит все необходимые поля (`country`, `region`, `city`, `device_category`, `browser`, а также `synthetic_session_id` для связи с конверсией). | `SELECT date, country, region, city, device_category FROM discount_details WHERE discount_id IN (SELECT discount_id FROM ... WHERE discount_category = 'promo_code') ORDER BY date DESC LIMIT 1000;` |
| **US-6** (BI-разработчик: единый датасет `all_data`) | Витрина не заменяет `all_data`, но может быть легко объединена с ним через `synthetic_session_id`. | `SELECT * FROM all_data WHERE event_name = 'Open_discount';` |
| **US-7** (Руководитель отдела маркетинга: динамика сессий со скидками за 4 недели) | В витрине есть `date` и `unique_sessions` для каждой скидки; можно агрегировать по дате и суммировать уникальные сессии. | `SELECT date, SUM(unique_sessions) AS sessions_with_discount FROM discount_analytics WHERE date >= today() - 28 GROUP BY date ORDER BY date;` |
| **US-8** (Системный аналитик: агрегация по категориям скидок) | Поле `discount_category` позволяет группировать метрики по категориям (beauty-health, electronics и др.). | `SELECT discount_category, SUM(total_opens) AS total_opens, COUNT(DISTINCT discount_id) AS unique_discounts FROM discount_analytics GROUP BY discount_category ORDER BY total_opens DESC;` |

### 9.3. Процесс обновления витрины в рамках Airflow

Существующий DAG `GA_gp_ch` уже содержит шаги `fill_events` и `fill_sessions`. Для витрины `discount_analytics` добавляется дополнительная задача `fill_discount_analytics`, которая выполняется после `fill_sessions`. Логика обновления:

1. **Инкремент для `discount_details`**:  
   `INSERT INTO discount_details SELECT ... FROM events WHERE date >= (SELECT max(date) FROM discount_details) - 7` (за последнюю неделю).

2. **Снапшот для `discount_analytics`**:  
   Таблица пересоздаётся для скользящего окна (последние 28 дней) с помощью `INSERT ... SELECT ... GROUP BY`, а затем старые данные (старше 28 дней) не трогаются. Для простоты можно пересоздавать всю таблицу каждую неделю (объём невелик).

### 9.4. Пример аналитического запроса (топ-10 скидок по конверсии среди мобильных пользователей за последнюю неделю)

```sql
SELECT 
    discount_id,
    discount_category,
    SUM(unique_sessions) AS sessions_with_discount,
    SUM(total_opens) AS total_opens,
    ROUND(SUM(total_opens) / SUM(unique_sessions), 2) AS avg_opens_per_session
FROM google_analytics.discount_analytics
WHERE date >= today() - 7
  AND device_category = 'mobile'
  AND discount_id > 0
GROUP BY discount_id, discount_category
ORDER BY sessions_with_discount DESC
LIMIT 10;
```

Таким образом, предложенная витрина полностью покрывает все бизнес-требования и user stories, обеспечивая высокую производительность и гибкость аналитики по скидкам.
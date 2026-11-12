## 8. Маппинг таблиц и трансформации данных между слоями

### 8.1. Общая схема трансформаций

![](./img/transformation.png)

### 8.2. Маппинг RAW → Stage / ODS (внешняя таблица `gp_ext`)

На этом этапе данные перемещаются из Hive-таблицы `raw` (формат Parquet, строковые типы) во внешнюю таблицу Greenplum `gp_ext`. Трансформации выполняются «на лету» при чтении через PXF.

**Маппинг полей и преобразования типов:**

| Поле в RAW (Hive, тип STRING) | Поле в `gp_ext` (Greenplum) | Тип в `gp_ext` | Преобразование |
|-------------------------------|----------------------------|----------------|----------------|
| `yearmonth` | `yearmonth` | TEXT | Без изменений (служебное поле партиции) |
| `firstsessiondate` | `first_session_date` | DATE | `CAST(string AS DATE)` (формат YYYY-MM-DD) |
| `datehourminute` | `datehourminute` | TIMESTAMP | `CAST(string AS TIMESTAMP)` (маска YYYY-MM-DD HH24:MI:SS) |
| `eventname` | `event_name` | TEXT | Приведение к нижнему регистру, обрезка пробелов |
| `iskeyevent` | `is_key_event` | BOOLEAN | `true` если строка = 'true'/'1'/'True', иначе `false` |
| `newsvreuming` (опечатка в raw) | `is_new` | BOOLEAN | Аналогично: 'true' → `true`, иначе `false` |
| `signedinwithuserid` | `signed_in_with_user_id` | BOOLEAN | Аналогично |
| `city` | `city` | TEXT | Обрезка пробелов, замена пустых строк на NULL |
| `country` | `country` | TEXT | Обрезка пробелов |
| `continent` | `continent` | TEXT | Без изменений |
| `cityid` | `city_id` | INTEGER | `CAST(string AS INTEGER)`, при ошибке → NULL |
| `countryid` | `country_id` | TEXT | Верхний регистр, обрезка |
| `continentid` | `continent_id` | TEXT | Без изменений |
| `region` | `region` | TEXT | Обрезка пробелов |
| `browser` | `browser` | TEXT | Нормализация названий (например, 'CHROME' → 'Chrome') |
| `language` | `language` | TEXT | Без изменений |
| `languagecode` | `language_code` | TEXT | Приведение к нижнему регистру |
| `operating system with version` (пробел) | `operating_system_with_version` | TEXT | Переименование, обрезка пробелов |
| `screensolution` (опечатка) | `screen_resolution` | TEXT | Очистка: удаление непечатных символов |
| `devicecategory` | `device_category` | TEXT | Нормализация ('desktop'/'mobile'/'tablet') |
| `devicemodel` | `device_model` | TEXT | Без изменений |
| `mobiledevicebranding` | `mobile_device_branding` | TEXT | Замена пустых строк на NULL |
| `mobiledevicemarketingname` | `mobile_device_marketing_name` | TEXT | Замена пустых строк на NULL |
| `mobiledevicemodel` | `mobile_device_model` | TEXT | Замена пустых строк на NULL |
| `page location` (пробел) | `page_location` | TEXT | Переименование, удаление невалидных URL-символов |
| `pagereferer` (опечатка) | `page_referrer` | TEXT | Обрезка пробелов, `NULL` если пусто |
| `linkurl` | `link_url` | TEXT | Обрезка пробелов |
| `landingpageplusquerystring` | `landing_page_plus_query_string` | TEXT | Без изменений |

**Очистка и валидация на этом этапе:**
- Удаление записей, где `datehourminute` имеет некорректный формат или `NULL`.
- Отбрасывание событий с неизвестным `eventname` (не в списке допустимых типов событий).
- Установка `is_new = false`, если `firstsessiondate` > текущей даты (защита от будущих дат).

### 8.3. Маппинг ODS → DDS (Greenplum: `gp_ext` → измерения + факты)

На этом этапе происходит нормализация: широкая таблица `gp_ext` расщепляется на 5 измерений и 1 таблицу фактов. Трансформации выполняются процедурами `fill_dim_*` и `fill_fact_event`.

#### 8.3.1. Заполнение измерений (SCD Type 0)

| Измерение | Источник (поля `gp_ext`) | Генерация суррогатного ключа | Дополнительная логика |
|-----------|--------------------------|------------------------------|----------------------|
| `dim_date` | `datehourminute::DATE` | `date_id` = DATE (нативный) | Вычисляются поля: `year`, `month`, `month_name`, `day`, `day_of_week`, `week`, `is_weekend`. При первом заполнении генерируется весь календарный диапазон от MIN до MAX дат в источнике. |
| `dim_time` | `datehourminute::TIME` | `time_id` = TIME (нативный) | Вычисляются `hour`, `minute`, `time_of_day` (утро/день/вечер/ночь). Аналогично – предрасчёт всех возможных минут в сутках (1440 записей). |
| `dim_device` | `device_category`, `browser`, `operating_system_with_version`, `screen_resolution`, `language`, `language_code`, `mobile_device_branding`, `mobile_device_marketing_name`, `mobile_device_model` | `device_id` = MD5(конкатенация всех перечисленных полей) | Вставляются только новые комбинации (не существующие в таблице). Пустые мобильные поля для desktop-устройств игнорируются. |
| `dim_location` | `continent`, `continent_id`, `country`, `country_id`, `region`, `city`, `city_id` | `location_id` = MD5(конкатенация: continent \|\| country \|\| region \|\| city) | Вставляются только новые комбинации. Приводим `city_id` из `gp_ext` (INTEGER) – если NULL, то в хеш идёт 'unknown'. |
| `dim_page` | `page_location`, `page_referrer`, `link_url`, `landing_page_plus_query_string` (частично) | `page_id` = MD5(`page_location`) | **Обогащение**: из `page_location` извлекается `page_path` (часть после домена), а также парсится параметр `discount_id` и `discount_category` из query-строки (например, `?discount=123&category=beauty`). Поля `link_domain` извлекается из `link_url`. |

**Особенность:** Процедуры `fill_dim_*` используют `INSERT ... WHERE NOT EXISTS` для избежания дубликатов. Это SCD Type 0 – исторические значения не перезаписываются.

#### 8.3.2. Заполнение фактов `fact_event`

| Поле в `fact_event` | Источник (прямо или через подзапрос) | Трансформация |
|---------------------|--------------------------------------|---------------|
| `date_id` | `gp_ext.datehourminute::DATE` | Прямое приведение |
| `time_id` | `gp_ext.datehourminute::TIME` | Прямое приведение |
| `device_id` | Подзапрос к `dim_device` | `SELECT device_id FROM dim_device WHERE MD5(...) = MD5(из gp_ext)` |
| `location_id` | Подзапрос к `dim_location` | Аналогично |
| `page_id` | Подзапрос к `dim_page` | Аналогично |
| `event_name` | `gp_ext.event_name` | Приведение к нижнему регистру, трим |
| `is_key_event` | `gp_ext.is_key_event` | Прямое копирование BOOLEAN |
| `is_new` | `gp_ext.is_new` | Прямое копирование |
| `signed_in_with_user_id` | `gp_ext.signed_in_with_user_id` | Прямое копирование |
| `first_session_date` | `gp_ext.first_session_date` | Прямое копирование DATE |
| `user_fingerprint` | **Вычисляемое** | `MD5(device_id \|\| location_id \|\| city \|\| browser \|\| language_code)` – устойчивый идентификатор анонимного пользователя |
| `synthetic_session_id` | **Вычисляемое** | `MD5(user_fingerprint \|\| first_session_date \|\| session_num)` – уникальный ID сессии, формируемый на основе номера сессии |
| `session_num` | **Вычисляемое** | Ранжирование событий одного пользователя по `datehourminute` (оконная функция `ROW_NUMBER() OVER (PARTITION BY user_fingerprint ORDER BY datehourminute)`) |

**Дополнительные трансформации в факте:**
- Удаление дубликатов: если для одного `(date_id, time_id, page_id, device_id, location_id, user_fingerprint)` существует несколько строк с одинаковым `event_name`, оставляется только одна.
- Фильтрация: исключаются служебные события (например, `session_start`, `first_visit`), если они не нужны для аналитики скидок.

### 8.4. Маппинг DDS → Data Mart (ClickHouse)

#### 8.4.1. Внешняя таблица `ch_ext` (шлюз)

`ch_ext` создаётся как PostgreSQL-движок в ClickHouse, который напрямую читает данные из Greenplum. Маппинг полей – один в один с `fact_event` и присоединёнными измерениями (денормализация на лету). Фактически `ch_ext` – это представление:

```sql
-- Псевдокод: SELECT-запрос, который выполняется в Greenplum
SELECT 
    f.date_id, f.time_id, f.device_id, f.location_id, f.page_id,
    f.event_name, f.is_key_event, f.is_new, f.signed_in_with_user_id,
    f.first_session_date, f.user_fingerprint, f.synthetic_session_id, f.session_num,
    d.year, d.month, d.month_name, d.day, d.day_of_week, d.is_weekend,
    t.hour, t.minute, t.time_of_day,
    dev.device_category, dev.browser, dev.operating_system_with_version, dev.screen_resolution,
    loc.continent, loc.country, loc.region, loc.city,
    p.page_location, p.page_path, p.discount_id, p.discount_category, p.link_url, p.page_referrer
FROM fact_event f
LEFT JOIN dim_date d ON f.date_id = d.date_id
LEFT JOIN dim_time t ON f.time_id = t.time_id
LEFT JOIN dim_device dev ON f.device_id = dev.device_id
LEFT JOIN dim_location loc ON f.location_id = loc.location_id
LEFT JOIN dim_page p ON f.page_id = p.page_id;
```

**Трансформация:** денормализация – все атрибуты измерений «притягиваются» к факту, образуя широкую плоскую таблицу. Это необходимо, так как ClickHouse не оптимизирован для джойнов, а предпочитает денормализованные данные.

#### 8.4.2. Таблица `events` (физическая копия)

| Поле в `ch_ext` | Поле в `events` | Трансформация |
|-----------------|----------------|---------------|
| Все поля | Все поля | Прямое копирование (структура идентична) |

**Дополнительная трансформация:** При вставке в `events` используется партиционирование по `toYYYYMM(date_hour_minute)`. ClickHouse автоматически распределяет строки по месяцам.

#### 8.4.3. Таблица `sessions` (агрегированная)

`sessions` создаётся на основе `events` с группировкой по `synthetic_session_id`. 

| Поле в `sessions` | Источник / Формула | Тип агрегации |
|-------------------|--------------------|---------------|
| `synthetic_session_id` | `events.synthetic_session_id` | GROUP BY ключ |
| `user_fingerprint` | `MIN(events.user_fingerprint)` | Первое значение |
| `session_start` | `MIN(events.date_hour_minute)` | Минимум времени |
| `session_end` | `MAX(events.date_hour_minute)` | Максимум времени |
| `pageviews` | `COUNT(*) WHERE event_name = 'page_view'` | Сумма по условию |
| `clicks_total` | `COUNT(*) WHERE event_name = 'click'` | Сумма по условию |
| `discount_opens` | `COUNT(*) WHERE event_name = 'Open_discount'` | Сумма по условию |
| `promo_clicks` | `COUNT(*) WHERE event_name = 'Open_promo_code'` | Сумма по условию |
| `favourite_clicks` | `COUNT(*) WHERE event_name = 'Click_favorite_button'` | Сумма по условию |
| `scroll_events` | `COUNT(*) WHERE event_name = 'scroll'` | Сумма по условию |
| `is_bounce` | `CASE WHEN pageviews = 1 AND discount_opens = 0 AND promo_clicks = 0 THEN true ELSE false END` | Вычисляемое |
| `had_discount_open` | `CASE WHEN discount_opens > 0 THEN true ELSE false END` | Вычисляемое |
| `had_promo_click` | `CASE WHEN promo_clicks > 0 THEN true ELSE false END` | Вычисляемое |
| `first_page_location` | `argMin(page_location, date_hour_minute)` | Страница входа (первое событие сессии) |
| `last_page_location` | `argMax(page_location, date_hour_minute)` | Последняя страница |
| `device_category` | `any(device_category)` (одинаково в рамках сессии) | Любое значение (дедупликация) |
| `country`, `region`, `city` | `any(country)`, `any(region)`, `any(city)` | Любое значение |
| `is_new` | `any(is_new)` | Любое значение |
| `signed_in_with_user_id` | `any(signed_in_with_user_id)` | Любое значение |

**Трансформации при создании `sessions`:**
- Агрегация всех событий сессии в одну строку.
- Расчёт bounce-сессий (отказ) – сессия считается отказной, если в ней был только один просмотр страницы и не было других активностей.
- Денормализация: поля измерения (устройство, локация) копируются в `sessions` для ускорения запросов.

### 8.5. Сводная таблица трансформаций по слоям

| Этап | Исходный слой | Целевой слой | Тип загрузки | Основные трансформации |
|------|---------------|--------------|---------------|------------------------|
| 1 | Raw (Hive STRING) | Stage / ODS (`gp_ext`) | Инкремент (по партициям) | Приведение типов, очистка, фильтрация NULL, нормализация названий |
| 2 | ODS (`gp_ext`) | DDS (измерения) | Инкремент + SCD Type 0 | Извлечение уникальных значений, MD5-хеширование, вычисление календарных атрибутов, парсинг discount_id из URL |
| 3 | ODS (`gp_ext`) + измерения | DDS (факт `fact_event`) | Инкремент (по дате) | Генерация `user_fingerprint`, `synthetic_session_id`, `session_num`; подстановка внешних ключей через подзапросы; дедупликация |
| 4 | DDS (через `ch_ext`) | ClickHouse `events` | Полная перезагрузка (либо инкремент по дате) | Денормализация (джойн с измерениями), партиционирование по месяцу |
| 5 | ClickHouse `events` | ClickHouse `sessions` | Полное пересоздание | Группировка по сессиям, агрегатные функции, вычисление bounce-флага и флагов наличия скидок/промо |


### 8.7. Контроль качества трансформаций

На каждом этапе выполняются автоматические проверки:

| Этап | Проверка | Действие при ошибке |
|------|----------|---------------------|
| ODS → DDS | Количество записей в `fact_event` должно совпадать с количеством строк в `gp_ext` за тот же период (с точностью до дедупликации). | Логирование, остановка процедуры, алерт. |
| DDS → ClickHouse | Сравнить `COUNT(*)` в `ch_ext` и в `events` после загрузки – должно быть 100% совпадение. | Перезапуск задачи `fill_events`. |
| Сессии | Убедиться, что в `sessions` нет дубликатов `synthetic_session_id`. | Откат и повторная агрегация с явным `GROUP BY`. |
| Скидочные ID | Проверить, что поле `discount_id` в `sessions` (агрегированное) не потеряло значимые значения – например, хотя бы в одной сессии discount_opens > 0 ⇒ discount_id IS NOT NULL. | Ручной анализ, корректировка парсинга URL. |

Все трансформации описаны в процедурах Greenplum (`fill_dim_*`, `fill_fact_event`) и скриптах ClickHouse (`fill_events.sql`, `fill_sessions.sql`), которые вызываются Airflow. Это обеспечивает воспроизводимость и возможность аудита.
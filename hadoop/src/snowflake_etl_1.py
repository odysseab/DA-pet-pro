# # snowflake_etl.py
from pyspark.sql import SparkSession
# # from pyspark.sql.functions import row_number, max as spark_max

spark = SparkSession.builder \
    .appName("EbaySnowflakeETL") \
    .enableHiveSupport() \
    .getOrCreate()

spark.sql("USE s_yudin")

spark.sql("SET hive.exec.dynamic.partition.mode = nonstrict")

# # 1. dim_cat
# spark.sql("""
#     INSERT OVERWRITE TABLE dim_cat
#     SELECT
#         ROW_NUMBER() OVER (ORDER BY category_name) AS cat_id,
#         category_name
#     FROM (SELECT DISTINCT category_name FROM ebay_listings_optimized WHERE category_name IS NOT NULL) t
# """)

# print("TABLE dim_cat OVERWRITED")

# # 2. dim_sub_cat
# spark.sql("""
#     INSERT OVERWRITE TABLE dim_sub_cat
#     SELECT
#         ROW_NUMBER() OVER (ORDER BY t.sub_category_name) AS sub_cat_id,
#         t.sub_category_name,
#         dc.cat_id
#     FROM (
#         SELECT DISTINCT sub_category_name, category_name
#         FROM ebay_listings_optimized
#         WHERE sub_category_name IS NOT NULL
#     ) t
#     JOIN dim_cat dc ON t.category_name = dc.category_name
# """)

# print("TABLE dim_sub_cat OVERWRITED")

# # 3. dim_sub_sub_cat
# spark.sql("""
#     INSERT OVERWRITE TABLE dim_sub_sub_cat
#     SELECT
#         ROW_NUMBER() OVER (ORDER BY t.sub_sub_category_name) AS sub_sub_cat_id,
#         t.sub_sub_category_name,
#         dsc.sub_cat_id
#     FROM (
#         SELECT DISTINCT sub_sub_category_name, sub_category_name
#         FROM ebay_listings_optimized
#         WHERE sub_sub_category_name IS NOT NULL
#     ) t
#     JOIN dim_sub_cat dsc ON t.sub_category_name = dsc.sub_category_name
# """)

# print("TABLE dim_sub_sub_cat OVERWRITED")

# # 4. dim_sellers
# spark.sql("""
#     INSERT OVERWRITE TABLE dim_sellers
#     SELECT
#         ROW_NUMBER() OVER (ORDER BY seller_name) AS seller_id,
#         seller_name,
#         MAX(seller_feedback_percentage) AS seller_feedback_percentage,
#         MAX(seller_feedback_score) AS seller_feedback_score,
#         MAX(top_rated_buying_experience) AS top_rated_buying_experience
#     FROM ebay_listings_optimized
#     WHERE seller_name IS NOT NULL
#     GROUP BY seller_name
# """)

# print("TABLE dim_sellers OVERWRITED")

# # 5. dim_items
# spark.sql("""
#     INSERT OVERWRITE TABLE dim_items
#     SELECT
#         ROW_NUMBER() OVER (ORDER BY itemid) AS item_id,
#         itemid,
#         MAX(title) AS title,
#         MAX(price) AS price,
#         MAX(currency) AS currency,
#         MAX(item_condition) AS item_condition,
#         MAX(buying_options) AS buying_options,
#         MAX(item_creation_ts) AS item_creation_ts
#     FROM ebay_listings_optimized
#     GROUP BY itemid
# """)

# print("TABLE dim_items OVERWRITED")

# # 6. dim_locations
# spark.sql("""
#     INSERT OVERWRITE TABLE dim_locations
#     SELECT
#         ROW_NUMBER() OVER (ORDER BY location_country) AS location_id,
#         location_country
#     FROM (SELECT DISTINCT location_country FROM ebay_listings_optimized WHERE location_country IS NOT NULL) t
# """)

# print("TABLE dim_locations OVERWRITED")

# # 7. dim_logistics
# spark.sql("""
#     INSERT OVERWRITE TABLE dim_logistics
#     SELECT
#         ROW_NUMBER() OVER (ORDER BY shipping_cost_type, shipping_cost, shipping_currency, estimated_delivery_days) AS logistics_id,
#         shipping_cost_type,
#         shipping_cost,
#         shipping_currency,
#         estimated_delivery_days
#     FROM (
#         SELECT DISTINCT
#             shipping_cost_type,
#             shipping_cost,
#             shipping_currency,
#             estimated_delivery_days
#         FROM ebay_listings_optimized
#         WHERE shipping_cost_type IS NOT NULL
#     ) t
# """)

# print("TABLE dim_logistics OVERWRITED")

# # 8. dim_currencies
# spark.sql("""
#     INSERT OVERWRITE TABLE dim_currencies
#     SELECT
#         ROW_NUMBER() OVER (ORDER BY currency) AS currency_id,
#         currency AS currency_code
#     FROM (SELECT DISTINCT currency FROM ebay_listings_optimized WHERE currency IS NOT NULL) t
# """)

# print("TABLE dim_currencies OVERWRITED")

# 9. Таблица фактов (INSERT OVERWRITE с партиционированием)
spark.sql("""
    INSERT OVERWRITE TABLE fact_ebay_listings PARTITION (snapshot_dt)
    SELECT
        ROW_NUMBER() OVER (ORDER BY l.snapshot_dt, l.itemid) AS fact_id,
        di.item_id,
        ds.seller_id,
        dl.location_id,
        dlog.logistics_id,
        dc.currency_id,
        dssc.sub_sub_cat_id,
        l.price AS price_usd,
        l.shipping_cost AS shipping_cost_usd,
        l.snapshot_dt
    FROM ebay_listings_optimized l
    LEFT JOIN dim_items di ON l.itemid = di.itemid
    LEFT JOIN dim_sellers ds ON l.seller_name = ds.seller_name
    LEFT JOIN dim_locations dl ON l.location_country = dl.location_country
    LEFT JOIN dim_logistics dlog ON l.shipping_cost_type = dlog.shipping_cost_type
                                 AND l.shipping_cost = dlog.shipping_cost
                                 AND l.shipping_currency = dlog.shipping_currency
                                 AND l.estimated_delivery_days = dlog.estimated_delivery_days
    LEFT JOIN dim_currencies dc ON l.currency = dc.currency_code
    LEFT JOIN dim_sub_sub_cat dssc ON l.sub_sub_category_name = dssc.sub_sub_category_name
    WHERE l.snapshot_dt IS NOT NULL
""")

# print("TABLE fact_ebay_listings OVERWRITED")

# print("ETL завершён успешно")
spark.stop()
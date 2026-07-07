-- What's the average, min, and max closing_stock overall, and by category? (Tests the overstocking-vs-good-management question from Q1.)
sELECT 
Category,Holiday_Promotion,
round(min(Closing_stock),2) as min_closing,
round(max(Closing_stock),2) as max_closing,
round(avg(Closing_stock),2) as avg_closing,
round(avg(Units_Sold),2) as avg_unitsolds
from retail_store_inventory 
group by 1,2

-- What are the raw stockout counts (not %) by category and by promotion? (Tests whether Q2/Q3 findings survive a sample-size check.)

SELECT 
Category,stockout,
round(avg(Demand_Forecast),2) as avg_forecast,
round(avg(Units_Sold),2) as avg_Usold,
round(avg(Units_Ordered),2) as avg_Uorders
from retail_store_inventory 
group by 1,2


-- For Electronics specifically: compare avg Demand_Forecast and avg Units_Ordered for promotion=0 vs promotion=1. (Tests why Electronics reverses — is it under-ordering during promotions, or forecast miss during promotions?)


SELECT 
Category,Holiday_Promotion,
count(*) as StockOut
from retail_store_inventory 
where Closing_stock <= 0
group by 1,2


SELECT Product_ID, COUNT(*) AS negative_rows, MIN(Demand_Forecast) AS worst_value
FROM retail_store_inventory
WHERE Demand_Forecast < 0
group by 1
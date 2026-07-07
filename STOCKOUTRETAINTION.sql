-- By Category: stockout % for each — which is highest, which is lowest, what's the gap?
sELECT 
Category,
round(100*sum(case when Closing_stock <=0 then 1 else 0 end)/(count(*)),2) as stockout_per 
from retail_store_inventory 
group by 1

-- By Holiday_Promotion (0 vs 1): what's the stockout % for each — does promotion look like it raises or lowers stockout risk overall?

SELECT 
Holiday_Promotion,
round(100*sum(case when Closing_stock <=0 then 1 else 0 end)/(count(*)),2) as stockout_per 
from retail_store_inventory 
group by 1

-- Now cross both: Category × Holiday_Promotion — does the promotion effect from Q3 hold in every category, or does it flip/disappear in some?
SELECT 
Category, Holiday_Promotion,
round(100*sum(case when Closing_stock <=0 then 1 else 0 end)/(count(*)),2) as stockout_per 
from retail_store_inventory 
group by 1,2
order by 1,2

-- For stockout rows vs non-stockout rows, what's the average Demand_Forecast in each group? (This tells you whether stockouts cluster around high-forecast products — i.e., is the forecast itself the problem, or is something else going on.)
SELECT 
Category,
(select round(avg(Demand_Forecast),2) as avgforecast from retail_store_inventory where Closing_stock <=0) as avgforecaststockout,
(select round(avg(Demand_Forecast),2) as avgforecast from retail_store_inventory where Closing_stock > 0) as avgforecastInstock
from retail_store_inventory 
group by 1
order by 1

SELECT 
avg(Demand_Forecast),
avg(Units_Sold)
from retail_store_inventory 
where Closing_stock <=0
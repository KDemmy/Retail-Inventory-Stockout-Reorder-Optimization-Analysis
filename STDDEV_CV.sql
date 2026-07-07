select 
Store_ID,
STDDEV(Units_Sold) as std_dev_uSold,
100*round(STDDEV(Units_Sold)/avg(Units_Sold),2) unitsolds_CV,
100*round(STDDEV(Units_Ordered)/avg(Units_Ordered),2) Units_Ordered_CV,
100*round(STDDEV(Price)/avg(Price),2) Price_CV,
100*round(STDDEV(Demand_Forecast_N)/avg(Demand_Forecast_N),2) Demand_Forecast_N_CV
from retail_store_inventory
group by 1
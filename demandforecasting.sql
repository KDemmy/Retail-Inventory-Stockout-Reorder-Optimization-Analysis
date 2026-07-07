select * from (
Select 
	Store_ID,
    Units_Sold,
    Units_Ordered,
    Demand_Forecast,
    Price,
    Discount,
    Competitor_Pricing,
    round((((Units_Sold-Demand_Forecast)/Units_Sold)*100.0),0) as MAPE,
    dense_rank() over(partition by Category order by (((Units_Sold-Demand_Forecast)/Units_Sold)*100.0) desc)  as rnk
 from retail_store_inventory 
) as newt
where rnk <5
order by Store_ID,rnk asc
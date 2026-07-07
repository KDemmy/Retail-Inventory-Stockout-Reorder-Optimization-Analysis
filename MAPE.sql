Select 
	Year(Date) as years,
    Month(Date) as monts,
    Store_ID as streid, 
	round(sum(Units_Sold),0) as sold, 
	round(sum(Demand_Forecast),0) as forecast, 
    round(avg(((Units_Sold-Demand_Forecast)/Units_Sold)*100.0),0) as MAPE,
    round(avg(Price),0) as avgprice,  
    round(avg(Competitor_Pricing),0) as avgpricecomp
 from retail_store_inventory group by 1,2,3
having MAPE >0